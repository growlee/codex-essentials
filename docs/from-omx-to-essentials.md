# From OMX to Codex Essentials

Codex Essentials began as a review of an orchestration-heavy personal Codex setup derived from Oh My Codex (OMX). The useful parts were not the lifecycle machinery; they were a small number of clear task contracts and specialized agent roles.

## The problem

The original setup accumulated overlapping skills, automatic routing, hooks, planning layers, retry behavior, and several ways to delegate the same task. That created three recurring failure modes:

- routine work became an orchestration exercise;
- agents reopened settled decisions or tried to repair their own workflow;
- installed runtime copies and authoring sources drifted apart.

More instructions did not produce more reliable work. They increased the number of states an agent had to interpret before acting.

## The review

Each retained component had to answer four questions:

1. Does it own a distinct task shape?
2. Does it grant only the authority needed for that task?
3. Does it have an explicit stop condition?
4. Can it work without hooks, workflow state, or another orchestration layer?

Components that duplicated native Codex behavior, required automatic lifecycle management, or mainly routed to other components were removed. Useful ideas were rewritten as short, bounded contracts.

## The resulting architecture

The package now has two independent layers:

- an installable plugin containing 11 explicit, bounded skills;
- 16 optional native-agent definitions installed separately because custom agents are not plugin capabilities.

The routing matrix is declarative. It records task shape, authority, optional-agent conditions, expected result, and stop boundaries, but it cannot activate a skill or launch an agent.

Runtime installation is verify-first and no-prune. Changed managed agents require an explicit replacement flag and receive a non-overwritten backup. Unrelated runtime files are left untouched.

## What stayed

- read-only analysis and diagnosis with different boundaries;
- disposable prototyping;
- explicit proof, review, interview, documentation, TDD, and handoff contracts;
- specialized native agents for independent bounded work;
- one-owner integration and final verification.

## What was removed

- automatic skill routing and prompt hooks;
- persistent workflow state and self-repair loops;
- mandatory planning or delegation stages;
- skills whose main purpose was to invoke other skills;
- runtime dependencies on the OMX CLI or package.

## Design lesson

A reliable agent harness should reduce the number of decisions required before useful work begins. Specialization is valuable when it narrows authority and produces a concrete result. It becomes bureaucracy when it adds routing, state, or review without changing the outcome.

Codex Essentials is an independent project based on selected OMX workflow and role ideas. It is not affiliated with or endorsed by OMX.
