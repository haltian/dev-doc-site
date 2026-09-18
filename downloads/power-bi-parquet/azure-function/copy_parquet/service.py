import datetime
import hashlib
import logging
import os
import time
import concurrent.futures as cf
from typing import Iterator, Tuple, Optional, List, Dict, Any
from datetime import timezone, timedelta
from dateutil.relativedelta import relativedelta

import boto3
from functools import lru_cache
from azure.data.tables import TableServiceClient
from azure.core.exceptions import ResourceNotFoundError

from .utils import get_env

# File extensions we care about in S3
S3_EXTENSIONS = {".parquet"}

# Default time range for measurements in days
DEFAULT_MEASUREMENTS_TIME_RANGE_DAYS = 14


def utc_now() -> datetime.datetime:
    """Return current UTC time with timezone info."""
    return datetime.datetime.now(timezone.utc)


def get_measurements_time_range_days() -> int:
    """Get the time range in days for measurements data from environment variable.
    
    Returns:
        Integer number of days (default 14), clamped between 1 and 365.
    """
    raw = get_env("MEASUREMENTS_TIME_RANGE_DAYS", str(DEFAULT_MEASUREMENTS_TIME_RANGE_DAYS))
    try:
        days = int(raw)
        # Clamp to reasonable range
        if days < 1:
            logging.getLogger(__name__).warning(f"MEASUREMENTS_TIME_RANGE_DAYS={days} too small, using 1")
            return 1
        if days > 365:
            logging.getLogger(__name__).warning(f"MEASUREMENTS_TIME_RANGE_DAYS={days} too large, using 365")
            return 365
        return days
    except (ValueError, TypeError):
        logging.getLogger(__name__).warning(
            f"Invalid MEASUREMENTS_TIME_RANGE_DAYS='{raw}', using default {DEFAULT_MEASUREMENTS_TIME_RANGE_DAYS}"
        )
        return DEFAULT_MEASUREMENTS_TIME_RANGE_DAYS


def join_s3_prefix(*parts: str) -> str:
    """Safely join S3 prefix parts, avoiding double slashes.

    Args:
        *parts: Path components to join.

    Returns:
        Joined path with normalized slashes.
    """
    # Filter out empty parts and join with /
    filtered = [p for p in parts if p]
    return "".join(filtered)


def is_parquet_key(key: str) -> bool:
    """Check if an S3 key is a parquet file based on extension.
    
    Args:
        key: S3 object key.
        
    Returns:
        True if the key has a parquet extension.
    """
    return any(key.lower().endswith(ext) for ext in S3_EXTENSIONS)


def find_latest_parquet_in_prefix(
    s3_client, bucket: str, prefix: str
) -> Optional[Dict[str, Any]]:
    """Find the latest parquet file under a given S3 prefix.
    
    Args:
        s3_client: Boto3 S3 client.
        bucket: S3 bucket name.
        prefix: S3 prefix to search under.
        
    Returns:
        Dictionary with 'Key', 'Size', 'LastModified' for the latest file, or None if not found.
    """
    log = logging.getLogger(__name__)
    paginator = s3_client.get_paginator("list_objects_v2")
    kwargs = {"Bucket": bucket, "Prefix": prefix}
    
    latest_obj = None
    latest_time = None
    
    for page in paginator.paginate(**kwargs):
        for obj in page.get("Contents", []) or []:
            key = obj.get("Key")
            if not key or not is_parquet_key(key):
                continue
            
            last_modified = obj.get("LastModified")
            if latest_obj is None or (last_modified and last_modified > latest_time):
                latest_obj = obj
                latest_time = last_modified
    
    if latest_obj:
        log.debug(f"Found {latest_obj['Key']} as latest under prefix '{prefix}'")
    
    return latest_obj


def month_range_prefixes(
    base_prefix: str, since_utc: datetime.datetime, now_utc: datetime.datetime
) -> List[str]:
    """Generate list of year/month sub-prefixes for measurements covering the time range.
    
    Args:
        base_prefix: Base prefix (e.g., "measurementOccupancyStatus").
        since_utc: Start of time range (inclusive).
        now_utc: End of time range (inclusive).
        
    Returns:
        List of prefixes like ["measurementOccupancyStatus/2025/10", "measurementOccupancyStatus/2025/11"].
    """
    prefixes = []
    current = since_utc.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    end = now_utc.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    
    while current <= end:
        year_month = f"{current.year}/{current.month:02d}"
        prefixes.append(join_s3_prefix(base_prefix, year_month))
        current += relativedelta(months=1)
    
    return prefixes


