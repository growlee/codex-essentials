---
name: grill-me
description: "Stress-test a plan or design through a focused decision interview. Use only when the user explicitly invokes $grill-me or explicitly asks to be interviewed; do not use for ordinary clarification or planning."
---

# Grill Me

Resolve the decisions that materially affect the user's plan or design. Do not turn the interview into exhaustive branch enumeration.

## Boundaries

- Interview only; do not implement, edit files, or start a separate planning workflow unless the user asks for that work separately.
- Inspect the smallest relevant code or artifacts read-only when they can answer a question without asking the user.
- Ask about user intent, priorities, constraints, and tradeoffs that cannot be discovered from evidence.
- Do not ask speculative questions whose answers would not change the design or next action.
- Do not reopen a settled decision unless new evidence conflicts with it.
- Do not create decision logs or other files unless the user explicitly requests them.

## Interview

1. Identify the next unresolved decision that blocks or materially changes downstream choices.
2. Ask one decision-dependent question at a time.
3. Give a recommended answer with a concise reason and material tradeoff.
4. Offer only genuinely distinct options. Batch independent, low-risk confirmations when separate turns would add no value.
5. Treat a brief confirmation such as “yes” as acceptance of the current recommendation and continue to the next unresolved decision.
6. Stop when the remaining unknowns no longer materially affect the requested plan or design.

If the user changes an earlier answer, update only the dependent conclusions instead of restarting the interview.

## Completion

Finish with a compact summary of agreed decisions, material unresolved risks, and the next useful action. Do not continue interviewing merely to cover every hypothetical branch.
