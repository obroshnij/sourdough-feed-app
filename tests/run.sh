#!/usr/bin/env bash
# The one command that says whether a branch is green. Owner: qa-engineer.
# Contract: docs/test-plan.md §1 (R-0 to R-9) and architecture.md §12.
#
#   tests/run.sh                    lints, then --import, then every tests/**/test_*.gd
#   tests/run.sh -- --filter=save   arguments after -- go to tests/run_tests.gd (R-7)
#   tests/run.sh --strict           a skipped test or lint counts as a failure (phase exit gate)
#   tests/run.sh --selftest         prove the runner catches every known false pass (R-9)
#
# Environment: GODOT (engine binary), RUN_TIMEOUT_S (outer timeout per Godot call, default 300).
# Exit 0 only when every step passed. The last line is always "RUN: PASS ..." or "RUN: FAIL ...".
# Written for the bash 3.2 that ships with macOS.

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
RUN_TIMEOUT_S="${RUN_TIMEOUT_S:-300}"
RESULT_RE='^RESULT: ([0-9]+) passed, ([0-9]+) failed, ([0-9]+) skipped$'

MODE=main
STRICT="${RUN_STRICT:-0}"
RUNNER_ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --selftest) MODE=selftest ;;
    --strict) STRICT=1 ;;
    --) shift; RUNNER_ARGS=("$@"); break ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "run.sh: unknown option $1 (see --help)"; echo "RUN: FAIL bad arguments"; exit 2 ;;
  esac
  shift
done

WORK="$(mktemp -d "${TMPDIR:-/tmp}/sourdough_run.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# Runs Godot with an outer alarm. SIGALRM survives exec, so a hang exits 142 (R-6).
# Never use --quit-after as a watchdog: it exits 0 on a hang.
godot_timed() {
  local limit="$1"; shift
  perl -e '$t = shift @ARGV; alarm $t; exec @ARGV or die "run.sh: cannot exec $ARGV[0]: $!\n"' \
    "$limit" "$GODOT" "$@"
}

# run_suite DIR IMPORT(1|0) QUIET(1|0) LIMIT [runner args...]
# Imports DIR (R-0), runs its tests/run_tests.gd, and judges the result (R-6).
# Sets SUITE_P, SUITE_F, SUITE_S. Returns 0 pass, 1 fail, 2 skipped (no project.godot).
run_suite() {
  local dir="$1" do_import="$2" quiet="$3" limit="$4"; shift 4
  local out="$WORK/suite_out.txt" err="$WORK/suite_err.txt" code line
  SUITE_P=0; SUITE_F=0; SUITE_S=0
  if [ ! -f "$dir/project.godot" ]; then
    echo "SKIP godot: no project.godot in $dir (it arrives with T1's contracts commit)"
    return 2
  fi
  if [ "$do_import" = 1 ]; then
    godot_timed "$limit" --headless --path "$dir" --import >"$WORK/import.txt" 2>&1
    code=$?
    if [ $code -ne 0 ]; then
      [ $code -eq 142 ] && echo "TIMEOUT: --import killed after ${limit} s" \
                        || echo "FAIL godot --import exited $code"
      tail -n 30 "$WORK/import.txt"
      return 1
    fi
  fi
  if [ "$quiet" = 1 ]; then
    godot_timed "$limit" --headless --path "$dir" -s res://tests/run_tests.gd -- "$@" >"$out" 2>"$err"
    code=$?
    cat "$out" "$err"
  else
    godot_timed "$limit" --headless --path "$dir" -s res://tests/run_tests.gd -- "$@" | tee "$out"
    code=${PIPESTATUS[0]}
  fi
  line="$(tail -n 1 "$out" | tr -d '\r')"
  if [ $code -eq 142 ]; then
    echo "TIMEOUT: the runner was killed after ${limit} s (a hang, or a runtime error in _init)"
    return 1
  fi
  if [[ ! "$line" =~ $RESULT_RE ]]; then
    echo "FAIL no RESULT line at the end of the output (exit $code): the runner did not finish, or failed to parse"
    return 1
  fi
  SUITE_P="${BASH_REMATCH[1]}"; SUITE_F="${BASH_REMATCH[2]}"; SUITE_S="${BASH_REMATCH[3]}"
  if [ "$SUITE_F" -gt 0 ] || [ $code -ne 0 ]; then
    [ $code -eq 0 ] && echo "FAIL the runner exited 0 but reported $SUITE_F failures"
    [ "$SUITE_F" -eq 0 ] && echo "FAIL the runner exited $code but reported 0 failures"
    return 1
  fi
  if [ "$SUITE_P" -eq 0 ]; then
    echo "FAIL no test passed: an empty run is a failure"
    return 1
  fi
  return 0
}

