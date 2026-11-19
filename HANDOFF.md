# HANDOFF - read this first

For any AI assistant (or person) continuing this project in a new chat. Keep this file current: update "Status" and
"Decisions" at the end of every working session.

## RULE 0 (highest priority)
FL Studio compatibility in both directions must never break. Read `CLAUDE.md` and `docs/FL-COMPAT.md` before any feature work.

## Goal
The owner wants a fast assistant inside a DAW for repetitive tasks, driven by prompts, e.g.
"put a 4-bar gap between every audio file in the playlist and, for each, add a pattern named after the file on track 2".
FL Studio has no external API for the playlist, so the plan is to use **Lemon Studio** (open-source FL-inspired DAW,
Rust, GPL-3, pre-alpha, https://github.com/ItsAlphaNeon/Lemon-Studio), which ships a **control plane** made for AI
assistants. It can open FL `.flp` projects (support is young; always work on copies).

## Owner / environment
- Speaks Persian; prefers ready-made scripts and zips over many manual commands. Reply in Persian unless told otherwise.
- Windows 11. Lemon Studio is installed beside FL Studio at `C:\DAW\Image-Line\Lemon-Studio`.
- AI sessions have NO access to the owner's machine. Work only through this repo; ask the owner to paste logs or the
  diagnostics file for real-world state.
- Model for the agent: undecided between DeepSeek (`deepseek-flash`, paid, very cheap, no free tier on the official page)
  and Gemini (3.5 Flash / 3.1 Flash-Lite have a free tier, but Iran is not a supported region, so a VPN is needed).
  Build the agent provider-agnostic: base URL, key and model name come from `config.json`.

## How the pieces fit
```
Lemon Studio (lemonstudio.exe --control 7777 --control-level propose)
        ^  JSON-RPC 2.0, one JSON per line, TCP 127.0.0.1:7777 (Windows takes ports only; needs the token in `hello`)
        |
agent/ (Python)  <->  LLM API (DeepSeek / Gemini / ...)
```
- Lemon's protocol is documented in its repo: `docs/control-plane.md` (read the current version, it changes).
  Methods: `hello` (gives `protocol`, currently 1), `state`, `notes`, `plugins`, `params`, `history`, `events`,
  `apply`, `propose`, `proposals`, `accept`, `discard`, `undo`, `redo`, `save`.
  Commands include `set_tempo`, `add_channel`, `add_pattern`, `add_clip`, `set_clip`, `delete_clip`, `set_notes`,
  `add_notes`, `add_track`, `add_effect`, `set_param`, ... Positions and lengths are in ticks (`state.ppq` per quarter).
- Every `apply` is ONE undo step named after the client. Default level for the agent: `propose` (the user approves).
- The agent must check `hello.protocol` and warn loudly on a mismatch instead of failing silently.
- Not yet supported by the control plane (as of the first check): markers, automation clips/points, clip groups,
  rendering and import through the protocol, pushing events (poll `events`). Verify against the current docs.

## Installer (`installer/`)
- (v2, current) `Install-or-Update.bat` runs `Lemon-Studio-Setup.ps1`: downloads release `latest` of PoMo007/Lemon-Studio (exe + plugins zip, sha256 check), backs up, updates `agent/` from this repo as a zip. No compiler. The text below describes the old v1, now `Build-From-Source.ps1/.bat`: checks Git, Rust (>= 1.85), VS C++ Build Tools, LLVM, installs
  only what is missing (winget), clones Lemon Studio into `C:\DAW\Image-Line\Lemon-Studio\src`, builds it with cargo,
  builds/installs the VST3+CLAP plugins, copies `lemonstudio.exe` to `bin\`. Run again = smart update (fetch, show changes,
  back up exe + settings, ff-merge, build, replace only on success, roll back source on failure).
- **Not yet tested on a real Windows machine.** First thing to do when the owner reports back: ask for the newest file
  in `C:\DAW\Image-Line\Lemon-Studio\logs\`.
- Planned: also `git pull` THIS repo into `...\Lemon-Studio\agent` on every start of `Start-Lemon-Agent-Mode.bat`
  (cheap, no build) so changes pushed here reach the owner without manual uploads.
- Planned: a diagnostics script that writes one text file (installed Lemon commit, `hello` protocol/version, project
  summary from `state`, last error, log tail) for the owner to paste into a chat.

## Status
- [x] Repo created (public), base files, installer v1, rules (CLAUDE.md / AGENTS.md / docs/FL-COMPAT.md) and TASKS.md committed.
- The task queue lives in `TASKS.md`.
- [x] Installer v2 (prebuilt download from fork release `latest`) committed; fork build green (2026-11-20).
- [ ] Installer v2 verified on the owner's Windows 11.
- [ ] Agent v1: connect, `hello`/protocol check, send `state` to the LLM, get commands back, `propose`, show result.
- [ ] First task end-to-end: spacing of audio clips by 4 bars + named patterns on track 2.
- [ ] Diagnostics script.
- [x] Installer also updates this repo (agent zip download, no git needed).

## Decisions
- Public repo -> never commit keys; `config.json`, logs and project/audio files are git-ignored.
- Changes to the agent live here. Changes to Lemon Studio itself would need a fork of it (installer URL is configurable).
- The Lemon source is public: read it from GitHub instead of asking the owner for files.
