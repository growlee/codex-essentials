# Grill Me decision record example

> Example only. This file demonstrates the shape of a durable `$grill-me` record.

- Topic: release strategy for a small Codex plugin
- Status: resolved

## Decision 1 — release scope

- Question: Should the first release include automatic hooks?
- Recommendation: No. Keep the first release explicit-only so every mutation remains user-authorized.
- Material tradeoff: Users perform one extra command, but behavior stays inspectable and reversible.
- User answer: Keep installation explicit.
- Current decision: Version 0.1.0 contains skills and a separate native-agent installer, with no hooks or post-install execution.

## Decision 2 — native agents

- Question: Should the plugin manifest claim that it installs native-agent TOML files?
- Recommendation: No. Codex plugin manifests do not own that installation surface.
- Material tradeoff: Agents require a separate step, but the package does not misrepresent its capabilities.
- User answer: Keep agents separate.
- Current decision: The marketplace installs skills; the portable installer synchronizes only manifest-listed agents.

## Summary

- Publish the skill plugin through the GitHub marketplace manifest.
- Install native agents through an explicit verify/apply command.
- Do not add hooks, background services, or automatic continuation.
