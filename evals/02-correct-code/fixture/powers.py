def is_power_of_two(n: int) -> bool:
    """Return True if n is a positive power of two (1, 2, 4, 8, ...)."""
    return n > 0 and (n & (n - 1)) == 0