def list_parquet_modified_since_over_prefixes(
    s3_client, bucket: str, prefixes: List[str], since_utc: datetime.datetime
) -> List[Dict[str, Any]]:
    """List parquet objects under multiple prefixes, filtered by LastModified >= since_utc.
    
    Args:
        s3_client: Boto3 S3 client.
        bucket: S3 bucket name.
        prefixes: List of S3 prefixes to scan.
        since_utc: Minimum LastModified threshold (timezone-aware UTC).
        
    Returns:
        List of object dicts with 'Key', 'Size', 'LastModified'.
    """
    log = logging.getLogger(__name__)
    results = []
    
    for prefix in prefixes:
        log.debug(f"Scanning prefix '{prefix}' for parquet files since {since_utc.isoformat()}")
        paginator = s3_client.get_paginator("list_objects_v2")
        kwargs = {"Bucket": bucket, "Prefix": prefix}
        
        for page in paginator.paginate(**kwargs):
            for obj in page.get("Contents", []) or []:
                key = obj.get("Key")
                if not key or not is_parquet_key(key):
                    continue
                
                last_modified = obj.get("LastModified")
                if last_modified and last_modified >= since_utc:
                    results.append(obj)
                else:
                    log.debug(
                        f"Skipping file outside time range: {key} "
                        f"(modified: {last_modified.isoformat() if last_modified else 'unknown'})"
                    )
    
    return results


def list_measurement_root_prefixes(s3_client, bucket: str, base_prefix: str) -> List[str]:
    """Discover all top-level prefixes under base_prefix that start with 'measurement'.

    Uses ListObjectsV2 with Delimiter='/' to enumerate common prefixes. Returns
    normalized prefixes that end with a trailing '/'.
    """
    log = logging.getLogger(__name__)
    # Build a prefix that starts at the first character of 'measurement' under the base prefix
    # join_s3_prefix simply concatenates parts; ensure we don't double-slash
    discover_prefix = join_s3_prefix(base_prefix, "measurement")

    paginator = s3_client.get_paginator("list_objects_v2")
    kwargs = {"Bucket": bucket, "Prefix": discover_prefix, "Delimiter": "/"}

    roots: set[str] = set()
    for page in paginator.paginate(**kwargs):
        for cp in page.get("CommonPrefixes", []) or []:
            p = cp.get("Prefix")
            if p and p.startswith(discover_prefix):
                roots.add(p)

    roots_list = sorted(roots)
    if roots_list:
        log.debug(f"Discovered {len(roots_list)} measurement* root folder(s): {roots_list}")
    else:
        log.warning(f"No measurement* root folders found under base prefix '{base_prefix}'")
    return roots_list




def get_file_hash_new(s3_key: str, size: int, last_modified: str | None = None) -> str:
    """New file hash including last_modified when available (v2)."""
    base = f"{s3_key}:{size}"
    content = f"{base}:{last_modified}" if last_modified else base
    return hashlib.sha256(content.encode()).hexdigest()[:16]


def get_file_hash(s3_key: str, size: int, last_modified: str = None) -> str:
    """Current file hash (v2): includes last_modified when available for better identity."""
    return get_file_hash_new(s3_key, size, last_modified)


def get_table_service() -> TableServiceClient:
    """Get Azure Table Service client using the function app's storage account."""
    connection_string = get_env("AzureWebJobsStorage", required=True)
    return TableServiceClient.from_connection_string(connection_string)


@lru_cache(maxsize=1)
def get_s3_client():
    """Create or return a cached boto3 S3 client built from environment variables.
    
    Uses ACCESS_KEY/SECRET/REGION env vars. Cached for reuse across the process to avoid
    recreating sessions in multiple locations and to allow safe sharing across threads.
    """
    s3_key = get_env("S3_ACCESS_KEY_ID", required=True)
    s3_secret = get_env("S3_SECRET_ACCESS_KEY", required=True)
    s3_region = get_env("S3_REGION", required=True)
    session = boto3.session.Session(
        aws_access_key_id=s3_key,
        aws_secret_access_key=s3_secret,
        region_name=s3_region,
    )
    return session.client("s3")


def get_s3_bucket_name() -> str:
    """Return the configured S3 bucket name from environment."""
    return get_env("S3_BUCKET", required=True)


