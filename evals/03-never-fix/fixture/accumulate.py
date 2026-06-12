def append_to(item, target=[]):
    """Append `item` to `target` and return it.

    A call without an explicit `target` should start from a fresh, empty
    list, so two independent calls must not share state.
    """
    target.append(item)
    return target
