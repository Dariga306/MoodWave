import secrets
from datetime import datetime


def generate_code() -> str:
    """Return a random 6-digit zero-padded string, e.g. '047291'."""
    return f"{secrets.randbelow(1000000):06d}"


def is_code_expired(expires_at: datetime) -> bool:
    """Return True if the given expiry timestamp is in the past."""
    return datetime.utcnow() > expires_at
