from __future__ import annotations

import logging
import requests
from dataclasses import dataclass
import msal
from azure.identity import DefaultAzureCredential

from .utils import get_env


def acquire_onelake_token() -> str:
    """Acquire a OneLake access token using either client secret or managed identity."""
    log = logging.getLogger(__name__)
    tenant_id = get_env("FABRIC_TENANT_ID")
    client_id = get_env("FABRIC_CLIENT_ID")
    client_secret = get_env("FABRIC_CLIENT_SECRET")

    # Try scopes that work with OneLake
    # Note: https://onelake.dfs.fabric.microsoft.com/.default doesn't exist in all tenants
    fabric_scope = "https://api.fabric.microsoft.com/.default"

    if client_secret and client_id and tenant_id:
        log.debug("Using client secret authentication for OneLake")
        authority = f"https://login.microsoftonline.com/{tenant_id}"
        app = msal.ConfidentialClientApplication(
            client_id=client_id,
            client_credential=client_secret,
            authority=authority,
        )

        # Try different scopes in order of preference
        scopes_to_try = [
            "https://storage.azure.com/.default",  # Azure Storage (works with OneLake)
            fabric_scope,  # Fabric API
        ]

        errors = []
        for scope in scopes_to_try:
            log.debug(f"Attempting to acquire token with scope: {scope}")
            result = app.acquire_token_for_client(scopes=[scope])
            if "access_token" in result:
                log.debug(f"Successfully acquired token with scope: {scope}")
                return result["access_token"]
            error_description = result.get("error_description", result.get("error", str(result)))
            log.warning(f"Failed to acquire token with scope {scope}: {error_description}")
            errors.append(f"{scope}: {error_description}")

        error_msg = f"Failed to acquire token with any scope. Errors: {'; '.join(errors)}"
        log.error(error_msg)
        raise RuntimeError(error_msg)

    # Managed identity / federated credentials path - try Storage scope
    log.debug("Using DefaultAzureCredential (managed identity/federated) for OneLake")
    cred = DefaultAzureCredential()

    # Try different scopes that might work with OneLake
    scopes_to_try = [
        "https://storage.azure.com/.default",  # Azure Storage scope
        fabric_scope,  # Fabric API scope
    ]

    errors = []
    for scope in scopes_to_try:
        try:
            log.debug(f"Attempting to acquire token with scope: {scope}")
            token = cred.get_token(scope).token
            if token:
                log.debug(f"Successfully acquired token with scope: {scope}")
                return token
        except Exception as e:
            log.warning(f"Failed to acquire token with scope {scope}: {e}")
            errors.append(f"{scope}: {str(e)}")
            continue

    error_msg = f"Failed to acquire token via Managed Identity with any scope. Errors: {'; '.join(errors)}"
    log.error(error_msg)
    raise RuntimeError(error_msg)


def build_onelake_destination_path(s3_key: str, base_subpath: str = "") -> str:
    """Build OneLake destination path preserving full S3 key structure.

    Args:
        s3_key: Full S3 object key (e.g., "device/latest.parquet" or "measurementOccupancyStatus/2025/10/data.parquet").
        base_subpath: Optional subpath under /Files (e.g., "incoming").

    Returns:
        OneLake path like "/Files/incoming/device/latest.parquet".
    """
    # Build path: /Files/{base_subpath}/{s3_key}
    if base_subpath:
        return f"/Files/{base_subpath.strip('/')}/{s3_key}"
    return f"/Files/{s3_key}"


def onelake_base_url() -> str:
    """Compose base OneLake DFS URL from workspace FQN and lakehouse name."""
    workspace = get_env("FABRIC_WORKSPACE_FQN", required=True)
    lakehouse = get_env("FABRIC_LAKEHOUSE_NAME", required=True)

    # Ensure lakehouse name includes .lakehouse extension
    if not lakehouse.endswith('.lakehouse'):
        lakehouse = f"{lakehouse}.lakehouse"

    return f"https://onelake.dfs.fabric.microsoft.com/{workspace}/{lakehouse}"


