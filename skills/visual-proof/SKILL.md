---
name: visual-proof
description: "Verify an explicit UI state, transition, layout, or visual-runtime claim in the named environment with reproducible evidence. Use only when explicitly invoked as $visual-proof; do not use for general design exploration or source-only review."
---

# Visual Proof

Verify the requested visual behavior in a bounded pass. Do not turn verification into a persistent visual workflow or an aesthetic redesign.

## Authority and scope

- Use the exact route, application, environment, reference, viewport, and state named by the user or required by the claim.
- Verification is read-only unless the same request explicitly authorizes repair. Do not infer permission to redesign, deploy, publish, or alter live data.
- Limit checks to requested states and transitions plus only the direct prerequisites needed to reproduce them.
- Do not capture or expose credentials, private messages, personal data, or unrelated sensitive screen content.
- Do not create workflow state, invoke this skill recursively, or keep iterating after the claim is proved, disproved, or concretely blocked.

## Runtime evidence

Source, markup, or CSS inspection alone cannot prove rendered behavior.

For each material claim:

- reproduce the relevant runtime state;
- identify the owning DOM element or UI boundary when practical;
- inspect computed styles, geometry, layering, scroll ownership, responsive state, and lifecycle timing only where they affect the verdict;
- exercise the requested transition rather than judging only its final static frame;
- capture a screenshot or other reproducible evidence for decisive states when the environment supports it.

Pixel comparison is supporting evidence, not an automatic verdict when fonts, animation, antialiasing, timestamps, or dynamic data can vary.

## Method

1. State the exact claim and acceptance criteria.
2. Capture the material runtime context: application or build identity when available, route, viewport, data fixture, authentication boundary, and initial UI state.
3. Reproduce the target state and transition.
4. Inspect runtime ownership and geometry before attributing a mismatch to source code.
5. Compare observation with the acceptance criteria and assign a verdict.
6. Stop when every requested criterion has a verdict.

## Repair boundary

If repair was explicitly requested, make only the smallest evidence-backed change through normal implementation and rerun the affected criteria. Do not enter an open-ended fix-and-recheck loop; report any remaining failure or unsupported cause.

If repair was not requested, remain read-only and identify only the observed mismatch, likely owning boundary, and smallest useful developer direction.

## Verdicts

Use:

- **PASS:** runtime evidence proves the criterion.
- **FAIL:** runtime evidence contradicts the criterion.
- **BLOCKED:** the required state or evidence cannot be reached within current access or authority.

Report the verdict for each requested state or transition, decisive evidence, runtime context, known owner or hypothesis, and any remaining verification gap.
