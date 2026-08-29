# Codex Essentials

Codex Essentials is a small, OMX-independent Codex marketplace plugin plus a companion native-agent pack. It is based on selected workflows and role ideas from oh-my-codex (OMX), rewritten as lean, explicit, non-recursive contracts.

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

Each plugin skill remains a normal Codex skill rooted at `plugins/codex-essentials/skills/<name>/SKILL.md`. Supporting files stay beside the entrypoint.

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

Codex plugin manifests do not install native-agent TOML definitions. The agents therefore remain a separate, explicit component of this repository rather than being represented as plugin capabilities.

## Plugin installation

Add this GitHub repository as a marketplace, then install the skill plugin:

```powershell
codex plugin marketplace add growlee/codex-essentials --ref main `
  --sparse .agents/plugins `
  --sparse plugins/codex-essentials

codex plugin add codex-essentials@codex-essentials
```

Start a new Codex task after installation so the skill catalog is loaded from the installed plugin.

Native agents use a separate explicit synchronization step from a local checkout:

```powershell
.\scripts\sync-runtime.ps1 -Mode Verify -Components Agents
.\scripts\sync-runtime.ps1 -Mode Apply -Components Agents
```

The default `-Components All` remains available for existing direct-runtime installations that intentionally synchronize both skills and agents.

## Routing matrix

[`routing-matrix.json`](routing-matrix.json) is the package-level source of truth for pairing task shapes, skills, and optional native subagents. It records invocation, authority, evidence, and stop boundaries without enabling automatic routing.

Skills never launch subagents themselves. The current task owner may add only a matrix-listed native subagent when its stated evidence gap applies, and the owner remains responsible for integration and the final claim. Model selection remains in `agents/<name>.toml` and is not duplicated in the matrix.

## Boundaries

- This repository is the authoring source. Plugin skills live under `plugins/codex-essentials`; optional direct-runtime copies under `C:\Users\growlee\.codex\skills` and native-agent copies under `C:\Users\growlee\.codex\agents` are managed through an explicit verify-first synchronization script.
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
.\scripts\test-sync-runtime.ps1
```

Verify installed runtime mirrors without changing them:

```powershell
.\scripts\sync-runtime.ps1 -Mode Verify -Components All
```

Synchronize only manifest-listed skills and agents after reviewing reported drift:

```powershell
.\scripts\sync-runtime.ps1 -Mode Apply -Components All
```

`Apply` copies authoring sources and verifies their hashes. It never deletes runtime-only files, adds hooks, or enables automatic synchronization.

## License

Codex Essentials is released under the [MIT License](LICENSE).