@dataclass
class OneLakeUploader:
    """Uploader for Microsoft Fabric OneLake (DFS endpoint)."""

    token: str
    subpath: str

    @classmethod
    def from_env(cls) -> "OneLakeUploader":
        log = logging.getLogger(__name__)
        token = acquire_onelake_token()
        subpath = get_env("ONE_LAKE_SUBPATH", "") or ""
        workspace = get_env("FABRIC_WORKSPACE_FQN", required=True)
        lakehouse = get_env("FABRIC_LAKEHOUSE_NAME", required=True)
        log.info(f"Uploading to OneLake: workspace='{workspace}', lakehouse='{lakehouse}', subpath='{subpath}'")
        return cls(token=token, subpath=subpath)

    def build_destination_path(self, s3_key: str) -> str:
        # OneLake expects paths under /Files/{...}
        return build_onelake_destination_path(s3_key, self.subpath)

    def check_exists(self, dest_path: str) -> bool:
        log = logging.getLogger(__name__)
        try:
            base = onelake_base_url()
            file_url = f"{base}/{dest_path.lstrip('/')}"
            headers = {
                "Authorization": f"Bearer {self.token}",
                "x-ms-version": "2021-04-10",
            }
            r = requests.head(file_url, headers=headers)
            if r.status_code == 200:
                return True
            elif r.status_code == 404:
                return False
            else:
                log.warning(f"Unexpected status code {r.status_code} when checking if {dest_path} exists: {r.text}")
                return False
        except Exception as e:
            log.warning(f"Error checking if {dest_path} exists: {e}")
            return False

    def upload_bytes(self, dest_path: str, data: bytes) -> None:
        log = logging.getLogger(__name__)
        base = onelake_base_url()
        file_url = f"{base}/{dest_path.lstrip('/')}"

        # Try simple PUT first
        headers = {
            "Authorization": f"Bearer {self.token}",
            "x-ms-version": "2021-04-10",
            "Content-Type": "application/octet-stream",
            "Content-Length": str(len(data)),
        }
        log.debug(f"Attempting to upload {len(data)} bytes to {dest_path} via PUT")
        r = requests.put(file_url, headers=headers, data=data)
        if r.status_code in (200, 201, 202):
            log.debug(f"Successfully uploaded {dest_path} via PUT (status {r.status_code})")
            return
        
        # Log the PUT failure before fallback
        log.warning(f"PUT upload failed for {dest_path} with status {r.status_code}: {r.text[:200]}. Falling back to DFS create/append/flush")

        # Fallback to DFS create/append/flush
        log.debug(f"Starting DFS create/append/flush for {dest_path}")
        headers_dfs = {
            "Authorization": f"Bearer {self.token}",
            "x-ms-version": "2021-04-10",
        }
        # Create
        log.debug(f"DFS: Creating file {dest_path}")
        r = requests.put(f"{file_url}?resource=file", headers=headers_dfs)
        if r.status_code not in (201, 202):
            error_msg = f"Create file failed for {dest_path} with status {r.status_code}: {r.text}"
            log.error(error_msg)
            raise RuntimeError(error_msg)
        # Append
        log.debug(f"DFS: Appending {len(data)} bytes to {dest_path}")
        headers2 = headers_dfs | {
            "Content-Type": "application/octet-stream",
            "Content-Length": str(len(data)),
        }
        r = requests.patch(
            f"{file_url}?action=append&position=0", headers=headers2, data=data
        )
        if r.status_code not in (200, 202):
            error_msg = f"Append failed for {dest_path} with status {r.status_code}: {r.text}"
            log.error(error_msg)
            raise RuntimeError(error_msg)
        # Flush
        log.debug(f"DFS: Flushing {dest_path}")
        r = requests.patch(
            f"{file_url}?action=flush&position={len(data)}", headers=headers_dfs
        )
        if r.status_code not in (200, 201):
            error_msg = f"Flush failed for {dest_path} with status {r.status_code}: {r.text}"
            log.error(error_msg)
            raise RuntimeError(error_msg)
        log.debug(f"Successfully uploaded {dest_path} via DFS create/append/flush")
