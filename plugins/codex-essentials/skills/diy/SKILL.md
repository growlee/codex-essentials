---
name: diy
description: "Check one scoped request for material ambiguity, then automatically create exactly one native Codex goal after an explicit $diy invocation; draft only on explicit opt-out."
---

# DIY

Turn the current scoped request into one reviewable native Codex goal. An explicit `$diy` invocation authorizes automatic goal creation after the comprehension gate; it does not authorize execution of the created goal.

## Activation and authority

- Act only through an explicit `$diy` invocation. Catalog visibility or implicit loading is not execution authority.
- Default to automatic start. Use draft-only mode only when the current invocation explicitly asks for a draft, prompt, or objective without creating or starting a goal.
- Preserve the current task's authority limits. This skill does not authorize external, production, destructive, credential-sensitive, Git, installation, synchronization, or publication actions by itself.
- Preserve settled constraints and the newest non-conflicting user instruction.

## Comprehension gate

Complete this gate before inspecting or mutating native goal state:

1. Derive the concrete outcome, in-scope target, acceptance criteria, authority limits, known source of truth, and stop condition from the current request and settled context.
2. Check whether another reasonable interpretation would materially change the outcome, scope, safety boundary, irreversible action, or acceptance criteria.
3. Treat discoverable implementation details as work for the goal, not as ambiguity. Do not ask for confirmation merely because the request omits details that can be safely inspected or decided during execution.
4. If the objective has one materially reasonable interpretation, show the exact objective and continue without requesting confirmation.
5. If a missing choice materially changes the objective, ask exactly one concise question, return `BLOCKED`, and do not inspect or mutate native goal state.

For a finite test request, expose any material scope expansion before creating the goal. Do not silently turn a fixed matrix into harness development, reusable infrastructure, release work, production integration, or additional deliverables. If that expansion is neither already authorized nor safely separable, treat it as a material ambiguity.

## Write the objective

Include only details that change execution:

- the concrete outcome and in-scope target;
- acceptance criteria and proportionate verification;
- authority limits and explicitly prohibited actions;
- known source-of-truth paths, versions, or identities;
- a material unresolved blocker, when one prevents safe execution;
- the stop condition.

Reference exact authoritative paths and immutable revisions or identities instead of copying their full contracts. Do not copy the full conversation, fabricate missing decisions, expose secrets, encode internal tool syntax, or add a token budget that the user did not supply.

## Draft-only opt-out

When the user explicitly requests only a draft, return the exact objective as a copyable prompt with status `DRAFT` and stop. Do not inspect or mutate native goal state.

## Automatic start

1. Show the exact objective in a user-visible update immediately before any goal mutation. The visible objective is the understanding check; do not add a separate approval step.
2. Inspect native goal state once with `get_goal`.
3. If an unfinished goal exists, do not replace, complete, pause, or update it. Return the objective and the active-goal blocker.
4. If no unfinished goal exists, call `create_goal` exactly once with the objective. Include `token_budget` only when the user explicitly supplied a positive budget.
5. If inspection or creation is unavailable or rejected, do not retry. Return the objective and the exact blocker.
6. Treat an uncertain `create_goal` outcome as `BLOCKED`. Do not retry unless authoritative new evidence proves that no goal was created.
7. After confirmed creation, the `$diy` invocation ends. Do not call `update_goal`, invoke `$diy` again, or create another goal during this invocation. Later goal execution may use `update_goal` only under the native goal contract.

## Boundaries

These boundaries apply only while `$diy` checks, drafts, or creates the goal. Execution of the created goal follows its objective, current user authority, and applicable operating contracts.

- Do not create plan files, ledgers, checkpoints, hooks, notifications, background work, or launch subagents during drafting and creation.
- Do not require or prohibit subagents in the objective unless the user or an applicable operating contract explicitly requires it. Goal execution may use typed native subagents under the normal routing contract.
- Do not install or synchronize skills, edit repositories, perform Git actions, or mutate external systems merely because the goal describes that work.
- Do not create a package-owned workflow, lifecycle, retry counter, or self-repair loop.

## Result

Return one concise status and the exact objective when it can be safely formed:

- `CREATED` only when `create_goal` confirmed creation;
- `DRAFT` only for an explicit draft-only opt-out with no goal-state inspection or mutation;
- `BLOCKED` for one material clarification question, an unfinished goal, an unavailable or rejected tool, or an uncertain creation outcome.

Keep the explanation to the material outcome and blocker, if any.
