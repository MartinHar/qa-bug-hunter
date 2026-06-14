"""Shared money helpers used by multiple services.

This is the 'shared data models' resource the eval hands the hunter a path to once; the test is that
the hunter records that path and reuses it on a later, different target without re-asking.
"""


def to_cents(amount):
    """Convert a dollar amount (float/int) to an integer number of cents."""
    return int(round(amount * 100))