# ------------------------------------------------------------------ lints (python, repo root)

LINT_P=0; LINT_F=0; LINT_S=0

# run_lint NAME SCRIPT_REL ARGS...: runs a python3 tool from the repo root, exit 0 = pass.
run_lint() {
  local name="$1" script="$2"; shift 2
  local log="$WORK/lint_$name.txt" code
  if ! command -v python3 >/dev/null 2>&1; then
    echo "SKIP lint $name: python3 not found"; LINT_S=$((LINT_S + 1)); return
  fi
  if [ ! -f "$ROOT/$script" ]; then
    echo "FAIL lint $name: $script is missing"; LINT_F=$((LINT_F + 1)); return
  fi
  (cd "$ROOT" && python3 -I "$script" "$@") >"$log" 2>&1
  code=$?
  if [ $code -eq 0 ]; then
    echo "PASS lint $name: $(tail -n 1 "$log")"; LINT_P=$((LINT_P + 1))
  else
    echo "FAIL lint $name: python3 -I $script $* exited $code"; sed 's/^/    /' "$log"
    LINT_F=$((LINT_F + 1))
  fi
}

# The committed DIFF-01 traces must equal a fresh run of the reference model. Catches a
# sim.py change that nobody regenerated the traces for (test-plan §2.2).
lint_golden_fresh() {
  local fresh="$WORK/fresh_traces" committed="$ROOT/tests/golden/reference_traces"
  if ! command -v python3 >/dev/null 2>&1; then
    echo "SKIP lint golden-fresh: python3 not found"; LINT_S=$((LINT_S + 1)); return
  fi
  if (cd "$ROOT" && python3 -I tools/sim-reference/sim.py trace "$fresh") >"$WORK/golden.txt" 2>&1 \
      && diff -rq "$fresh" "$committed" >"$WORK/golden_diff.txt" 2>&1; then
    echo "PASS lint golden-fresh: tests/golden/reference_traces equals a fresh sim.py trace"
    LINT_P=$((LINT_P + 1))
  else
    echo "FAIL lint golden-fresh: tests/golden/reference_traces differs from python3 -I tools/sim-reference/sim.py trace"
    sed 's/^/    /' "$WORK/golden.txt" "$WORK/golden_diff.txt" | tail -n 30
    LINT_F=$((LINT_F + 1))
  fi
}

# ------------------------------------------------------------------ self-test (R-9)
#
# Each tests/runner_selftest/cases/<case>/ holds:
#   expect           "pass" or "fail": what run.sh must conclude
#   expect_output    optional, one fixed string per line that must appear in the output,
#                    so a case can't "fail" for the wrong reason
#   no_control       optional: don't add runner_selftest/test_control.gd (a passing test)
#   project/         files copied over a fresh project (base_project.godot as project.godot,
#                    plus the real tests/run_tests.gd and tests/lib/), so it can override them
#   include          optional, repo-relative paths copied into the project (for example a lint)
#   dot_godot/       optional, copied to .godot/ (a stale cache)
#   args, env        optional runner args (one per line) and KEY=VALUE lines for the run
#   timeout          optional outer timeout in seconds (default 60)
#   without_import   optional "pass" or "fail": the outcome when R-0's --import is skipped.
#                    Proves the import step is what makes the case come out right.

