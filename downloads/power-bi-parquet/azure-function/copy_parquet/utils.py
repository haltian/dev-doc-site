"""Shared utility functions for the copy_parquet package.

This module contains helper functions used across multiple modules to avoid circular imports.
"""
import os


def get_env(name: str, default: str | None = None, required: bool = False) -> str | None:
    """Read environment variable with optional default and required enforcement.

    Args:
        name: Environment variable name.
        default: Default value to return if not set.
        required: If True, raise RuntimeError when not set and no default provided.

    Returns:
        The environment variable value or default.
    """
    val = os.getenv(name, default)
    if required and not val:
        raise RuntimeError(f"Missing required environment variable: {name}")
    return val