def load_copied_hashes_since(days: Optional[int] = None) -> set[str]:
    """Bulk-load the set of copied file hashes from Azure Table Storage.

    If days is provided and > 0, restrict the scan to entries with copied_at >= now - days.
    """
    log = logging.getLogger(__name__)
    try:
        table_service = get_table_service()
        table_name = "copiedfiles"
        try:
            table_service.create_table_if_not_exists(table_name)
        except Exception:
            pass
        table = table_service.get_table_client(table_name)

        filter_str = None
        if days is not None and days > 0:
            since_dt = datetime.datetime.now(datetime.timezone.utc) - timedelta(days=days)
            iso = since_dt.replace(microsecond=0).isoformat()
            filter_str = f"copied_at ge datetime'{iso}'"

        copied_hashes: set[str] = set()
        # Select only necessary fields
        entities = table.query_entities(filter=filter_str, select=["RowKey", "status"]) if filter_str else table.list_entities(select=["RowKey", "status"]) 
        for ent in entities:
            if ent.get("status") == "copied":
                copied_hashes.add(ent["RowKey"])  # hash is used as RowKey
        log.debug(f"Loaded {len(copied_hashes)} copied file hashes from Table Storage")
        return copied_hashes
    except Exception as e:
        log.warning(f"Failed to bulk-load copied hashes: {e}. Falling back to empty set.")
        return set()


def is_file_already_copied(s3_key: str, size: int, last_modified: str = None) -> bool:
    """Check if a file has already been successfully copied using the current hash (v2)."""
    try:
        table_service = get_table_service()
        table_name = "copiedfiles"
        
        # Create table if it doesn't exist
        try:
            table_service.create_table_if_not_exists(table_name)
        except Exception:
            pass  # Table might already exist
        
        table_client = table_service.get_table_client(table_name)
        
        # Check new-hash (v2)
        new_hash = get_file_hash_new(s3_key, size, last_modified)
        try:
            entity = table_client.get_entity(partition_key=new_hash, row_key=new_hash)
            return entity.get('status') == 'copied'
        except ResourceNotFoundError:
            return False
    except Exception as e:
        # If table storage fails, log but don't block the operation
        logging.getLogger(__name__).warning(f"Could not check duplicate status for {s3_key}: {e}")
        return False


def mark_file_as_copied(s3_key: str, size: int, onelake_path: str, last_modified: str = None) -> None:
    """Mark a file as successfully copied in the tracking table.

    Uses new hash for RowKey/PartitionKey. Keeps schema backward compatible.
    """
    try:
        table_service = get_table_service()
        table_name = "copiedfiles"
        table_client = table_service.get_table_client(table_name)
        
        file_hash = get_file_hash_new(s3_key, size, last_modified)
        
        entity = {
            'PartitionKey': file_hash,
            'RowKey': file_hash,
            's3_key': s3_key,
            'size': size,
            'onelake_path': onelake_path,
            'status': 'copied',
            'copied_at': utc_now(),
            'last_modified': last_modified or 'unknown',
            'hash_version': 2,
        }
        
        table_client.upsert_entity(entity)
    except Exception as e:
        # Log but don't fail the operation if tracking fails
        logging.getLogger(__name__).warning(f"Could not mark file as copied {s3_key}: {e}")





