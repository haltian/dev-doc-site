from __future__ import annotations

from dataclasses import dataclass
import logging
import os
from typing import Optional

from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient


@dataclass
class StorageAccountUploader:
    """Uploader for Azure Storage Account (Blob).

    Uses either a connection string (preferred for simplicity) or
    DefaultAzureCredential with an account URL.
    """

    blob_service: BlobServiceClient
    container: str
    subpath: str

    @classmethod
    def from_env(cls) -> "StorageAccountUploader":
        log = logging.getLogger(__name__)
        container = os.getenv("STORAGE_UPLOAD_CONTAINER")
        if not container:
            raise RuntimeError("Missing required env STORAGE_UPLOAD_CONTAINER for storageaccount uploads")

        subpath = os.getenv("UPLOAD_SUBPATH", "") or ""

        conn = os.getenv("STORAGE_CONNECTION_STRING")
        if conn:
            log.debug("Using connection string for Storage Account authentication")
            svc = BlobServiceClient.from_connection_string(conn)
            log.info(f"Uploading to Storage Account: container='{container}', subpath='{subpath}'")
            return cls(blob_service=svc, container=container, subpath=subpath)

        account_url = os.getenv("STORAGE_ACCOUNT_URL")
        if not account_url:
            raise RuntimeError(
                "Provide STORAGE_CONNECTION_STRING or STORAGE_ACCOUNT_URL for storageaccount uploads"
            )
        log.debug("Using DefaultAzureCredential for Storage Account authentication")
        cred = DefaultAzureCredential()
        svc = BlobServiceClient(account_url=account_url, credential=cred)
        log.info(f"Uploading to Storage Account: url='{account_url}', container='{container}', subpath='{subpath}'")
        return cls(blob_service=svc, container=container, subpath=subpath)

    def _blob_name(self, s3_key: str) -> str:
        if self.subpath:
            return f"{self.subpath.strip('/')}/{s3_key}"
        return s3_key

    def build_destination_path(self, s3_key: str) -> str:
        # For storage account, the dest path is the blob name (no leading slash)
        return self._blob_name(s3_key)

    def check_exists(self, dest_path: str) -> bool:
        log = logging.getLogger(__name__)
        bc = self.blob_service.get_blob_client(container=self.container, blob=dest_path)
        try:
            return bc.exists()
        except Exception as e:
            log.warning(f"Error checking if blob {dest_path} exists: {e}")
            return False

    def upload_bytes(self, dest_path: str, data: bytes) -> None:
        log = logging.getLogger(__name__)
        log.debug(f"Uploading {len(data)} bytes to blob {dest_path}")
        bc = self.blob_service.get_blob_client(container=self.container, blob=dest_path)
        # upload_blob supports overwrite
        try:
            bc.upload_blob(data, overwrite=True)
            log.debug(f"Successfully uploaded blob {dest_path}")
        except Exception as e:
            log.error(f"Failed to upload blob {dest_path}: {e}")
            raise
