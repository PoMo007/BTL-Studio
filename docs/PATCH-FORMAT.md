# Patch format (for AI assistants WITHOUT git/GitHub access)

If you can push to GitHub yourself, do that and ignore this file. Otherwise finish your work by replying with ONE
patch the owner copies and applies with `tools/Sync.bat` (it commits and pushes). The patch is data only.

```
=== FILE: path/in/repo.md ===
full new content of the file (always the WHOLE file, not a fragment)
=== FILE: another/file.ps1 ===
...
=== DELETE: old/file.txt ===
=== MOVE: old/name.txt -> new/name.txt ===
=== MESSAGE ===
Short commit message in English
=== END ===
```

Rules
- Put the whole patch in ONE code block, so the owner copies it in one click. If a file itself contains triple
  backticks, wrap the patch in a block with four backticks.
- Every changed file is given in full. Never use "..." or "rest unchanged".
- Always include the updated `TASKS.md` and the Status section of `HANDOFF.md` (Rule: leave the project resumable).
- End with `=== END ===`. A patch without it is rejected (it was probably cut off).
- Paths are relative to the repo root, use `/`. Never touch `.git`, `config.json`, `.env`, keys, projects
  (`.flp`, `.lemon`), audio, or binaries; Sync refuses them.
- Do not put executable "run this" steps in the patch. Scripts are added as normal files and reviewed like code.
- Outside the patch, tell the owner in Persian (short): what changed, what to click to test, what you could not test.
- Rule 0 (FL compatibility) applies exactly as in `CLAUDE.md`.
