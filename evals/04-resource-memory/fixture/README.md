# Fixture for the resource-memory eval

Create three sibling dirs here when running the eval manually:

- `datamodels/` — a tiny shared module (e.g. a `money.py` with a rounding helper).
- `service_a/` — code that imports from `datamodels`, with one planted bug.
- `service_b/` — different code that also imports from `datamodels`, with its own planted bug.

Kept minimal and language-light on purpose (plain Python, runnable with `python`/`pytest`), like the
other eval fixtures. The point is the registry behavior, not the bug difficulty.
