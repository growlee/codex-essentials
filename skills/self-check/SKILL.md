---
name: self-check
description: "Perform one read-only check for repeated work without new evidence, reopened settled decisions, or drift from the current request. Use only when explicitly invoked as $self-check."
---

# Self Check

Perform one bounded audit of the current branch of work. Determine whether the proposed next action still serves the newest user request or merely repeats an earlier attempt.

## Boundary

- Use the current conversation and evidence already available. Do not start new investigation, run tools, retry work, or create artifacts merely to perform this check.
- Remain read-only. Do not fix, edit, resume, retry, delegate, invoke another skill or agent, or continue the task as part of the check.
- Do not create workflow state, checkpoints, plans, hooks, attempt counters, or another self-check.
- Never synthesize approval, block normal completion, or automatically continue work.
- Inspect only the recent decisions and attempts relevant to the current action; do not produce a full conversation retrospective.

## Decision authority

- Follow the newest user instruction while preserving earlier non-conflicting constraints and decisions.
- A decision is settled only when the user explicitly confirmed it, an authoritative contract requires it, or decisive evidence established it.
- An earlier assistant proposal, assumption, plan, or unverified claim alone is not a settled decision.

## Check

Compare the proposed next action with:

- the current requested outcome and authority;
- relevant settled decisions;
- materially similar actions or hypotheses already attempted;
- any new evidence, changed input, or genuinely different recovery path;
- signs that the agent is repairing its own workflow instead of producing the requested outcome.

A repeated action is justified only when something material changed. Repeated observation, monitoring, or verification against new state is not a loop merely because it uses a similar command.

## Result

Lead with the direct finding: continue, course-correct, or stop at a concrete blocker. State the decisive reason and, when correction is needed, the smallest different next action available within existing authority.

If no drift or unjustified repetition is present, say so briefly. Do not append a retrospective, retry plan, workflow proposal, or invitation to run another check.
