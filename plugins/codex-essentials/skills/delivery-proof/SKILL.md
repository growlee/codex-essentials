---
name: delivery-proof
description: "Verify an explicit delivery or completion claim across the requested source, artifact, runtime, deployment, or live/public boundary. Use only when explicitly invoked as $delivery-proof; return evidence-backed PASS, FAIL, or BLOCKED without implementing or deploying."
---

# Delivery Proof

Prove the claim the user actually made. This is a bounded read-only verification pass, not a release pipeline or repair workflow.

## Authority and scope

- Verification remains read-only. Do not implement, rebuild, publish, deploy, restart, repair, or change configuration through this skill.
- Verify only the named outcome and the boundaries necessary to prove it.
- Use existing access and exact authorized targets; do not broaden into unrelated environments or accounts.
- Preserve dirty worktrees and existing artifacts. Avoid checks that rewrite build output or runtime state; isolate them when a generated check is genuinely necessary.
- Keep direct evidence, inference, and missing evidence distinct.
- Do not create workflow state, invoke the skill recursively, or continue after the claim is adequately proved or disproved.

## Evidence by boundary

Use only the boundaries relevant to the claim:

- **Source:** exact repository, checkout, ref, commit, blob, diff, and relevant test or static evidence.
- **Artifact:** immutable package or file identity, hash, contents, and provenance from source where available.
- **Runtime:** the process, image, loaded artifact, configuration identity, and observed behavior actually in use.
- **Deployment:** the deployed release or artifact identity and its connection to the intended source or package.
- **Live/public:** an independent observation of the named target's externally visible behavior, plus deployed identity when obtainable.

For a named production, public, or LIVE result, source and artifact evidence are intermediate. Do not report completion without observing the named target itself unless the user explicitly limited the claim to an earlier boundary.

Matching names, timestamps, branches, or version strings are insufficient when stronger immutable identity is practical.

## Method

1. State the exact claim and required boundaries.
2. Identify the strongest practical evidence for each boundary.
3. Run the smallest read-only check that can prove or disprove each part.
4. Compare identities across boundaries when delivery or deployment is claimed.
5. Stop when every required part has a verdict.

If a check fails, investigate only enough to explain why the claim is unproved. Do not repair unless the user starts separate authorized work.

## Verdicts

- **PASS:** direct evidence proves every required part of the claim.
- **FAIL:** direct evidence contradicts at least one required part.
- **BLOCKED:** required evidence cannot be obtained within current access or authority.

Report each required boundary with its verdict and decisive evidence, followed by one overall verdict. Use a table only when several boundaries make it clearer. Include the smallest concrete gap or next action for FAIL or BLOCKED.
