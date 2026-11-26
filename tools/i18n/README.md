# tools/i18n

`check_copy.py` checks every `Key | Text | Max` row in `docs/narrative.md`, `docs/events-catalog.md` and `docs/game-copy.md`: worst-case length, unique keys, banned words, the safety lint and the variant rule (game-copy §16). Owner: narrative-designer (D-028).
Run from the repo root: `python3 -I tools/i18n/check_copy.py .` Exit 0 means clean. It is the build gate for the generated `src/i18n/en.csv` (ADR-014, Phase 2).
