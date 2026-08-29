---
name: tdd
description: "Implement explicitly requested behavior through a focused red-green-refactor loop using the project's existing test stack. Use only when explicitly invoked as $tdd; ordinary requests for tests or coverage do not activate this skill."
---

# TDD

Implement the requested behavior test-first without creating a separate planning or approval lifecycle.

## Authority and boundaries

- Work only within the implementation scope already requested by the user.
- Use the project's existing test framework, conventions, fixtures, and dependencies.
- Run tests only against local, disposable, or explicitly authorized environments; never point a test at production or live user data by assumption.
- Do not add a dependency, redesign architecture, or expose internals merely to make testing convenient.
- Do not fix unrelated failing tests or broaden the feature while completing the loop.
- Do not weaken, delete, or rewrite valid assertions merely to obtain green output.

## Loop

1. Define the smallest observable behavior that proves the requirement.
2. Inspect the nearest existing tests and identify relevant baseline failures before attributing a failure to the new test.
3. Add the smallest focused test or case set at the highest practical stable seam.
4. Run it and confirm that it fails because the requested behavior is absent—not because of syntax, setup, environment, or an unrelated defect.
5. Implement the narrowest correct behavior.
6. Run the focused test and confirm it passes.
7. Run the relevant surrounding tests. Refactor only when it clearly improves the changed code while preserving green behavior.

If a meaningful red state cannot be produced because the behavior already exists, the seam is unavailable, or the environment cannot execute it, report that concrete limitation instead of manufacturing a ceremonial failure or expanding scope.

## Completion

Report the red observation, the green observation, surrounding-test result, changed behavior, and any remaining validation gap. Stop when the requested behavior is implemented and proportionately verified.
