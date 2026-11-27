#!/usr/bin/env bash
# Self-test stand-in for Godot (R-9): an --import that dies like 4.7.2's worker-thread crash
# (SIGABRT from libmalloc, test-plan §1). The first FAKE_ABORTS (default 1) --import calls in a project
# end with exit 134, what the shell reports for a SIGABRT death; a real signal would also leave a macOS
# crash report on every self-test run. Every other call runs the real engine at REAL_GODOT.
real="${REAL_GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
path=""
import=0
prev=""
for a in "$@"; do
  [ "$prev" = "--path" ] && path="$a"
  [ "$a" = "--import" ] && import=1
  prev="$a"
done
if [ "$import" = 1 ] && [ -n "$path" ]; then
  count_file="${FAKE_COUNT_FILE:-$path/.fake_aborts}"
  n="$(cat "$count_file" 2>/dev/null || echo 0)"
  if [ "$n" -lt "${FAKE_ABORTS:-1}" ]; then
    echo $((n + 1)) >"$count_file"
    echo "fake godot: simulated abort in a worker thread (pointer being freed was not allocated)"
    exit 134
  fi
fi
exec "$real" "$@"
