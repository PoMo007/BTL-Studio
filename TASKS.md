# Task queue

Format: `[ ]` open, `[x]` done (with date and commit). Newest handoff note at the bottom. Every assistant updates this.

## Next up (in order)
- [ ] 1. Make GitHub the delivery channel: fork `ItsAlphaNeon/Lemon-Studio` to `PoMo007/Lemon-Studio` (owner action),
         install the Claude GitHub App on the fork, then add a GitHub Actions workflow that builds the Windows exe on every
         push and publishes it as a release asset, so the owner never compiles locally or moves zips.
- [ ] 2. Change `installer/Lemon-Studio-Setup.ps1` to download the prebuilt exe (fall back to building from source),
         and to `git pull` this repo into `...\Lemon-Studio\agent` on every start.
- [ ] 3. Write `agent/` v1 (provider-agnostic: DeepSeek / Gemini via config.json), `hello` protocol check, `propose` flow.
- [ ] 4. First end-to-end task: 4-bar gaps between audio clips + patterns named after files on track 2.
- [ ] 5. Diagnostics script (one text file the owner can paste into a chat).
- [ ] 6. FL compatibility test pack (docs/FL-COMPAT.md): tiny sample projects + checklist for the owner.

## Needs the owner
- [ ] Verify installer on Windows 11 and send the newest file from `C:\DAW\Image-Line\Lemon-Studio\logs\`.
- [ ] Choose the agent's model provider (DeepSeek or Gemini).

## Handoff notes
- 2026-11-19: repo created, base files, installer v1 and Rule 0 written. Nothing of the agent exists yet.
