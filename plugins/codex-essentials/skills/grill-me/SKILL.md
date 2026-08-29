---
name: grill-me
description: "Stress-test a plan or design through a focused decision interview and keep a durable record of the answers. Use only when the user explicitly invokes $grill-me or explicitly asks to be interviewed; do not use for ordinary clarification or planning."
---

# Grill Me

Resolve the decisions that materially affect the user's plan or design. Do not turn the interview into exhaustive branch enumeration.

## Boundaries

- Interview and decision-record work only; do not implement, edit project or runtime files, or start a separate planning workflow unless the user asks for that work separately.
- Inspect the smallest relevant code or artifacts read-only when they can answer a question without asking the user.
- Ask about user intent, priorities, constraints, and tradeoffs that cannot be discovered from evidence.
- Do not ask speculative questions whose answers would not change the design or next action.
- Do not reopen a settled decision unless new evidence conflicts with it.

## Decision record

- Create one unique Markdown record when the interview starts. Use a destination supplied by the user; otherwise write under `$CODEX_HOME/grill-me/records` when `CODEX_HOME` is set, or `~/.codex/grill-me/records` otherwise.
- Use a timestamp and filesystem-safe topic slug. Never overwrite an existing record.
- After each answer, record the question, recommendation and material tradeoff, the user's answer, and the resulting current decision or consequence.
- If the user changes an answer, mark the previous decision as superseded and update only the dependent conclusions.
- Keep the record compact and user-readable. Do not store the full transcript, tool output, secrets, credentials, or sensitive payloads.
- This record is the only file write authorized by the skill. It is not workflow state and must not trigger, resume, or automatically continue work.
- If the record cannot be created or updated, report the exact path and error without claiming the answer was recorded or entering a retry loop.

## Interview

1. Identify the next unresolved decision that blocks or materially changes downstream choices.
2. Ask one decision-dependent question at a time.
3. Give a recommended answer with a concise reason and material tradeoff.
4. Offer only genuinely distinct options. Batch independent, low-risk confirmations when separate turns would add no value.
5. Treat a brief confirmation such as “yes” as acceptance of the current recommendation and continue to the next unresolved decision.
6. Stop when the remaining unknowns no longer materially affect the requested plan or design.

If the user changes an earlier answer, update only the dependent conclusions instead of restarting the interview.

## Completion

Finish with a compact summary of agreed decisions, material unresolved risks, and the next useful action. Write the same current summary to the decision record and report its path. Do not continue interviewing merely to cover every hypothetical branch.