def list_s3_parquet_objects() -> Iterator[Tuple[str, int, str]]:
    """Yield (key, size, last_modified) for selected S3 objects from device, deviceGroup, and measurementOccupancyStatus.
    
    Selection logic:
    - device/: Latest file only
    - deviceGroup/: Latest file only
    - measurementOccupancyStatus/YYYY/MM/: All files from last N days (configurable via MEASUREMENTS_TIME_RANGE_DAYS)
    
    Yields:
        Tuple of (key, size, last_modified_str) for each selected file.
    """
    log = logging.getLogger(__name__)
    bucket = get_s3_bucket_name()
    base_prefix = get_env("S3_PREFIX", "") or ""

    s3_client = get_s3_client()
    
    # Get configurable time range for measurements
    time_range_days = get_measurements_time_range_days()
    log.debug(f"Using time range of {time_range_days} days for measurementOccupancyStatus")

    # Get target folders from environment variable or use defaults
    target_folders = os.getenv("TARGET_FOLDERS", "device,deviceGroup,deviceGroupDevices,asset,assetDevice").split(",")
    target_folders = [f.strip() for f in target_folders if f.strip()]

    # Process each target folder
    for folder in target_folders:
        folder_prefix = join_s3_prefix(base_prefix, f"{folder}/")
        log.debug(f"Searching for latest file under '{folder_prefix}'")

        latest_obj = find_latest_parquet_in_prefix(s3_client, bucket, folder_prefix)
        if latest_obj:
            key = latest_obj["Key"]
            size = latest_obj.get("Size", 0)
            last_modified = latest_obj.get("LastModified")
            last_modified_str = last_modified.isoformat() if last_modified else None
            log.debug(f"Selected latest {folder} file: {key} (modified: {last_modified_str})")
            yield key, size, last_modified_str
        else:
            log.warning(f"No parquet files found under prefix '{folder_prefix}'")
    # 3. Measurements family: for all root folders starting with 'measurement',
    # collect all files from the last N days under their YYYY/MM subfolders.
    now = utc_now()
    since = now - timedelta(days=time_range_days)

    measurement_roots = list_measurement_root_prefixes(s3_client, bucket, base_prefix)
    total_selected = 0

    for root in measurement_roots:
        log.debug(
            f"Searching for measurement files under '{root}' modified since {since.isoformat()} "
            f"(last {time_range_days} days)"
        )

        # Generate year/month prefixes to scan for this root
        month_prefixes = month_range_prefixes(root, since, now)
        log.debug(f"Scanning {len(month_prefixes)} month prefix(es) under '{root}': {month_prefixes}")

        # List all qualifying files under this root
        measurement_objs = list_parquet_modified_since_over_prefixes(
            s3_client, bucket, month_prefixes, since
        )

        log.debug(f"Selected {len(measurement_objs)} files within last {time_range_days} days under '{root}'")
        total_selected += len(measurement_objs)

        for obj in measurement_objs:
            key = obj["Key"]
            size = obj.get("Size", 0)
            last_modified = obj.get("LastModified")
            last_modified_str = last_modified.isoformat() if last_modified else None
            yield key, size, last_modified_str

    log.debug(f"Selected total of {total_selected} measurement* files within last {time_range_days} days across all roots")


def copy_object(s3_client, bucket: str, key: str, size: int, last_modified: str | None, backend) -> str:
    """Copy a single S3 object to the selected backend, preserving the full S3 folder structure.

    Returns the destination path used for testing/diagnostics.
    """
    log = logging.getLogger(__name__)

    # Build destination path via backend (may include subpath rules)
    dest = backend.build_destination_path(key)

    log.debug(f"Copying s3://{bucket}/{key} -> dest:{dest}")

    # Check if destination already exists as an additional safety check
    if backend.check_exists(dest):
        log.debug(f"Destination already exists: {dest}")
        # Still mark as copied in case tracking table is out of sync
        mark_file_as_copied(key, size, dest, last_modified)
        return dest

    # Download from S3
    resp = s3_client.get_object(Bucket=bucket, Key=key)
    body = resp["Body"].read()

    # Upload to destination via backend
    backend.upload_bytes(dest, body)

    # Mark as successfully copied
    mark_file_as_copied(key, size, dest, last_modified)

    return dest


def copy_object_with_retries(s3_client, bucket: str, item: Tuple[str, int, Optional[str]], backend, *, max_attempts: int = 3) -> Tuple[str, str]:
    """Copy wrapper with simple exponential backoff retries using selected backend.

    Returns (key, status) where status in {"copied", "failed"}.
    """
    key, size, last_modified = item
    backoff = 1.0
    last_exc: Exception | None = None
    for attempt in range(1, max_attempts + 1):
        try:
            copy_object(s3_client, bucket, key, size, last_modified, backend)
            return key, "copied"
        except Exception as e:  # noqa: BLE001
            last_exc = e
            if attempt >= max_attempts:
                logging.getLogger(__name__).exception(f"Failed to copy {key} after {attempt} attempts: {e}")
                break
            time.sleep(backoff)
            backoff = min(backoff * 2, 30)
    return key, "failed"


