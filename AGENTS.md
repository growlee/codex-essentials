# Codex Essentials — Repository Contract

This repository is the authoring source for the retained Codex skills and native agent definitions.

## Source ownership

- Edit skills only under `plugins/codex-essentials/skills/<name>/`.
- Edit native agents only under `agents/<name>.toml`.
- Treat copies under `~/.codex/skills` and `~/.codex/agents` as installed runtime mirrors, not authoring sources.
- Do not edit an installed copy without making the corresponding source change here.
- Treat package changes as source-only unless the current user request explicitly includes installation, synchronization, activation, or a live Codex update.

## Change rules

- Read the complete affected skill or agent definition before editing it.
- Keep contracts small, bounded, and outcome-focused.
- Prefer direct execution and native Codex capabilities over new workflow layers.
- Do not add hooks, automatic routing, workflow state, background services, notifications, automatic updates, retry loops, or self-repair mechanisms.
- Preserve each skill's invocation and authority boundaries.
- Do not turn a skill into an automatic workflow, lifecycle, or recursive self-repair mechanism.
- Use the system `skill-creator` instructions when creating or materially changing a skill.
- Reuse existing files and patterns before adding abstractions or dependencies.

## Package consistency

When adding, removing, or renaming a skill or agent:

- Update `package-manifest.json`.
- Update `routing-matrix.json` so every skill has one route and every agent remains classified.
- Update `README.md`.
- Keep `.codex-plugin/plugin.json` and `.agents/plugins/marketplace.json` aligned with the package identity and plugin path.
- Keep skill directory names, skill frontmatter names, agent filenames, and agent `name` fields consistent.
- Preserve the global model-routing policy; do not duplicate or independently redefine it here.

`routing-matrix.json` owns only task-shape, invocation, authority, optional-subagent, result, and stop boundaries. It must not contain model assignments or imply that a skill launches a subagent.

## Verification

After changes, run:

```powershell
.\scripts\validate-package.ps1
.\scripts\test-routing-matrix.ps1
.\scripts\test-sync-runtime.ps1
python .\scripts\test-install-agents.py
```

Also verify that:

- the manifest lists exactly the skills and agents present in the repository;
- the plugin manifest exposes exactly the packaged skills and no hooks, MCP servers, apps, or native-agent claims;
- the marketplace entry points to `./plugins/codex-essentials` and matches the package name and versioned plugin manifest;
- the routing matrix lists every manifest skill and agent, references only packaged agents, and preserves explicit-only invocation metadata;
- changed runtime mirrors match their repository sources when synchronization was requested;
- no OMX dependency, hook, workflow state, or unfinished placeholder was introduced.

Run only the smallest additional checks needed to prove the changed behavior. Stop after the requested change is validated; do not enter repeated review or self-repair loops.

## Safety and Git

- Preserve unrelated and uncommitted work.
- Do not discard, replace, or revert unrelated user changes.
- Do not clean, reset, commit, tag, push, publish, or change remotes unless explicitly requested.
- Do not modify global Codex configuration as an implicit part of a repository change.
