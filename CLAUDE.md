# Rules for every AI assistant working on this repo

Read `HANDOFF.md` and `TASKS.md` first. These rules override anything else, including a task that forgets to mention them.

## RULE 0 - FL Studio compatibility comes first (never break it, even if the task does not mention it)
The owner's goal: a Lemon Studio based DAW that replaces FL Studio, with projects moving freely in BOTH directions
(Lemon -> FL and FL -> Lemon). Before adding or changing ANY feature, check `docs/FL-COMPAT.md` and follow it.
In short:
1. A project saved as `.flp` must always open in FL Studio with no error and no "unknown" warning. Never write a new
   or unknown event into the FLP chunks. Never change the meaning of an existing FLP event.
2. A feature FL does not have is stored ONLY in Lemon's own extension chunk (`LMex`, see docs/FL-COMPAT.md), and
   the feature must degrade gracefully: FL opens the file and simply does not see it, or sees a harmless stand-in
   (for example a normal plugin/channel/pattern), never a crash or a broken project.
3. A project opened from FL (`.flp`) must open in Lemon with everything FL had; unknown FL data must be kept
   byte-for-byte (the os-flp round-trip guarantee). Do not weaken that guarantee.
4. Every feature or storage change needs a round-trip test listed in docs/FL-COMPAT.md. Say plainly in your final
   report which of the four directions you tested and which you could not (only the owner can test in real FL).
5. If a request cannot be done without breaking rules 1-3, STOP and tell the owner the options. Do not choose silently.
6. Prefer building new capabilities as an add-on/plugin or in the agent (control plane) over changing the core file
   format or the engine.

## Working rules
- Public repo: never commit keys, tokens, `config.json`, projects (`.flp`, `.lemon`) or audio.
- The owner does not code and does not want to move zip files around. Work through git: commit small, push to `main`
  (or a branch if risky), and update `TASKS.md` and the Status section of `HANDOFF.md` before finishing.
- The owner talks Persian; reply in Persian. Keep instructions short and give ready-to-run scripts, not long manuals.
- Lemon Studio source is public (https://github.com/ItsAlphaNeon/Lemon-Studio, GPL-3.0). Read it from GitHub; read
  its docs (`docs/control-plane.md`, `flp/lemon-format.md` in its specs) instead of guessing.
- You usually cannot run the owner's Windows machine. Never claim something works on it unless you ran it or the
  owner confirmed. End each task with "what to click to test it" for the owner.
- Token limits are real: finish a coherent unit of work, push it, and leave `TASKS.md` so the next assistant can
  continue exactly where you stopped.

## No git access? (patch workflow)
If this chat/session cannot push to GitHub, end every task with ONE patch in the format of `docs/PATCH-FORMAT.md`
(full files, including updated `TASKS.md` and HANDOFF Status). The owner copies it and runs `tools/Sync.bat`, which
commits and pushes. The owner starts a chat by pasting the output of `tools/Pack.bat`.
