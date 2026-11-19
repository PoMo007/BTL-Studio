# Task queue

Format: `[ ]` open, `[x]` done (with date and commit). Newest handoff note at the bottom. Every assistant updates this.

## Next up (in order)
- [x] 1. (2026-11-20, Lemon-Studio f42291e; build green, release `latest` has 3 assets) Make GitHub the delivery channel: fork `ItsAlphaNeon/Lemon-Studio` to `PoMo007/Lemon-Studio` (owner action),
         install the Claude GitHub App on the fork, then add a GitHub Actions workflow that builds the Windows exe on every
         push and publishes it as a release asset, so the owner never compiles locally or moves zips.
- [x] 2. (2026-11-20, installer v2 pushed to BTL-Studio) Change `installer/Lemon-Studio-Setup.ps1` to download the prebuilt exe (fall back to building from source),
         and to `git pull` this repo into `...\Lemon-Studio\agent` on every start.
- [ ] 3. Write `agent/` v1 (provider-agnostic: DeepSeek / Gemini via config.json), `hello` protocol check, `propose` flow.
- [ ] 4. First end-to-end task: 4-bar gaps between audio clips + patterns named after files on track 2.
- [ ] 5. Diagnostics script (one text file the owner can paste into a chat).
- [ ] 6. FL compatibility test pack (docs/FL-COMPAT.md): tiny sample projects + checklist for the owner.

## Needs the owner
- [ ] Test installer v2: run `Check-Only.bat`, then `Install-or-Update.bat`, start `C:\DAW\Image-Line\Lemon-Studio\bin\lemonstudio.exe`.
- [ ] Note: upstream `CI` workflow fails on the fork (not ours, `BTL Build Windows` is green). Optionally disable `CI` in the fork's Actions tab.
- [ ] Verify installer on Windows 11 and send the newest file from `C:\DAW\Image-Line\Lemon-Studio\logs\`.
- [ ] Choose the agent's model provider (DeepSeek or Gemini).

## Handoff notes
- 2026-11-19: repo created, base files, installer v1 and Rule 0 written. Nothing of the agent exists yet.

- 2026-11-20: Fork build is green (run 44610206565), release `latest` has lemonstudio.exe, LemonStudio-Plugins.zip, build-info.json. Installer v2 (download prebuilt, sha256, backups, agent zip update) added; old compile script is now `Build-From-Source.ps1/.bat` (points to PoMo007/Lemon-Studio). README-FA updated. Rule 0: no format/engine change, no FLP round-trip needed. Installer untested on Windows. Next: task 3 (agent v1).
