# tools/i18n

Owner: narrative-designer (D-028). Run everything from the repo root.

| Script | What it does |
|---|---|
| `check_copy.py` | Checks every `Key \| Text \| Max` row in `docs/narrative.md`, `docs/events-catalog.md` and `docs/game-copy.md`: worst-case length, unique keys, banned words, the safety lint and the variant rule (game-copy §16). |
| `build_catalog.py` | Runs `check_copy.py`, then generates `src/i18n/en.csv` from the same rows (ADR-014). Any checker error stops the build and leaves `en.csv` as it was. |

```bash
python3 -I tools/i18n/check_copy.py .              # exit 0 means clean
python3 -I tools/i18n/build_catalog.py .           # check, then write src/i18n/en.csv
python3 -I tools/i18n/build_catalog.py . --check   # check, then exit 1 if en.csv is stale (for CI)
```

Last run, 2026-11-26: `wrote src/i18n/en.csv: 613 strings, 38906 bytes, sha256 6a15a2e29c65b71e`. A second run printed `unchanged.` with the same hash.

**`en.csv` format.** Header `keys,en`. One row per key, sorted by key. UTF-8 without a BOM, LF line endings. Fields are quoted per RFC 4180 when they hold a comma, a quote or a line break. Straight quotes become curly (U+2018, U+2019, U+201C, U+201D). `{placeholders}` are left as they are for `tr(key).format({...})`. `**(sci)**` review marks are stripped. The same docs always give the same bytes, and the file is only rewritten when its bytes change.

**Rules for doc rows.** No backslashes: Godot's CSV import unescapes them. A word-initial apostrophe ('til) would come out as an opening quote, so type U+2019 directly. Nobody hand-edits `en.csv`. Godot imports it as `src/i18n/en.en.translation` (git-ignored). That filename is not yet confirmed by a Godot import.

`tools/.gdignore` keeps Godot from scanning `tools/`.
