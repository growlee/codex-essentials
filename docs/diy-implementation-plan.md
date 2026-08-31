# DIY implementation plan

## Intended outcome

Add an explicit-invocation `diy` skill that checks whether a scoped user request is materially unambiguous and then automatically creates one reviewable native Codex goal without introducing package-owned workflow state, retry loops, or background automation. Draft-only behavior remains available through an explicit opt-out.

The repository remains the authoring source. This change does not install or synchronize the plugin runtime.

## Runtime contract

1. Activate only through an explicit `$diy` invocation.
2. Derive one concise objective from the current request and already settled constraints.
3. Before goal-state access, check whether another reasonable interpretation would materially change the outcome, scope, safety boundary, irreversible action, or acceptance criteria.
4. Treat safely discoverable implementation details as downstream work rather than ambiguity; do not ask for ceremonial confirmation.
5. If a material choice is missing, ask exactly one concise question, return `BLOCKED`, and do not inspect or mutate native goal state.
6. If the request is materially unambiguous, show the exact goal prompt and automatically continue without an additional approval step.
7. Use draft-only behavior only when the invocation explicitly asks for a prompt, draft, or objective without goal creation.
8. Before automatic creation, inspect native goal state once with `get_goal`. Do not replace, complete, pause, or update an unfinished goal.
9. When no unfinished goal exists, create exactly one native goal with `create_goal`.
10. Set `token_budget` only when the user supplied an explicit positive budget.
11. If goal inspection or creation is unavailable, rejected, or uncertain, return the prompt and the exact blocker without retrying; an uncertain creation outcome remains fenced until authoritative evidence proves that no goal was created.
12. During checking, drafting, and creation, do not create plan files, ledgers, checkpoints, hooks, subagents, notifications, or a separate continuation mechanism.
13. After confirmed creation, the `$diy` invocation ends without calling itself, calling `update_goal`, or creating another goal. Later goal execution follows the native goal contract and may use `update_goal` to close its lifecycle.
14. Do not prescribe or prohibit subagents for downstream execution unless the user or an applicable operating contract explicitly requires it.

## Goal prompt content

The generated objective should preserve only information that changes execution:

- concrete outcome and in-scope target;
- acceptance criteria and proportionate verification;
- authority limits and explicitly prohibited actions;
- known source-of-truth paths or identities;
- material unresolved blocker, if one prevents safe execution;
- stop condition.

Do not copy the full conversation, fabricate missing decisions, include secrets, or encode internal tool syntax in the objective.

## Repository changes

- Add `plugins/codex-essentials/skills/diy/SKILL.md`.
- Add catalog-visible `plugins/codex-essentials/skills/diy/agents/openai.yaml`; the skill contract still requires an explicit `$diy` invocation before acting.
- Add `diy` to `package-manifest.json`.
- Add one user-requested route to `routing-matrix.json` with no subagent ownership.
- Add the skill to the README skill table; keep the generic architecture tree unchanged.
- Bump the feature release from `0.2.0` to `0.3.1` in the package manifest, plugin manifest, and README installation ref.
- Keep the plugin manifest skill-directory exposure and marketplace path unchanged.
- Keep `runtime.workflowState` false because the package creates no private state machine; document that `diy` can explicitly request one product-owned native goal.
- Clarify the plugin and README wording so “no workflow state” means no package-owned lifecycle, not that the package can never call an explicitly requested native goal tool.

## Validation

- Run the system skill validator on the new skill.
- Run all five repository validation commands from `AGENTS.md`.
- Verify the manifest and routing matrix list the new skill exactly once.
- Verify the catalog metadata exposes `diy` with `allow_implicit_invocation: true` while the skill contract and routing matrix keep execution user-requested.
- Verify materially ambiguous requests ask one question without native goal-state access, unambiguous explicit invocations require one `get_goal` preflight before at most one `create_goal` call, and explicit draft-only requests call neither tool.
- Verify the contract contains no automatic retry, recursive invocation, background action, subagent launch, or runtime synchronization.

## Analyze and diagnose results

The read-only analysis found four material gaps in the first draft: active-goal handling was absent, creation authority was ambiguous, the feature version was unchanged, and native product goal state was not distinguished from forbidden package-owned workflow state.

The diagnosis identified one shared cause: prompt construction, goal creation, and downstream execution lacked strict phase boundaries. The accepted repair is now part of the runtime contract: a pre-state comprehension gate, automatic start after an unambiguous explicit invocation, explicit draft-only opt-out, one `get_goal` preflight, at most one `create_goal`, unknown-outcome fencing, no replacement of an unfinished goal, downstream lifecycle ownership under the native contract, normal downstream subagent routing, and no package-owned continuation or retry.

The `0.3.1` compatibility repair separates catalog visibility from execution routing. Codex receives `diy` metadata so `$diy` can resolve, while the skill body and the `user-requested` matrix route still require an explicit user invocation before the skill acts.

## Stop boundary

Finish with the source-only candidate and validation evidence. Do not install, synchronize, commit, push, publish, or create another goal during this implementation task.
