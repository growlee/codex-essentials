---
name: eli5
description: Create a beginner-friendly HTML picture explainer with big visuals and very little text. Use when the user invokes $eli5 or $codex-essentials:eli5 with a topic, types /eli5 followed by a topic, or asks for a simple picture explainer of how something works.
---

# ELI5

Explain the requested topic for someone with no prior knowledge, in the user's language. Build one HTML artifact where large illustrations carry the explanation and short, plain-language captions connect the ideas. Use familiar analogies without making the explanation misleading.

Save the artifact as a local `.html` file in the current task's workspace. Before delivery, open it once in an available local preview or browser and check that the main illustrations and captions render and any essential interaction works. If no suitable preview is available, read back the saved HTML and state that rendering remains unverified; do not install a browser or build a test harness for this check.

Provide a local file link and show the artifact in Codex when a suitable preview is available. Stop once the requested explainer is delivered; no deployment or application setup is implied.

Adapted for Codex from Thariq Shihipar's [ELI5](https://github.com/anthropics/claude-plugins-community/tree/a727be1c7bd6064419b6f60d71993a19198adc17/eli5), with independently worded instructions and local-file delivery in place of Claude's artifact and argument conventions.
