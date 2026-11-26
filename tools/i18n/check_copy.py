#!/usr/bin/env python3
"""Copy check for Sourdough: the narrative docs' string tables and the code tracks'
src/i18n/pending_*.csv placeholder rows. Usage: check_copy.py <repo_root>"""
import csv
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
DOCS = ["docs/narrative.md", "docs/events-catalog.md", "docs/game-copy.md"]
PENDING_GLOB = "src/i18n/pending_*.csv"
CATALOG = "src/i18n/en.csv"

WORST = {
    "name": 16, "window": 18, "time": 8, "hours": 2, "days": 2,
    "start_date": 12, "end_date": 12, "grams": 3, "ratio": 5, "flour": 11,
    "smell": 19, "note": 19, "word": 12, "hint": 34,
}
BANNED = [
    "safe", "safely", "probably fine", "should be ok", "scrape", "scraping", "salvage",
    "save some", "just a little mold", "starving", "dying", "dead", "killed",
    "poor thing", "toxic", "poison", "danger", "tummy", "yummy", "nom", "wittle",
    "baby", "bestie", "vibes", "oopsie", "uh oh", "you forgot", "you neglected",
    "finally", "missed you", "daily streak", "gut", "probiotic", "immune", "cure",
    "health benefit",
]
# qa-engineer LINT-06 lists, mapped to our real key prefixes
QA_SAFETY_PREFIX = re.compile(
    r"^(STATUS_MOLDY|STATUS_UNHEALTHY|SMELL_MUSTY|SMELL_MOLDY|INSPECT_\w*_MOLDY|"
    r"INSPECT_\w*_UNHEALTHY|INSPECT_SURFACE_HOOCH_DARK|EVENT_WARNING_SIGNS|EVENT_MOLD_FOUND|"
    r"MOLD_|MEMORIAL_|NOTIF_WARNING|REASON_MOLDY|REASON_NOT_MOLDY)")
QA_SAFETY_BAD = ["safe to", "still good", "scrape", "skim off", "just remove", "fine to use",
                 "fine to eat", "ok to eat", "okay to eat"]
QA_HUNGER_PREFIX = re.compile(
    r"^(STATUS_HUNGRY|STATUS_DORMANT_STARVED|SMELL_ACETONE|SMELL_ALCOHOL|SMELL_STRONGLY_ACIDIC|"
    r"EVENT_HOOCH_FORMING|EVENT_HUNGRY_AGAIN|EVENT_FIRST_ACETONE|INSPECT_SURFACE_HOOCH|"
    r"INSPECT_\w*_HUNGRY|FEED_HOOCH|GLOSS_HOOCH)")
QA_HUNGER_BAD = ["danger", "unsafe", "toxic", "sick", "poison", "throw it out", "throw away"]
QA_ANY_BAD = ["probiotic", "gut health", "health benefit", "cure"]
# moldy messages that must say "discard" (titles, words, observations, buttons are always shown beside one)
MUST_DISCARD = re.compile(r"^(STATUS_MOLDY_(HINT|TAP)|SMELL_MOLDY_BODY|INSPECT_\w*MOLDY\w*_MEAN|"
                          r"MOLD_SHEET_BODY\w*|MOLD_FEED_BLOCKED|REASON_MOLDY_LOCKED)$")

ROW = re.compile(r"^\|\s*`([^`]+)`\s*\|\s*(.*?)\s*\|\s*(\d+)\s*\|\s*$")
PLACEHOLDER = re.compile(r"\{(\w+)\}")
errors, rows, seen = [], [], {}


def lint(where: str, key: str, val: str) -> None:
    """Key format, placeholders, banned words and the safety lists. Shared by doc rows
    and pending CSV rows. Length is checked only for doc rows, which carry a Max."""
    if not re.fullmatch(r"[A-Z][A-Z0-9_]*", key):
        errors.append(f"{where}: bad key {key}")
    for ph in PLACEHOLDER.findall(val):
        if ph not in WORST:
            errors.append(f"{where}: unknown placeholder {{{ph}}} in {key}")
    low = val.lower()
    for b in BANNED:
        if re.search(r"(?<![a-z])" + re.escape(b) + r"(?![a-z])", low):
            errors.append(f"{where}: banned '{b}' in {key}")
    if "!" in val and not key.startswith(("MILESTONE_", "ACH_")):
        errors.append(f"{where}: exclamation mark in {key}")
    if QA_SAFETY_PREFIX.match(key):
        for b in QA_SAFETY_BAD:
            if b in low:
                errors.append(f"{where}: QA safety lint '{b}' in {key}")
    if QA_HUNGER_PREFIX.match(key):
        for b in QA_HUNGER_BAD:
            if b in low:
                errors.append(f"{where}: QA hunger lint '{b}' in {key}")
    for b in QA_ANY_BAD:
        if b in low:
            errors.append(f"{where}: QA any lint '{b}' in {key}")
    if MUST_DISCARD.match(key) and "discard" not in low:
        errors.append(f"{where}: moldy message {key} lacks 'discard'")


