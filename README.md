# Codex Essentials

Codex Essentials is a small, OMX-independent package of retained Codex skills and native agents. It is based on selected workflows and role ideas from oh-my-codex (OMX), rewritten as lean, explicit, non-recursive contracts.

## Included skills

- `analyze`
- `diagnose`
- `self-check`
- `grill-me`
- `prototype`
- `tdd`
- `delivery-proof`
- `visual-proof`
- `adversarial-check`
- `wiki`
- `handoff`

Each skill remains a normal Codex skill rooted at `skills/<name>/SKILL.md`. Supporting files stay beside the entrypoint.

## Included native agents

- `analyst`
- `architect`
- `code-reviewer`
- `critic`
- `debugger`
- `dependency-expert`
- `executor`
- `explore`
- `explore-luna`
- `git-master`
- `planner`
- `researcher`
- `test-engineer`
- `verifier`
- `vision`
- `writer`

Each native agent is stored as `agents/<name>.toml`.

## Routing matrix

[`routing-matrix.json`](routing-matrix.json) is the package-level source of truth for pairing task shapes, skills, and optional native subagents. It records invocation, authority, evidence, and stop boundaries without enabling automatic routing.

Skills never launch subagents themselves. The current task owner may add only a matrix-listed native subagent when its stated evidence gap applies, and the owner remains responsible for integration and the final claim. Model selection remains in `agents/<name>.toml` and is not duplicated in the matrix.

## Boundaries

- This repository is the authoring source. Installed copies under `C:\Users\growlee\.codex\skills` and `C:\Users\growlee\.codex\agents` are runtime mirrors managed through an explicit verify-first synchronization script.
- The kit does not contain hooks, automatic routing, workflow state, background services, notification dispatch, or self-repair loops.
- The routing matrix is declarative. It does not activate skills, launch agents, or create a lifecycle.
- Automatic loop prevention is a short global `AGENTS.md` invariant; `$self-check` is an explicit-only, read-only diagnostic and does not implement lifecycle automation.
- Runtime synchronization is explicit and verify-first; the package does not install hooks or background services.
- No included skill requires the OMX CLI or runtime.

## Validation

Validate the complete package without installing dependencies:

```powershell
.\scripts\validate-package.ps1
.\scripts\test-routing-matrix.ps1
```

Verify installed runtime mirrors without changing them:

```powershell
.\scripts\sync-runtime.ps1
```

Synchronize only manifest-listed skills and agents after reviewing reported drift:

```powershell
.\scripts\sync-runtime.ps1 -Mode Apply
```

`Apply` copies authoring sources and verifies their hashes. It never deletes runtime-only files, adds hooks, or enables automatic synchronization.
