---
name: adversarial-check
description: "Challenge a concrete behavior or trust boundary with the smallest set of high-value hostile scenarios. Use only when explicitly invoked as $adversarial-check; keep scenarios bounded, safe, and tied to the stated risk."
---

# Adversarial Check

Test the assumptions most likely to hide a serious failure. Do not turn adversarial testing into a permanent QA mode, generic checklist, or open-ended repair loop.

## Authority and safety

- Define the exact behavior, trust boundary, safety property, and failure cost before selecting scenarios.
- Keep review and audit requests read-only. Do not create instrumentation, fixtures, or files unless the user also authorized local test changes.
- Use local, disposable, synthetic, or explicitly authorized targets and data.
- Do not probe production or public systems, use real credentials, perform load or denial-of-service testing, exploit unrelated systems, or cause destructive data changes without exact authority.
- If a mutation has an unknown outcome, stop and report it instead of retrying.
- Do not create workflow state, invoke the skill recursively, or broaden into unrelated security or quality review.

## Scenario selection

Choose the smallest scenario set that covers the material failure mechanisms. Do not satisfy a fixed count or mandatory matrix.

Possible mechanisms include:

- invalid, missing, oversized, malformed, or boundary input;
- authentication, authorization, privacy, tenant, or trust-boundary bypass;
- duplicate delivery, retries, races, cancellation, and partial completion;
- stale state, cache, version mismatch, reload, resume, and lifecycle timing;
- dependency, network, storage, quota, timeout, and process failure;
- keyboard, focus, viewport, localization, and accessibility behavior;
- rollback and data integrity in an isolated environment when relevant.

Prefer scenarios that can change the decision or confidence. Do not repeat cosmetic variants or tests already proved by stronger existing evidence.

## Method

1. State the risk and expected safety property.
2. Establish the smallest normal-path baseline needed to interpret failures.
3. Run each selected scenario with controlled inputs and capture direct evidence.
4. Repeat only when bounded repetition is necessary to distinguish a race, flake, or nondeterministic harness.
5. Classify the result as product failure, harness failure, environment blocker, or expected safe behavior before changing anything.
6. Stop when every selected risk has a verdict or concrete blocker.

If repair was explicitly requested, make the narrowest evidence-backed fix through normal execution, rerun the failed scenario, and run only the relevant regression check. Do not enter repeated repair rounds without new discriminating evidence.

## Verdicts and output

Use:

- **PASS:** the observed behavior preserves the stated safety property for the tested scenario.
- **FAIL:** direct evidence shows the safety property is violated.
- **BLOCKED:** the scenario cannot be evaluated within current environment or authority.

Report each scenario, expected safety property, decisive observation, and verdict. Use a table only when it improves comparison. Finish with the highest-risk confirmed failure, material coverage gaps, and any temporary artifacts created or removed. Do not generalize a narrow PASS into proof of overall system safety.
