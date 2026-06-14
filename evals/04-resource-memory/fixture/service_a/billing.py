"""service_a — depends on the shared datamodels.money helper. Contains one planted bug."""

from datamodels.money import to_cents


def discounted_total_cents(price, percent_off):
    """Return the total in cents after applying a percentage discount.

    `percent_off` is a percentage (e.g. 10 means 10% off).
    """
    # BUG: subtracts the percent as a flat dollar amount instead of a percentage of price.
    # Correct: price * (1 - percent_off / 100).
    discounted = price - percent_off
    return to_cents(discounted)