for d in DOCS:
    text = (root / d).read_text(encoding="utf-8")
    for i, line in enumerate(text.splitlines(), 1):
        if "—" in line:
            errors.append(f"{d}:{i}: em dash")
        m = ROW.match(line)
        if not m:
            continue
        key, val, mx = m.group(1), m.group(2), int(m.group(3))
        val = val.replace("**(sci)**", "").strip()
        rows.append((d, i, key, val, mx))
        if key in seen:
            errors.append(f"{d}:{i}: duplicate key {key} (also {seen[key]})")
        seen[key] = f"{d}:{i}"
        lint(f"{d}:{i}", key, val)
        worst = PLACEHOLDER.sub(lambda mm: "X" * WORST.get(mm.group(1), 10), val)
        if len(worst) > mx:
            errors.append(f"{d}:{i}: {key} is {len(worst)} > {mx} (worst case): {val}")

keys = set(seen)
DESCS = ["wet_flour", "mildly_fruity", "fresh_yeasty", "yogurt", "pleasantly_tangy",
         "strongly_acidic", "alcohol", "acetone", "cheesy", "musty"]
for dsc in DESCS:
    for part in ["TITLE", "NOTE", "MEANING", "1", "2", "3"]:
        k = f"SMELL_{dsc.upper()}_{part}"
        if k not in keys:
            errors.append(f"missing {k}")
STATES = ["freshly_fed", "developing", "active", "near_peak", "at_peak", "collapsing", "hungry",
          "dormant_cold", "dormant_starved", "recovering", "unhealthy", "moldy"]
for st in STATES:
    for part in ["WORD", "HINT", "TAP"]:
        k = f"STATUS_{st.upper()}_{part}"
        if k not in keys:
            errors.append(f"missing {k}")
# P0 inspection coverage: every kind x state has OBS and MEAN (or the shared moldy / dormant split)
for kind in ["BUBBLES", "HEIGHT", "SURFACE", "CONSISTENCY"]:
    for st in ["FRESHLY_FED", "DEVELOPING", "ACTIVE", "NEAR_PEAK", "AT_PEAK", "COLLAPSING",
               "HUNGRY", "DORMANT", "UNHEALTHY"]:  # recovering reuses rise_phase lines
        obs = [k for k in keys if k.startswith(f"INSPECT_{kind}_{st}_") and "_OBS" in k]
        mean = [k for k in keys if k.startswith(f"INSPECT_{kind}_{st}_") and "_MEAN" in k]
        if not obs or not mean:
            errors.append(f"missing inspect {kind} {st} (obs={len(obs)}, mean={len(mean)})")
if "INSPECT_RECOVERING_MEAN" not in keys:
    errors.append("missing INSPECT_RECOVERING_MEAN")
# deterministic smell rule covers every variant within 300 feeds (qa AC-07.2)
for idx, dsc in enumerate(DESCS):
    got = {1 + (fc + idx) % 3 for fc in range(300)}
    if got != {1, 2, 3}:
        errors.append(f"variant rule misses variants for {dsc}: {got}")
    # no repeat on consecutive cycles
    if any((1 + (fc + idx) % 3) == (1 + (fc + 1 + idx) % 3) for fc in range(300)):
        errors.append(f"variant rule repeats back-to-back for {dsc}")

# Pending CSVs (architecture §10): the code tracks' placeholder rows. Same word and safety
# lint as the docs, no length check (no Max). A key must not be in the catalog (the docs,
# or the en.csv on disk) or in two pending files: keys are unique across all CSVs (LINT-11).
catalog_where = dict(seen)
cat_path = root / CATALOG
if cat_path.exists():
    with cat_path.open(newline="", encoding="utf-8") as f:
        for r in list(csv.reader(f))[1:]:
            if r and r[0] not in catalog_where:
                catalog_where[r[0]] = CATALOG
pending_where, by_pending = {}, {}
for p in sorted(root.glob(PENDING_GLOB)):
    rel = p.relative_to(root).as_posix()
    with p.open(newline="", encoding="utf-8") as f:
        reader = csv.reader(f)
        header = next(reader, None)
        if header != ["keys", "en"]:
            errors.append(f"{rel}:1: header must be keys,en (got {header})")
            continue
        by_pending[rel] = 0
        for r in reader:
            where = f"{rel}:{reader.line_num}"
            if not r or r == [""]:
                continue
            if len(r) != 2:
                errors.append(f"{where}: expected 2 columns (keys,en), got {len(r)}")
                continue
            key, val = r
            by_pending[rel] += 1
            if key in catalog_where:
                errors.append(f"{where}: {key} is also in the catalog ({catalog_where[key]}). "
                              f"Delete the pending row")
            if key in pending_where:
                errors.append(f"{where}: duplicate key {key} (also {pending_where[key]})")
            pending_where[key] = where
            if "—" in val:
                errors.append(f"{where}: em dash in {key}")
            lint(where, key, val)

by_doc = {}
for d, *_ in rows:
    by_doc[d] = by_doc.get(d, 0) + 1
print("strings:", len(rows), by_doc)
print("pending:", sum(by_pending.values()), by_pending)
if errors:
    print(f"{len(errors)} problem(s):")
    for e in errors:
        print("  " + e)
    sys.exit(1)
print("OK: lengths, keys, em dashes, banned words, QA lint lists, coverage, variant rule, "
      "pending CSVs")