selftest_case() {
  local case_dir="$1" do_import="$2" expect="$3"
  local name proj limit log rc got
  name="$(basename "$case_dir")"
  proj="$WORK/case_${name}_$do_import"
  log="$WORK/case_${name}_$do_import.log"
  rm -rf "$proj"; mkdir -p "$proj/tests"
  cp "$ROOT/tests/runner_selftest/base_project.godot" "$proj/project.godot"
  cp "$ROOT/tests/run_tests.gd" "$proj/tests/"
  cp -R "$ROOT/tests/lib" "$proj/tests/lib"
  [ -f "$case_dir/no_control" ] || cp "$ROOT/tests/runner_selftest/test_control.gd" "$proj/tests/"
  if [ -f "$case_dir/include" ]; then
    while IFS= read -r rel || [ -n "$rel" ]; do
      [ -z "$rel" ] && continue
      mkdir -p "$proj/$(dirname "$rel")"; cp -R "$ROOT/$rel" "$proj/$rel"
    done <"$case_dir/include"
  fi
  [ -d "$case_dir/project" ] && cp -R "$case_dir/project/." "$proj/"
  [ -d "$case_dir/dot_godot" ] && cp -R "$case_dir/dot_godot" "$proj/.godot"
  limit=60; [ -f "$case_dir/timeout" ] && limit="$(tr -d ' \n' <"$case_dir/timeout")"
  (
    [ -f "$case_dir/env" ] && { set -a; . "$case_dir/env"; set +a; }
    args=()
    if [ -f "$case_dir/args" ]; then
      while IFS= read -r a || [ -n "$a" ]; do [ -n "$a" ] && args+=("$a"); done <"$case_dir/args"
    fi
    run_suite "$proj" "$do_import" 1 "$limit" ${args[@]+"${args[@]}"}
    rc=$?
    if [ $rc -eq 0 ] && [ "${RUN_STRICT:-0}" = 1 ] && [ "$SUITE_S" -gt 0 ]; then
      echo "FAIL strict: $SUITE_S skipped"; rc=1
    fi
    exit $rc
  ) >"$log" 2>&1
  rc=$?
  got=fail; [ $rc -eq 0 ] && got=pass
  if [ "$got" != "$expect" ]; then
    echo "  WRONG $name (import=$do_import): expected run.sh to $expect, it said $got"
    sed 's/^/      /' "$log" | tail -n 25
    return 1
  fi
  if [ "$do_import" = 1 ] && [ -f "$case_dir/expect_output" ]; then
    while IFS= read -r want || [ -n "$want" ]; do
      [ -z "$want" ] && continue
      if ! grep -qF -- "$want" "$log"; then
        echo "  WRONG $name: $got as expected, but the output lacks: $want"
        sed 's/^/      /' "$log" | tail -n 25
        return 1
      fi
    done <"$case_dir/expect_output"
  fi
  return 0
}

run_selftest() {
  local ok=0 bad=0 case_dir name expect
  echo "Runner self-test: each case is a throwaway project run through run.sh's own judge."
  for case_dir in "$ROOT"/tests/runner_selftest/cases/*/; do
    case_dir="${case_dir%/}"; name="$(basename "$case_dir")"
    expect="$(tr -d ' \n' <"$case_dir/expect")"
    if selftest_case "$case_dir" 1 "$expect"; then
      if [ -f "$case_dir/without_import" ] \
          && ! selftest_case "$case_dir" 0 "$(tr -d ' \n' <"$case_dir/without_import")"; then
        bad=$((bad + 1)); continue
      fi
      local note=""; [ -f "$case_dir/without_import" ] && note=", and $(tr -d ' \n' <"$case_dir/without_import") without --import"
      echo "  ok    $name: run.sh said $expect$note"
      ok=$((ok + 1))
    else
      bad=$((bad + 1))
    fi
  done
  if [ $bad -eq 0 ] && [ $ok -gt 0 ]; then
    echo "RUN: PASS selftest: $ok of $ok cases came out as expected"
    return 0
  fi
  echo "RUN: FAIL selftest: $bad of $((ok + bad)) cases came out wrong"
  return 1
}

# ------------------------------------------------------------------ main

if [ "$MODE" = selftest ]; then
  run_selftest
  exit $?
fi

echo "== lints"
run_lint copy tools/i18n/check_copy.py .
run_lint catalog tools/i18n/build_catalog.py . --check
run_lint sim-vectors tools/sim-reference/sim.py vectors
lint_golden_fresh

echo "== godot tests"
run_suite "$ROOT" 1 0 "$RUN_TIMEOUT_S" ${RUNNER_ARGS[@]+"${RUNNER_ARGS[@]}"}
SUITE_RC=$?

STATUS=PASS
GODOT_SUMMARY="godot $SUITE_P passed, $SUITE_F failed, $SUITE_S skipped"
[ $SUITE_RC -eq 2 ] && GODOT_SUMMARY="godot SKIPPED (no project.godot)"
[ $SUITE_RC -eq 1 ] && STATUS=FAIL
[ $LINT_F -gt 0 ] && STATUS=FAIL
if [ "$STRICT" = 1 ] && [ $((SUITE_S + LINT_S)) -gt 0 -o $SUITE_RC -eq 2 ]; then
  echo "FAIL --strict: skips are failures"; STATUS=FAIL
fi
echo "RUN: $STATUS ($GODOT_SUMMARY; lints $LINT_P passed, $LINT_F failed, $LINT_S skipped)"
[ "$STATUS" = PASS ]
