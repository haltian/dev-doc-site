from __future__ import annotations

from typing import Protocol


class UploadBackend(Protocol):
    """Protocol for upload backends (OneLake, Storage Account, etc.)."""

    def build_destination_path(self, s3_key: str) -> str:
        """Return destination path (relative) preserving S3 structure as needed."""
        ...

    def check_exists(self, dest_path: str) -> bool:
        """Return True if destination already exists."""
        ...

    def upload_bytes(self, dest_path: str, data: bytes) -> None:
        """Upload raw bytes to destination path."""
        ...


def get_backend_from_env() -> UploadBackend:
    """Factory that selects the upload backend based on environment variables.

    Supported types:
      - onelake (default for backwards compatibility)
      - storageaccount
    """
    import os

    upload_type = os.getenv("UPLOAD_TYPE", "onelake").strip().lower()
    if upload_type == "storageaccount":
        from .uploader_storage_account import StorageAccountUploader

        return StorageAccountUploader.from_env()
    elif upload_type == "onelake" or upload_type == "fabric":
        from .uploader_onelake import OneLakeUploader

        return OneLakeUploader.from_env()
    else:
        raise RuntimeError(
            f"Unsupported UPLOAD_TYPE '{upload_type}'. Supported: onelake, storageaccount"
        )
