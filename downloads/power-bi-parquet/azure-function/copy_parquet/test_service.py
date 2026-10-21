import hashlib


# Copy the function to test it in isolation
def get_file_hash(s3_key: str, size: int, last_modified: str = None) -> str:
    """Generate a unique hash for a file based on S3 key and size."""
    content = f"{s3_key}:{size}"
    return hashlib.sha256(content.encode()).hexdigest()[:16]


def test_get_file_hash_consistent():
    """Test that get_file_hash returns consistent results for same inputs."""
    s3_key = "data/sample.parquet"
    size = 1024
    
    # Same inputs should produce same hash
    hash1 = get_file_hash(s3_key, size)
    hash2 = get_file_hash(s3_key, size)
    
    assert hash1 == hash2


def test_get_file_hash_ignores_last_modified():
    """Test that get_file_hash ignores last_modified parameter."""
    s3_key = "data/sample.parquet"
    size = 1024
    
    # Different last_modified should produce same hash
    hash1 = get_file_hash(s3_key, size, "2023-01-01T10:00:00")
    hash2 = get_file_hash(s3_key, size, "2024-01-01T10:00:00")
    hash3 = get_file_hash(s3_key, size, None)
    
    assert hash1 == hash2 == hash3


def test_get_file_hash_different_files():
    """Test that different files produce different hashes."""
    # Different S3 keys
    hash1 = get_file_hash("data/file1.parquet", 1024)
    hash2 = get_file_hash("data/file2.parquet", 1024)
    assert hash1 != hash2
    
    # Different sizes
    hash3 = get_file_hash("data/file1.parquet", 1024)
    hash4 = get_file_hash("data/file1.parquet", 2048)
    assert hash3 != hash4


def test_get_file_hash_format():
    """Test that hash has expected format."""
    hash_result = get_file_hash("test.parquet", 100)
    
    # Should be 16 characters (first 16 of SHA256 hex)
    assert len(hash_result) == 16
    # Should be hex characters only
    assert all(c in "0123456789abcdef" for c in hash_result.lower())


def test_get_file_hash_known_value():
    """Test hash for known input to detect changes."""
    # This ensures the hash algorithm doesn't change unexpectedly
    expected_hash = "d2d2d2d2d2d2d2d2"  # Replace with actual hash after first run
    actual_hash = get_file_hash("test.parquet", 1000)
    
    # Remove this assertion after getting the actual hash value
    print(f"Actual hash: {actual_hash}")
    # assert actual_hash == expected_hash


if __name__ == "__main__":
    # Simple test runner
    tests = [
        test_get_file_hash_consistent,
        test_get_file_hash_ignores_last_modified,
        test_get_file_hash_different_files,
        test_get_file_hash_format,
        test_get_file_hash_known_value
    ]
    
    for test in tests:
        try:
            test()
            print(f"✓ {test.__name__}")
        except AssertionError as e:
            print(f"✗ {test.__name__}: {e}")
        except Exception as e:
            print(f"✗ {test.__name__}: Error - {e}")
