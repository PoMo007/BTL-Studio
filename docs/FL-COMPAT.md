# FL Studio <-> Lemon compatibility rules (Rule 0 details)

## What is known (from Lemon's source, `crates/os-flp`)
- Lemon opens FL `.flp` (FL 10+) and keeps anything it does not understand byte-for-byte on save.
- Lemon's own `.lemon` format is an FLP container: header chunk `LMhd` first, then the normal FLP chunks (every event
  keeps its FLP meaning), then an extra chunk `LMex` after them holding Lemon-only data (events 192 and up: icons, slot
  names/colours, performance settings, mixer checks, scaling, locks, `FEATURES` = what the project uses that an older
  Lemon cannot play, ...). Spec: `flp/lemon-format.md` in Lemon's specs repository.
- Saving as `.flp` (the "All files" save type with a `.flp` extension) is what the owner uses to hand projects to FL;
  the owner tested that FL opens such files and that Lemon opens FL projects. Treat it as working but young.

## Where a new feature's data may live (in order of preference)
1. **Nowhere new.** Express the feature with things FL already has (patterns, channels, automation, plugin state).
2. **Plugin-shaped.** Implement it as a plugin/instrument/effect. Its state is stored in the normal plugin-state events
   FL already knows, so FL treats it like any third-party plugin (missing plugin -> FL shows its normal "plugin not
   found" behaviour, project still opens).
3. **`LMex` chunk** (Lemon-only). Add a new event id above the existing ones, list the feature in `FEATURES`. Never
   put it inside FLP chunks.
4. **Sidecar file** next to the project (`name.flp.lemon.json`) for large or experimental data. FL ignores it.
Never: new events inside FLP chunks, reinterpreting FL event ids, changing FL-visible values to carry hidden data.

## Round-trip tests every feature must pass (record results in TASKS.md)
- A. Lemon `.lemon` -> save -> reopen in Lemon: feature intact.
- B. Lemon -> save as `.flp` -> open in FL (owner, manual): no error/warning; everything FL has is intact; the Lemon-only
  feature is either absent or a harmless stand-in.
- C. FL `.flp` -> open in Lemon -> save as `.flp` -> open in FL (owner, manual): nothing FL had is lost or changed.
- D. FL `.flp` saved by FL after step B (so FL has re-written it) -> open in Lemon: no crash; Lemon-only data may be
  lost, FL data must be intact.
Automated: use `os-flp` tests (`cargo test -p os-flp`), `flp-dump` (verifies round-trip) and a corpus of the owner's
projects when `OPENSTUDIO_FLP_CORPUS` is set. Always work on copies of real projects.

## Open questions (verify, do not assume)
- Does FL ignore an unknown trailing chunk (like `LMex`) in an `.flp`? Is `.flp` export from Lemon dropping `LMex`
  or keeping it? Check `os-flp` and ask the owner to test with a tiny project.
- Which Lemon features have no FL equivalent today (see Lemon `docs/status.md`) and what is the safest stand-in for each?
