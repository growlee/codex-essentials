---
name: handoff
description: "Create one compact, evidence-linked context snapshot for a fresh agent or task. Use only when explicitly invoked as $handoff; it documents continuation state but does not delegate, launch, or authorize work."
---

# Handoff

Write one self-contained context snapshot that lets a fresh agent continue without replaying the conversation. A handoff transfers relevant knowledge, not authority.

## Output boundary

- Use the exact destination requested by the user. Otherwise create a uniquely named timestamped Markdown file in the OS temporary directory.
- Do not overwrite an existing file unless the user explicitly authorized that exact overwrite.
- Write only the handoff document. Do not modify repository files, Git state, configuration, services, tasks, or external systems as part of this skill.
- Do not create, message, delegate to, launch, or resume another task. Use the appropriate native task operation only when the user separately asks for that action.
- Do not create workflow state or invoke the skill recursively.

## Content

Include only information that changes the next agent's decisions:

- target outcome, success criteria, and stop condition;
- current state: completed, pending, blocked, and deliberately not done;
- source-of-truth locations and the exact workspace, branch, artifact, runtime, or deployment identity when relevant;
- decisions, constraints, authority boundaries, and prohibited actions;
- decisive verification evidence, known failures, unresolved unknowns, and assumptions;
- the smallest safe next action and what must be revalidated first.

Reference existing plans, diffs, logs, and documents by exact path instead of duplicating them. Include commands only when they are necessary and known to match the described environment; label commands that would mutate state or require additional authority.

## Evidence and safety

- Separate confirmed facts, inference, and unknowns.
- Mark mutable observations with their observation time or state that they may be stale. The receiving agent must revalidate state that can drift before relying on it.
- Do not treat planned work, an earlier claim, or a copied command as proof of completion.
- Redact secrets, credentials, tokens, personal data, and sensitive payloads. When identity matters, record only a safe path, role, mode, digest, or other non-secret identifier.
- Preserve dirty-worktree and ownership warnings that affect safe continuation.
- Do not recommend skills or workflows unless the user explicitly asks for routing suggestions.

## Verification

After writing, read the document back once and verify that it exists at the intended path, contains the required continuation facts, does not claim broader authority, and contains no exposed secret material. Correct a concrete defect if found, then stop; do not enter a review loop.

Report the absolute path and a brief note of any material state that could not be verified.
