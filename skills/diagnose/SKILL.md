---
name: diagnose
description: "Find the most likely root cause of a concrete bug, regression, failure, or performance problem using discriminating evidence. Diagnosis stays read-only unless the user explicitly requests repair; use analyze for general architecture or behavior questions without a reported failure."
---

# Diagnose

Find the best-supported root cause with the smallest useful evidence loop. Do not turn diagnosis into an automatic repair lifecycle.

## Authority

- A diagnosis-only request is read-only and does not authorize edits, fixes, configuration changes, service changes, or external mutations.
- Reproduce or observe behavior only when it is safe and within current authority.
- Prefer existing tests, logs, traces, artifacts, and read-only observations before adding instrumentation.
- Do not add production instrumentation or send mutating requests to an external or live system without authority for that exact action.
- Repair only when the user explicitly requests a fix, change, or implementation.

## Method

1. Define the exact symptom, expected behavior, actual behavior, and relevant boundary.
2. Find the smallest signal capable of distinguishing the credible causes.
3. Trace the real execution path and test the cheapest evidence-backed hypotheses first.
4. Consider multiple causes only while several remain credible.
5. Converge on the most likely cause, confidence, supporting evidence, and unresolved unknowns.
6. Stop when the requested diagnosis is sufficiently supported.

If reproduction is unavailable or unsafe, continue from the best current evidence and state the limitation.

## Repair

When repair was requested:

- fix the narrowest shared root cause;
- do not repair unrelated nearby problems;
- run the smallest regression check that proves the corrected behavior;
- remove temporary instrumentation;
- if an external mutation has an unknown outcome, stop and report it instead of retrying automatically.

## Answer

Lead with the cause or best-supported finding. Separate confirmed evidence, inference, and unresolved gaps. Report changed files and regression evidence only when repair was requested and completed.
