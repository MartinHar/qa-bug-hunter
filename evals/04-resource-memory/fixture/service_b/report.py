"""service_b — a *different* target that also depends on datamodels.money. One planted bug."""

from datamodels.money import to_cents


def average_cents(amounts):
    """Return the average of `amounts`, in cents."""
    # BUG: no guard for an empty list -> ZeroDivisionError on average_cents([]).
    return to_cents(sum(amounts)) // len(amounts)
