---
name: roadmap
description: "Create, consult, or keep one durable development roadmap synchronized with verified project progress. Use only when explicitly invoked as $roadmap or when the user explicitly requests a roadmap operation."
---

# Roadmap

Maintain one current roadmap for a named development area. A roadmap recommends what to develop across future milestones and why; it is not a detailed execution plan for the current task and does not authorize implementation.

## Activation and authority

- Act only through an explicit `$roadmap` invocation or an explicit roadmap operation request. Catalog visibility or implicit loading is not execution authority.
- Creating a roadmap requires an explicit create request and authorizes writing exactly one task-local Markdown file plus its immediate parent directory when needed.
- A progress, completion, priority, or next-task request about a resolved existing roadmap authorizes updating that same file when verified evidence makes it stale. Only an explicit read-only or no-edit instruction suppresses this synchronization.
- If the current request separately authorizes implementation of work named in the resolved roadmap, that authority comes from the request, not this skill. Synchronize the same roadmap after the work reaches a verified outcome, then stop without starting another milestone.
- This skill itself does not authorize modifying code, configuration, Git state, services, native goals, tasks, or external systems.
- Do not create hooks, workflow state, ledgers, retry loops, background work, or automatic continuation.
- The roadmap is advisory. Its milestones never authorize their own execution.

## Resolve the roadmap file

Use the first applicable source:

1. the exact file named by the user;
2. one existing repository roadmap whose `Roadmap-ID` and scope match the current request;
3. the repository's established roadmap location;
4. otherwise `<project-root>/roadmaps/<scope-slug>.md`, using the repository root or, when no repository exists, the current workspace root.

On first creation, include these stable identity fields near the top:

```markdown
Roadmap-ID: <project-name>/<scope-slug>
Project: <repository name or stable workspace identifier>
Scope: <plain-language development area>
```

Search the current project before creating a file. Never create a second roadmap for the same scope. If multiple existing files are equally plausible or the requested path belongs to another scope, ask one concise question and do not write.

Read an existing roadmap completely before using or updating it. Treat it as advisory input, not as current truth.

## Synchronize verified progress

When an existing roadmap is resolved and the user did not require a read-only result:

- compare its baseline, milestone status, risks, and recommended next task with current evidence;
- mark a milestone complete only when current evidence satisfies its completion criteria; otherwise retain the accurate in-progress, blocked, deferred, or superseded state;
- update only the affected baseline, milestone, dependency, risk, and decision entries;
- remove an obsolete recommended next task and replace it with the smallest currently unblocked next task, or state that no actionable next task is proven;
- do not rewrite the file when evidence shows no material change.

For a progress or next-task request, synchronize before answering. When separately authorized implementation is in scope, synchronize after its outcome is verified and before the final report. Always update the resolved source roadmap itself, never a duplicate, summary, or session-specific copy.

## Ground the recommendation

- Inspect the smallest relevant set of source, tests, configuration, documentation, and current project state before recommending milestones.
- Revalidate current-state claims from an existing roadmap. Mark stale recommendations as superseded instead of following them automatically.
- Use current primary external documentation only when a material recommendation depends on a changeable external contract, version, or platform behavior.
- Separate confirmed evidence, evidence-backed assumptions, recommendations, and unresolved unknowns when the distinction changes a decision.
- Resolve technical choices from evidence when practical. Recommend one preferred direction in plain language rather than returning an unranked option list.
- Ask the user only about product priorities, cost, risk tolerance, irreversible choices, or other decisions that cannot be resolved safely from evidence. Do not make a non-expert choose implementation details the agent can determine.

## Keep the roadmap useful

Include only information that changes future development decisions:

- intended user or product outcome and material constraints;
- verified current baseline;
- recommended milestones in dependency and priority order;
- for each milestone, its outcome, reason, material prerequisites, and completion evidence;
- material risks, decisions, and unresolved unknowns;
- deliberately deferred or excluded work;
- one smallest recommended next task.

Explain unfamiliar terms briefly. Do not add staffing ceremonies, generic best-practice checklists, speculative features, precise time estimates without evidence, or empty sections.

Do not record secrets, credentials, tokens, unnecessary personal data, or sensitive diagnostic payloads.

When updating, preserve user-confirmed constraints and milestones whose completion is supported by evidence. Do not reopen settled decisions without conflicting new evidence. Keep the document as the current roadmap rather than an append-only session log or changelog.

## Completion

Read the resulting file back once. Verify its identity, project scope, internal consistency, and recommended next task. Correct only a concrete defect in the requested roadmap change, then stop.

Report the absolute path, the main recommendation, and only material unresolved decisions. Do not start implementing the roadmap or continue automatically.
