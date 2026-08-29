# Codex Essentials

[![Validate](https://github.com/growlee/codex-essentials/actions/workflows/validate.yml/badge.svg)](https://github.com/growlee/codex-essentials/actions/workflows/validate.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Codex Essentials is a lean Codex marketplace plugin plus a companion native-agent pack. It keeps the useful task contracts and role ideas from [oh-my-codex (OMX)](https://github.com/Yeachan-Heo/oh-my-codex), but removes automatic routing, recursive repair loops, workflow state, and mandatory orchestration.

## Why

Large agent harnesses can spend more effort managing themselves than solving the user's task. Codex Essentials takes the opposite approach:

- work directly by default;
- invoke specialized skills explicitly when they add value;
- use native agents only for bounded, independently useful work;
- verify runtime copies before changing them;
- stop when the requested outcome is proved.

The result is a small package whose behavior can be inspected, tested, and installed without hooks or background services.

## What it demonstrates

| Area | Implementation |
|---|---|
| Codex packaging | GitHub-compatible marketplace and plugin manifests |
| Skill design | 11 bounded skills with explicit authority and stop conditions |
| Agent design | 16 typed native-agent definitions kept separate from the plugin |
| Routing | Declarative, non-executing skill/agent matrix |
| Safety | No hooks, automatic routing, workflow state, or self-repair lifecycle |
| Delivery | Package validation, routing tests, sync tests, portable agent installation, and CI |

## Skills

| Skill | Purpose |
|---|---|
| `analyze` | Trace architecture, behavior, dependencies, and change impact |
| `diagnose` | Find the most likely root cause of a concrete failure |
| `self-check` | Detect repeated work or reopened settled decisions without creating a loop |
| `grill-me` | Resolve material decisions through a focused interview and durable record |
| `prototype` | Build a disposable experiment for one concrete question |
| `tdd` | Drive an explicitly requested change from a failing test |
| `delivery-proof` | Validate a delivery claim against concrete evidence |
| `visual-proof` | Validate visible behavior through rendered or runtime evidence |
| `adversarial-check` | Challenge a candidate against bounded failure modes |
| `wiki` | Produce evidence-grounded project documentation |
| `handoff` | Prepare a bounded, verifiable continuation contract |

The plugin skills live under [`plugins/codex-essentials/skills`](plugins/codex-essentials/skills). Native agents remain in [`agents`](agents) because Codex plugin manifests do not install agent TOML definitions.

## Examples

- [`grill-me` decision record](examples/grill-me-decision-record.md) shows how answers remain durable without becoming workflow state.
- [`self-check` loop stop](examples/self-check-loop-stop.md) shows how repeated work is stopped without retry counters or recursive repair.

## Install the plugin

Prerequisite: a Codex CLI build that provides `codex plugin marketplace` and `codex plugin add`.

```powershell
codex plugin marketplace add growlee/codex-essentials --ref v0.1.0 `
  --sparse .agents/plugins `
  --sparse plugins/codex-essentials

codex plugin add codex-essentials@codex-essentials
```

Start a new Codex task after installation so the skill catalog is reloaded.

## Install the native agents

Clone the repository, then use the dependency-free portable installer. `Verify` is read-only. `Apply` installs missing manifest-listed agents but preserves changed definitions and never prunes unrelated runtime files.

```bash
python scripts/install-agents.py --mode verify
python scripts/install-agents.py --mode apply
python scripts/install-agents.py --mode verify
```

Pass `--runtime-root <path>` to target a non-default Codex home. The default is `$CODEX_HOME` when set, otherwise `~/.codex`.

To replace a changed managed agent, inspect the reported drift first and opt in explicitly:

```bash
python scripts/install-agents.py --mode apply --replace-changed
```

Each replaced definition is preserved beside it as `<name>.toml.bak`. The installer refuses to overwrite an existing backup.

The existing PowerShell workflow remains available for users who intentionally synchronize skills, agents, or both:

```powershell
./scripts/sync-runtime.ps1 -Mode Verify -Components Agents
./scripts/sync-runtime.ps1 -Mode Apply -Components Agents
```

## Architecture

```text
codex-essentials/
├─ .agents/plugins/marketplace.json
├─ plugins/codex-essentials/
│  ├─ .codex-plugin/plugin.json
│  └─ skills/
├─ agents/
├─ examples/
├─ scripts/
├─ package-manifest.json
└─ routing-matrix.json
```

[`routing-matrix.json`](routing-matrix.json) records task shape, invocation, authority, optional-agent conditions, expected result, and stop boundaries. It is declarative: it does not activate skills or launch agents. The current task owner remains responsible for integration and final claims.

## Compatibility

| Component | Supported path | Validation |
|---|---|---|
| Marketplace plugin | Codex CLI plugin commands | System plugin validator and package tests |
| Native-agent installer | Python 3.9+ on Windows, Linux, and macOS | CI matrix using temporary runtime roots |
| Full runtime sync | PowerShell 7 on Windows | Windows CI and no-prune tests |

## Validation

```powershell
./scripts/validate-package.ps1
./scripts/test-routing-matrix.ps1
./scripts/test-sync-runtime.ps1
python scripts/test-install-agents.py
```

The tests verify exact skill and agent coverage, explicit-only metadata, routing boundaries, drift detection, no-prune behavior, and agents-only installation.

## Design boundaries

- No hooks, automatic routing, workflow state, background services, notification dispatch, or self-repair loops.
- Skills never launch subagents themselves.
- Runtime synchronization is explicit and verify-first.
- No included skill requires the OMX CLI or runtime.
- Installed copies are runtime mirrors; this repository remains the authoring source.

## Origin and license

Codex Essentials is an independent package derived from selected OMX workflow and role ideas. It is not affiliated with or endorsed by the OMX project.

Released under the [MIT License](LICENSE).
