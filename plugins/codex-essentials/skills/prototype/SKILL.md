---
name: prototype
description: "Build a disposable runnable experiment that answers one concrete product, logic, state-model, or UI question before production implementation. Use only when the user explicitly asks for a prototype, mockup, interactive exploration, or design variants."
---

# Prototype

Build the smallest disposable artifact that lets the user test an uncertain idea directly. A prototype answers a question; it is not an early production implementation.

## Authority and scope

- Prototype only when the user explicitly requests exploratory or throwaway work.
- Keep all changes local to the requested project or an isolated temporary workspace.
- Do not touch production, live data, external systems, or real user mutations unless the user gives exact authority.
- Mark prototype code clearly and keep it separate from production paths where practical.
- Do not promote, merge, delete, or rewrite production code merely because the prototype produced a preferred result.
- Do not create ADRs, issues, notes, or other durable records unless requested.

## Choose the artifact

Use the question being tested:

- For business rules, state transitions, data shape, or API ergonomics, read [LOGIC.md](LOGIC.md).
- For layout, hierarchy, interaction, or visual direction, read [UI.md](UI.md).

If the request is ambiguous and the choice would materially change the artifact, ask one focused question. Otherwise choose the smallest fitting branch and state the assumption. Do not build both branches unless both are needed.

## Shared contract

- Inspect the relevant project conventions before creating files.
- Use the existing runtime, components, dependencies, and task runner where practical; do not add a dependency for convenience.
- Keep the artifact focused on one stated question and expose the state or variation needed to judge it.
- Stub mutations and integrations unless they are themselves the question being tested.
- Prefer in-memory or disposable data and label any scratch persistence clearly.
- Provide one simple run command or URL.
- Add only the error handling and checks needed for safe, repeatable evaluation.
- Stop when the artifact runs and the user can evaluate the stated question.

## Completion

Smoke-test the primary interaction and any variant switch. Report the question, artifact location, run command or URL, assumptions, and known prototype gaps. Cleanup or production integration is separate work and requires an explicit request.
