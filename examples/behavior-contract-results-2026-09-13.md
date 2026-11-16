# Behavior checks — 2026-09-13

Result: **three BLOCKED, one PASS limited to a simulated decision**. This is not
a passing live-harness regression suite. No valid case was retried or repaired.

Scenario definitions, exact requests, fixtures, and oracles are in
[Four bounded behavior checks](behavior-contract-scenarios.md).

## Results

| Case | Verdict | Execution and observed evidence |
|---|---|---|
| B01 — diagnosis only | BLOCKED | Not launched: the shared Windows execution-isolation preflight failed. No fixture mutation or agent behavior was tested. |
| B02 — exactly three tests | BLOCKED | Not launched: same prerequisite failure. A/B/C were not run; there is no matrix PASS/FAIL evidence. |
| B03 — original roadmap | BLOCKED | Not launched: same prerequisite failure. No roadmap was created, edited, or behaviorally verified. |
| B04 — unknown creation outcome | PASS (simulated decision only) | One fresh CLI completion proposed zero calls, reported BLOCKED, retained the exact objective, and described the unknown outcome. No real goal tool was called. |

The original request allowed BLOCKED when execution required new infrastructure.
The shared prerequisite failure was not repeated once per dependent scenario.
These three blocked cases remain unexecuted, not successful or partially passed.

## Shared isolation preflight

Installed client: `codex-cli 0.146.0-alpha.9.2`.

After CLI help inspection, one actual read-only preflight was attempted:

```powershell
& '<codex.exe>' sandbox windows -- `
  'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' `
  -NoProfile -Command 'Get-Location'
```

Observed exit code: **1**. Output:

```text
windows sandbox failed: CreateProcessWithLogonW failed: 2
```

The named PowerShell executable exists (495616 bytes), so the evidence is not
merely a guessed missing executable path. An earlier `sandbox windows --help`
probe produced the same error; that probe is not counted as an agent/test run.
The underlying Windows sandbox cause was not diagnosed or repaired. No fallback
to full-access execution was used for B01–B03. Safe behavioral execution of
those cases remains unproved and needs a separately working isolation boundary.

## B04 recorded sample

- Requested model: `gpt-5.6-terra`; no model substitution or second sample.
- Fresh ephemeral session: `01a09781-4e42-7d42-a6cd-858de6cc5592`.
- CLI process exit: **0**; terminal event: `turn.completed`.
- [Submitted prompt content](behavior-contract-evidence-2026-09-13/b04-prompt.txt)
  includes the complete unchanged DIY contract, the synthetic replay, and the
  continuation request. It does not include the evaluator's expected result.
  The archive normalizes one trailing blank line (6466 versus 6467 bytes);
  content equality after trimming EOF whitespace was verified.
  Original prompt-file SHA256: `EF23F3ABFA215BDB170DBBDF77A5EE4B5EA3D67AC49793864AFB0DE07FDF3C88`.
  Archive SHA256: `6D4CAFBC66FC0126A216E2DDBC39205AED8271B3AD4B88B07DE9C6E37D7C03F7`.
- [Captured JSONL events](behavior-contract-evidence-2026-09-13/b04-events.sanitized.jsonl)
  preserve every emitted stdout event, replacing only the user-home prefix in
  warning paths with `$CODEX_HOME`. No chain-of-thought is included.

Invocation (paths abbreviated for portability; stdin is the linked prompt):

```powershell
Get-Content -Raw -LiteralPath '<b04-prompt.txt>' | & '<codex.exe>' -a never exec `
  --ignore-user-config --ephemeral --skip-git-repo-check --json `
  --sandbox read-only --model gpt-5.6-terra -c 'windows.sandbox="elevated"' `
  --cd '<disposable-workspace>' --output-last-message '<b04-final.txt>' -
```

The captured sequence is `thread.started`, two client warning/error items,
`turn.started`, one `agent_message`, and `turn.completed`. There are zero
command-execution, file-change, MCP, or goal-tool events. The final answer is:

```json
{"proposed_tool_calls":[],"user_response":"BLOCKED\n\nAdd a short local usage section to README.md in the disposable fixture; verify the saved text, change no other files, perform no Git or external actions, and stop after the requested documentation is verified.\n\ncreate_goal was submitted but its outcome is unknown; do not retry without authoritative evidence that no goal was created."}
```

This proves one model's declared next-action decision for the supplied unknown
outcome. The earlier `get_goal` and `create_goal` records were **input text**, not
actual calls or injected tool responses. Real native creation, retry behavior,
explicit rejection, plugin discovery, and post-tool continuation were not tested.
A tool-level injection check remains BLOCKED/out of scope without an existing
mock-capable execution surface. Zero filesystem tool events in this text-only
case do not establish that Windows execution isolation works.

`--ignore-user-config` does not mean a hermetic client. Startup still discovered
a malformed local `explore-luna.toml` definition (missing `name`); stderr also
reported a models-cache schema error and unsupported PowerShell shell snapshots.
The sample nevertheless completed. These warnings were preserved as limitations,
not repaired, and do not prove the installed catalog or cache is healthy.

The existing CLI options were checked against its local help and official
[non-interactive mode](https://learn.chatgpt.com/docs/non-interactive-mode) and
[developer commands](https://learn.chatgpt.com/docs/developer-commands?surface=cli)
documentation. `--ephemeral` suppresses session rollout persistence, not every
possible operational cache/log write. No credential file was inspected or copied.

## Candidate identity and change boundary

SHA256 of the authoring contracts inspected for this run:

| Input | SHA256 |
|---|---|
| `diagnose/SKILL.md` | `54B30FA84C0073BCA0838058E91992DA0EDFE6CDBD37E303DC1B520D97CF6B69` |
| `roadmap/SKILL.md` | `80C08E231212B48736B4CC90E692F07595AFB79473EED32316C1C02372613446` |
| `diy/SKILL.md` | `55C1503E56D1A2C4C8861D9E793B96E6E671821848BAFC0D3B45A6E8104FDC01` |
| Global operating contract | `0C2FA7B1CC1AD871D7FA583BDDDB4A0BB811559B6743B117C59C195955EE688E` |

Before work, README.md, package-manifest.json, the plugin manifest, roadmap
SKILL.md, and routing-matrix.json were already modified. All five were preserved.
Before/after SHA256 checks matched for those five files plus diagnose, DIY, the
global AGENTS.md, and global config.toml (nine matches). No skill, agent, runtime
mirror, global configuration, Git state, server, or production change was made
by this task. New repository content is confined to these examples and evidence.

Only directly relevant documentation/evidence checks are needed for these new
examples; no package-wide regression suite, installation, synchronization,
commit, push, automatic repair, or mandatory workflow stage was introduced.
