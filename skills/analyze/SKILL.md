---
name: analyze
description: "Read-only analysis of repository architecture, behavior, data flow, dependencies, or change impact from concrete evidence. Use when answering requires tracing multiple files or comparing plausible explanations; use diagnose instead for a specific failure or root-cause investigation."
---

# Analyze

Answer the user's question from current evidence without changing files, configuration, Git state, services, or external systems.

## Boundaries

- Analysis is strictly read-only and does not authorize fixes or implementation.
- Use repository files, tests, configuration, logs, and read-only runtime observations available within current authority.
- Do not expand a repository question into external research unless the user requests it or current external documentation is necessary.
- Separate confirmed evidence, inference, and unresolved unknowns when the distinction affects the answer.
- Suggest a next step only when useful; do not create a mandatory plan, handoff, or follow-up workflow.
- Use `$diagnose` when the primary question is why a concrete bug, regression, failure, or performance problem occurs.

## Method

1. Identify the smallest evidence set capable of answering the question.
2. Trace the real path across relevant files and system boundaries.
3. Verify material claims against current evidence.
4. Compare alternative explanations only while several remain credible.
5. Stop when the user's question is sufficiently answered; do not continue gathering evidence merely to make the analysis more exhaustive.

Use bounded native subagents only for genuinely independent lookup branches that materially improve the answer.

## Answer

Lead with the conclusion. Support material source claims with paths and line numbers where available. State meaningful uncertainty and validation gaps. Use the shortest structure that keeps the reasoning clear.
