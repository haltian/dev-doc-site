import logging
import os

import azure.functions as func

# Configure logging level from environment
log_level_name = os.getenv("LOG_LEVEL", "INFO").upper()
log_level = getattr(logging, log_level_name, logging.INFO)
logging.getLogger().setLevel(log_level)

app = func.FunctionApp()

# Schedule must be provided by Azure App Settings (Terraform). No code default.
_SCHEDULE = os.getenv("COPY_PARQUET_SCHEDULE")
if not _SCHEDULE:
    raise RuntimeError(
        "COPY_PARQUET_SCHEDULE app setting is required and must be provided by infrastructure."
    )


@app.function_name(name="copy_parquet")
@app.schedule(schedule=_SCHEDULE, arg_name="timer", run_on_startup=False, use_monitor=True)
def copy_parquet(timer: func.TimerRequest) -> None:  # noqa: ARG001 - required by Functions host
    """Timer-triggered entry point that delegates to the service layer.

    Note: We import the heavy dependencies (boto3, msal, etc.) lazily inside
    the function body to ensure the function can be discovered by the Azure
    Functions host even if dependencies are not pre-installed on the platform.
    """
    from copy_parquet.service import run_copy_parquet  # Lazy import

    logger = logging.getLogger("copy_parquet")
    run_copy_parquet(logger=logger)
