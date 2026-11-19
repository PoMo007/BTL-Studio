# BTL-Studio

A prompt-driven assistant ("agent") for DAW work, built on [Lemon Studio](https://github.com/ItsAlphaNeon/Lemon-Studio)'s
control plane. You describe a task in plain language ("put 4 bars between every audio clip and a pattern named after
each file on track 2"); the agent turns it into control-plane commands and applies them to the open project.

- `installer/` - Windows installer / updater for Lemon Studio (PowerShell). See `installer/README-FA.txt`.
- `agent/` - the agent itself (not written yet).
- `HANDOFF.md` - **start here if you are an AI assistant continuing this project.**

This repository is public: never commit API keys. Keys go in a local `config.json` (git-ignored).
