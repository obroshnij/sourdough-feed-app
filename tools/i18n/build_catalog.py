#!/usr/bin/env python3
"""Build the shipped string catalog, src/i18n/en.csv, from the narrative docs.

Usage, from the repo root:
    python3 -I tools/i18n/build_catalog.py .          # copy check, then write en.csv
    python3 -I tools/i18n/build_catalog.py . --check  # copy check, then exit 1 if en.csv is stale

Source: every `Key | Text | Max` row in the three docs below (game-copy.md §1.1).
Gate: check_copy.py runs first. Any checker error stops the build (ADR-014, D-028).
Output: header `keys,en`, one row per key sorted by key, RFC 4180 quoting, UTF-8 without
a BOM, LF line endings. Straight quotes become curly ones. `{placeholders}` are kept as is
for `tr(key).format({...})`. The same docs always give the same bytes, and the file is only
rewritten when its bytes change. Owner: narrative-designer. Nobody hand-edits en.csv.
"""
import argparse
import hashlib
import os
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
CHECKER = HERE / "check_copy.py"
OUT = Path("src/i18n/en.csv")
# Same list and row pattern as check_copy.py. The checker's string count is compared
# with ours below, so the two parsers can't drift apart unnoticed.
DOCS = ["docs/narrative.md", "docs/events-catalog.md", "docs/game-copy.md"]
ROW = re.compile(r"^\|\s*`([^`]+)`\s*\|\s*(.*?)\s*\|\s*(\d+)\s*\|\s*$")
KEY = re.compile(r"[A-Z][A-Z0-9_]*")
PLACEHOLDER = re.compile(r"\{(\w+)\}")
OPEN_AFTER = "([{“‘"  # a quote after one of these (or space, or nothing) opens


def curly(text: str) -> str:
    """Straight quotes to curly ones. A quote opens at the start, after a space or an
    opening bracket or quote. Anything else closes, so M.'s and it's get U+2019.
    A word-initial apostrophe ('til) would come out as U+2018: write U+2019 in the doc."""
    out: list[str] = []
    for c in text:
        prev = out[-1] if out else ""
        opening = prev == "" or prev.isspace() or prev in OPEN_AFTER
        if c == '"':
            out.append("“" if opening else "”")
        elif c == "'":
            out.append("‘" if opening else "’")
        else:
            out.append(c)
    return "".join(out)


def csv_field(s: str) -> str:
    """RFC 4180: quote a field that holds a comma, a quote, CR or LF, or edge spaces."""
    if any(ch in s for ch in ',"\r\n') or s != s.strip():
        return '"' + s.replace('"', '""') + '"'
    return s


def run_checker(root: Path) -> int:
    """Run the copy checker. Return its string count, or exit 1 if it found problems."""
    res = subprocess.run([sys.executable, "-I", str(CHECKER), str(root)],
                         capture_output=True, text=True, encoding="utf-8")
    sys.stdout.write(res.stdout)
    sys.stderr.write(res.stderr)
    if res.returncode != 0:
        sys.exit(f"build stopped: check_copy.py exited {res.returncode}. en.csv not written.")
    m = re.search(r"^strings: (\d+)", res.stdout, re.M)
    if not m:
        sys.exit("build stopped: no 'strings: N' line from check_copy.py.")
    return int(m.group(1))


def read_rows(root: Path) -> list[tuple[str, str]]:
    rows: list[tuple[str, str]] = []
    errors: list[str] = []
    seen: dict[str, str] = {}
    for d in DOCS:
        lines = (root / d).read_text(encoding="utf-8").splitlines()
        for i, line in enumerate(lines, 1):
            m = ROW.match(line)
            if not m:
                continue
            key, src = m.group(1), m.group(2)
            where = f"{d}:{i}"
            # Strip review marks the way the checker does, then tidy the spaces they leave.
            src = re.sub(r" {2,}", " ", src.replace("**(sci)**", "").strip())
            text = curly(src)
            if not KEY.fullmatch(key):
                errors.append(f"{where}: bad key {key}")
            if key in seen:
                errors.append(f"{where}: duplicate key {key} (also {seen[key]})")
            seen[key] = where
            if not text:
                errors.append(f"{where}: empty text for {key}")
            if "\\" in text:  # Godot's CSV import unescapes \n and friends
                errors.append(f"{where}: backslash in {key}; write the character itself")
            if text.count("“") != text.count("”"):
                errors.append(f"{where}: unbalanced double quotes in {key}: {text}")
            if PLACEHOLDER.findall(text) != PLACEHOLDER.findall(src):
                errors.append(f"{where}: placeholders changed in {key}")
            rows.append((key, text))
    if errors:
        print(f"{len(errors)} build problem(s):")
        for e in errors:
            print("  " + e)
        sys.exit("build stopped. en.csv not written.")
    return rows


def render(rows: list[tuple[str, str]]) -> bytes:
    lines = ["keys,en"]
    lines += [f"{csv_field(k)},{csv_field(t)}" for k, t in sorted(rows)]
    return ("\n".join(lines) + "\n").encode("utf-8")


def main() -> None:
    ap = argparse.ArgumentParser(description="Build src/i18n/en.csv from the narrative docs.")
    ap.add_argument("root", nargs="?", default=str(HERE.parents[1]), help="repo root")
    ap.add_argument("--check", action="store_true",
                    help="don't write; exit 1 if en.csv is missing or out of date")
    args = ap.parse_args()
    root = Path(args.root)

    checked = run_checker(root)
    rows = read_rows(root)
    if len(rows) != checked:
        sys.exit(f"build stopped: parsed {len(rows)} rows but check_copy.py counted {checked}.")
    data = render(rows)
    digest = hashlib.sha256(data).hexdigest()[:16]
    out = root / OUT
    current = out.read_bytes() if out.exists() else None
    summary = f"{OUT}: {len(rows)} strings, {len(data)} bytes, sha256 {digest}"

    if args.check:
        if current != data:
            sys.exit(f"STALE: {OUT} does not match the docs. "
                     "Run python3 -I tools/i18n/build_catalog.py .")
        print(f"OK, up to date. {summary}")
        return
    if current == data:
        print(f"unchanged. {summary}")
        return
    out.parent.mkdir(parents=True, exist_ok=True)
    tmp = out.with_name(out.name + ".tmp")
    tmp.write_bytes(data)
    os.replace(tmp, out)
    print(f"wrote {summary}")


if __name__ == "__main__":
    main()