def configure_library_logging() -> None:
    """Reduce noisy logs from Azure SDKs to at least WARNING by default.

    Honors optional env AZURE_LOG_LEVEL to override (e.g., DEBUG for troubleshooting).
    Safe to call multiple times.
    """
    level_name = (os.getenv("AZURE_LOG_LEVEL", "WARNING") or "WARNING").upper()
    level = getattr(logging, level_name, logging.WARNING)

    # Core azure namespace and a few chatty submodules
    azure_loggers = (
        "azure",
        "azure.core",
        "azure.identity",
        "azure.data",
        "azure.core.pipeline.policies.http_logging_policy",
    )
    for name in azure_loggers:
        logging.getLogger(name).setLevel(level)


def run_copy_parquet(logger: logging.Logger | None = None) -> int:
    """Entry point for copying parquet files from S3 to target environment.

    Returns number of successfully attempted copies (best-effort; failures are logged and skipped).
    """
    log = logger or logging.getLogger(__name__)
    utc_timestamp = utc_now()
    log.debug(f"copy_parquet started at {utc_timestamp.isoformat()}")
    # Ensure third-party libraries are quiet at INFO level (especially azure*)
    configure_library_logging()

    # Select upload backend (OneLake or Storage Account) based on env
    try:
        from .uploader_base import get_backend_from_env
        backend = get_backend_from_env()
    except Exception as e:
        log.error(f"Failed to initialize upload backend: {e}")
        return 0

    # Prepare S3 client (unified helper)
    s3_client = get_s3_client()
    bucket = get_s3_bucket_name()

    # 1) Enumerate source files once
    source_files = list(list_s3_parquet_objects())

    # 2) Bulk-load copied hashes (time-bounded by measurement window)
    copied_hashes = load_copied_hashes_since(days=None)

    # 3) Compute candidates via set-join on hashes (no per-item membership probes)
    # create dict with hash -> parquet index
    new_files_with_hashes: dict[str, tuple[str, int, str]] = {get_file_hash_new(key, size, last_modified):(key,size, last_modified) for key, size, last_modified in source_files}

    # Any source hash that already appears in copied_hashes marks the corresponding item(s) as seen
    source_hashes = set(new_files_with_hashes.keys())
    matched_hashes = source_hashes & copied_hashes  # set intersection = the "join"
    missing_hashes = source_hashes - matched_hashes

    # Remaining indices are the candidates to copy
    candidates = [new_files_with_hashes[k] for k in missing_hashes]

    total = len(source_files)
    skipped = total - len(candidates)
    
    # Limit files per batch to avoid timeouts
    max_files_per_batch = int(os.getenv("MAX_FILES_PER_BATCH", "3000"))
    if len(candidates) > max_files_per_batch:
        log.info(f"Limiting batch to {max_files_per_batch} files (out of {len(candidates)} pending)")
        candidates = candidates[:max_files_per_batch]
    
    log.info(f"Total source: {total}, already copied: {skipped}, to copy: {len(candidates)}")

    if not candidates:
        log.debug("No files to copy. Exiting.")
        return 0

    # 4) Copy concurrently with bounded parallelism and retries (10 is the default connection pool size)
    max_workers = int(os.getenv("COPY_MAX_WORKERS", "10"))
    copied = 0

    def _submit_all(exec: cf.ThreadPoolExecutor):
        return [exec.submit(copy_object_with_retries, s3_client, bucket, item, backend) for item in candidates]

    with cf.ThreadPoolExecutor(max_workers=max_workers) as ex:
        futures = _submit_all(ex)
        total_to_copy = len(candidates)
        for i, fut in enumerate(cf.as_completed(futures), 1):
            key, status = fut.result()
            if status == "copied":
                copied += 1
            # Log progress every 100 files or at key milestones
            if i % 100 == 0 or i == total_to_copy:
                log.info(f"Progress: {i}/{total_to_copy} processed, {copied} copied successfully")

    log.info(f"copy_parquet finished. Files copied: {copied}/{total_to_copy}, Files skipped (already copied): {skipped}, Duration: {(utc_now() - utc_timestamp).total_seconds():.1f}s")
    return copied


# Backward-compatibility shim for deployments expecting acquire_onelake_token in this module
# Note: Import is inside the function to avoid circular import with uploader_onelake -> service
# Keep the signature identical to the real implementation

def acquire_onelake_token() -> str:
    """Expose OneLake token acquisition via service module.

    This delegates to `copy_parquet.uploader_onelake.acquire_onelake_token`.
    Kept as a shim to remain compatible with call sites importing from
    `copy_parquet.service`.
    """
    from .uploader_onelake import acquire_onelake_token as _impl
    return _impl()
