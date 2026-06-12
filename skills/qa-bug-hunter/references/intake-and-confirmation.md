# Clarifying & checkpoints

This blends two approaches. **Andrej Karpathy's "Think Before Coding"** — don't assume silently,
surface tradeoffs, and ask when genuinely uncertain, but *only* then. And the **superpowers plugin's**
lightweight style — if you need information, ask 1–2 key questions right away — together with its
verification discipline (failing-test-first, investigate the root cause before any fix). The audience
is QAs who may not know the repo's code or its language/framework, so: ask sparingly, in plain
language, only about things a QA can actually answer — and work out every technical detail yourself.

## Ask only when it genuinely matters

- **Default to proceeding.** Most hunts need no question at all — the user's request plus reading the
  code is enough. Ask only when a real ambiguity would change *what you do or where you look*, and you
  can't resolve it yourself by reading the code.
- When you do ask, ask **at most 1–2 key questions, right away**, and present each as a short list of
  options the user picks by letter — easier than composing prose, especially for non-developers.
  Always include a "you decide / just go" option so an answer is never strictly required.
- If something is merely uncertain but low-stakes, **state your assumption in one line and proceed**
  rather than asking. Don't stall, and don't pile up questions.

## Only ask things a QA can answer — never about code or stack

The user may not know the codebase, the language, or the framework, so:

- **Never ask** which test framework or runner to use, whether a repro should be a unit or integration
  test, how the project is built, or any code-internal detail. Detect and decide all of that yourself
  (see `repro-execution.md`).
- **Fair to ask** (only if unclear and it matters): which feature / area / screen to focus on · what
  they expect to happen vs. what they're seeing · whether a specific input or step triggers it · which
  environment is safe to test against (local / staging). (Never ask about fixing — this skill only
  finds and reports bugs; it doesn't fix.)
- Phrase everything in plain language — no jargon. If you must use a term, define it in a few words.

A good, minimal ask (only when the target is genuinely unclear):

> Which part should I focus on?
> (a) login / sign-in   (b) search / results   (c) the whole <feature> flow   (d) you pick — I'll
> start with the riskiest area

## Checkpoints — confirm before anything consequential

Keep the user in control at the few moments that matter (superpowers' review checkpoints; Karpathy's
"surface tradeoffs / push back"). Before each of these, show a one-line plain-language summary of what
will happen, then wait for a "yes":

- Running anything that could **change data**, or that hits a **shared / staging** environment.
- **Driving the browser** against a non-local environment (it's also off by default — enable it on
  demand, see `ui-verification.md`).

(There is no "apply a fix" checkpoint — this skill never modifies code.)

Reading code, and running isolated/local repros that only read, need no checkpoint — just do them and
report. A QA shouldn't have to approve a harmless local test, but should always be the one to approve
anything that could touch real data.

## When you're stuck, say so — don't spin

From the superpowers debugging discipline and Karpathy's "stop when confused": understand the root
cause before writing a finding, and if you've tried to reproduce the same thing about three times
without progress, stop — summarize what you tried and what's still unclear, and ask one focused
question (or hand it back) rather than thrashing.
