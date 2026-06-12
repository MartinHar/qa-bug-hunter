# Frontend / UI / Client-state — high-yield bug classes

Use this as a checklist for frontend defects (React/Next, Vue/Nuxt, or any SPA). Read the component
**with its state management and the API calls it depends on**. Many UI bugs only appear under
conditions a happy-path click-through never hits: empty data, slow network, error responses, expired
sessions, very long strings. Reproduce those conditions in the browser (see `ui-verification.md`).

## State & reactivity
- Failure: stale closures capturing old state, effects with missing/incorrect dependencies, derived
  state that doesn't update when its source does, an async result applied after the component
  unmounted, double-fetch on mount.
- Inspect: effect/watcher dependency lists, where async results are written back to state, and
  cleanup on unmount/teardown.

## Rendering & hydration
- Failure: missing/unstable list `key`s causing wrong item reuse, conditional render flicker, SSR
  hydration mismatch (server markup ≠ first client render — common in Nuxt/Next), layout shift.
- Inspect: list rendering, anything that differs between server and client (dates, random, `window`
  access during render), and components that read browser-only APIs without guards.

## Forms & validation
- Failure: client and server validation disagree, submit button enabled/disabled in the wrong state,
  uncontrolled→controlled input warnings, number/date parsing that breaks under non-US locales,
  silent loss of input on error.
- Inspect: the validation rules on each side, the submit-enable condition, and how the form behaves
  when the server rejects it (does the user's input survive?).

## Async, loading & error states
- Failure: unhandled promise rejection, no loading/empty/error states (only the happy path is
  designed), request waterfalls, stale-while-revalidate showing stale data as fresh.
- Inspect: every data fetch — does it render distinct loading, empty, error, and success states?
  What renders while the request is in flight, and what renders if it 4xx/5xxs?

## Session & auth UX
- Failure: a 401/expired session mid-use shows a broken screen instead of a re-login prompt; token
  refresh races; protected route briefly flashes before redirect.
- Inspect: how the app reacts when a request returns 401 after the user has been idle. Reproduce by
  letting the session expire (or clearing it) and then acting — see `auth-and-sessions.md`.

## Boundary & adversarial inputs in the UI
- Failure: very long unbroken strings overflow layout, empty lists render nothing/garbage, special
  characters break rendering, throttled network exposes missing skeletons.
- Inspect: feed components real edge data and throttle the network in the browser to surface
  timing-dependent breakage.

## Accessibility & semantics (these are real bugs, not "nice-to-haves")
- Failure: controls with no accessible label, focus lost or trapped, keyboard navigation impossible,
  non-interactive elements used as buttons.
- Inspect: the accessibility snapshot (Playwright MCP exposes one) — missing names and roles show up
  there clearly, and it's also the most deterministic thing to assert against.

## Performance regressions (note the boundary)
- This crosses into perf rather than functional bugs, but a sharp regression in LCP, CLS, or TBT is
  worth flagging. Treat it as a finding with measurements, not a "bug" with a pass/fail repro, unless
  there's a hard threshold the team treats as a requirement.

## How to confirm
For logic/state bugs, a component or unit test in the project's own framework is often enough — assert
on rendered output for the failing input. For anything visual, interaction-driven, hydration-related, or end-to-end, drive the **Playwright MCP** browser
to reproduce the exact steps and capture a screenshot at the failure point. Prefer asserting on the
accessibility snapshot (deterministic) and using the screenshot as human-visible evidence.
