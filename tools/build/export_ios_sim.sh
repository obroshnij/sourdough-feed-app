#!/usr/bin/env bash
# iOS export for the simulator: Godot project export, Xcode simulator build, optional install and launch.
#
#   tools/build/export_ios_sim.sh          # export + xcodebuild -> build/ios-dd/.../Sourdough.app
#   tools/build/export_ios_sim.sh --run    # also install fresh on the simulator, launch, capture, time
#
# Env overrides: GODOT, PRESET (default "iOS"; "iOS (no shader baker)" for the A/B), DEVICE (simulator
# UDID, default the first available "iPhone 17 Pro"), CAPTURE_DIR, WAIT_S (seconds per launch, 8),
# RUNS (cold launches with --run, default 1).
#
# Two workarounds for Godot 4.7.2's official iOS template on Apple Silicon with the iOS 26.5 runtime
# (evidence in the Phase 2 toolchain report). Remove both when a template ships an arm64 simulator slice:
#  1. The template's simulator libgodot.a is x86_64 only and the runtime's dyld_sim is arm64 only, so the
#     arm64 device slice is retargeted to the simulator platform (retarget_ios_sim_lib.py).
#  2. That library needs two Metal constants the simulator SDK lacks (ios_sim_metal_stubs.m).
# The app is launched with the Compatibility renderer, as official simulator builds have no Metal.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
PRESET="${PRESET:-iOS}"
CAPTURE_DIR="${CAPTURE_DIR:-$ROOT/captures/toolchain}"
WAIT_S="${WAIT_S:-8}"
RUNS="${RUNS:-1}"
BUNDLE_ID="com.example.sourdough"
RUN=0
[[ "${1:-}" == "--run" ]] && RUN=1
SLUG="$(echo "$PRESET" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9\n' '-' | tr -s '-' | sed 's/-*$//')"
OUT="$ROOT/build/$SLUG"
DD="$ROOT/build/$SLUG-dd"
LOGS="$ROOT/build/logs"
mkdir -p "$OUT" "$LOGS"
# build/ is gitignored but sits in the project root: without .gdignore the import scans earlier
# export output (Xcode assets) and the export packs it into the PCK.
touch "$ROOT/build/.gdignore"
if [[ -z "${DEVICE:-}" ]]; then
	DEVICE="$(xcrun simctl list devices available -j | python3 -I -c '
import json, sys
devs = [d for r in json.load(sys.stdin)["devices"].values() for d in r if d["name"] == "iPhone 17 Pro"]
print(devs[0]["udid"] if devs else "")')"
fi
[[ -n "$DEVICE" ]] || { echo "ERROR: no available iPhone 17 Pro simulator; set DEVICE=<udid>"; exit 1; }

# 1. Import, then export the Xcode project. Windowed (no --headless) so the shader baker can run.
#    A windowed run is the editor, and it rewrites project.godot (drops default-valued keys and T1's header).
#    Snapshot it first and put the snapshot back, so the export never leaves an edit to commit.
cd "$ROOT"
cp project.godot "$LOGS/project.godot.before-export"
"$GODOT" --headless --path . --import >"$LOGS/ios_import.log" 2>&1
T0=$(date +%s)
set +e
"$GODOT" --path . --export-debug "$PRESET" "$OUT/Sourdough.ipa" >"$LOGS/$SLUG-export.log" 2>&1
RC=$?
set -e
cp "$LOGS/project.godot.before-export" project.godot
echo "Godot export ($PRESET): exit $RC in $(( $(date +%s) - T0 )) s (log: build/logs/$SLUG-export.log)"
sed 's/\x1b\[[0-9;]*m//g' "$LOGS/$SLUG-export.log" | grep -E "^(ERROR|WARNING)" | sort | uniq -c || true
[[ $RC -eq 0 && -d "$OUT/Sourdough.xcodeproj" ]] || { echo "ERROR: export failed"; exit 1; }
ls -la "$OUT/Sourdough.pck"

# 2. Simulator workarounds (see header), then the simulator build. No signing for the simulator.
SIM_LIB="$OUT/Sourdough.xcframework/ios-arm64_x86_64-simulator/libgodot.a"
if lipo -info "$SIM_LIB" | grep -q "architecture: x86_64$"; then
	python3 -I "$ROOT/tools/build/retarget_ios_sim_lib.py" "$OUT/Sourdough.xcframework/ios-arm64/libgodot.a" "$SIM_LIB"
fi
xcrun -sdk iphonesimulator clang -target arm64-apple-ios15.0-simulator -fobjc-arc \
	-c "$ROOT/tools/build/ios_sim_metal_stubs.m" -o "$OUT/ios_sim_metal_stubs.o"
T0=$(date +%s)
set +e
xcodebuild -project "$OUT/Sourdough.xcodeproj" -scheme Sourdough -configuration Debug -sdk iphonesimulator \
	-destination "id=$DEVICE" -derivedDataPath "$DD" CODE_SIGNING_ALLOWED=NO \
	OTHER_LDFLAGS="$OUT/ios_sim_metal_stubs.o" build >"$LOGS/$SLUG-xcodebuild.log" 2>&1
RC=$?
set -e
echo "xcodebuild: exit $RC in $(( $(date +%s) - T0 )) s (log: build/logs/$SLUG-xcodebuild.log)"
grep -E "error:|\*\* BUILD" "$LOGS/$SLUG-xcodebuild.log" | head -5 || true
APP="$DD/Build/Products/Debug-iphonesimulator/Sourdough.app"
[[ $RC -eq 0 && -d "$APP" ]] || exit 1
[[ $RUN -eq 1 ]] || exit 0

# 3. Fresh install per run (cold: empty container and shader cache), launch, time from the device log.
#    The 4.7.2 simulator build draws nothing (see the report), so timing stops at "main.tscn loaded".
xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE" -b >/dev/null
mkdir -p "$CAPTURE_DIR"
for i in $(seq 1 "$RUNS"); do
	xcrun simctl terminate "$DEVICE" "$BUNDLE_ID" 2>/dev/null || true
	xcrun simctl uninstall "$DEVICE" "$BUNDLE_ID" 2>/dev/null || true
	xcrun simctl install "$DEVICE" "$APP"
	START="$(date '+%Y-%m-%d %H:%M:%S')"
	LAUNCH_T="$(perl -MTime::HiRes=time -e 'printf "%.3f", time')"
	xcrun simctl launch "$DEVICE" "$BUNDLE_ID" --rendering-method gl_compatibility --rendering-driver opengl3 --verbose >/dev/null
	perl -e "select(undef,undef,undef,$WAIT_S)"
	DLOG="$LOGS/$SLUG-device-$i.log"
	xcrun simctl spawn "$DEVICE" log show --start "$START" --info --debug --style compact \
		--predicate "subsystem == \"$BUNDLE_ID\"" >"$DLOG" 2>/dev/null || true
	echo "Run $i: renderer: $(grep -o -E "(OpenGL API|Vulkan|Metal) .*" "$DLOG" | head -1 || true)"
	echo "Run $i: script errors $(grep -c "SCRIPT ERROR" "$DLOG" || true), engine errors $(grep -c ":ERROR\]" "$DLOG" || true)"
	python3 -I - "$DLOG" "$LAUNCH_T" "$i" <<'EOF'
import datetime, sys
log, launch, run = sys.argv[1], float(sys.argv[2]), sys.argv[3]
marks = {"first engine line": "Godot Engine v", "main.tscn loaded": "Completed load for: 'res://src/main/main.tscn'"}
for name, needle in marks.items():
    line = next((l for l in open(log, errors="replace") if needle in l), None)
    if line is None:
        print("Run %s: %s: not found" % (run, name))
        continue
    ts = datetime.datetime.strptime(line[:23], "%Y-%m-%d %H:%M:%S.%f").timestamp()
    print("Run %s: launch -> %s: %d ms (simulator estimate)" % (run, name, round((ts - launch) * 1000)))
EOF
done
SHOT="$CAPTURE_DIR/ios_sim_${SLUG}.png"
xcrun simctl io "$DEVICE" screenshot "$SHOT" >/dev/null 2>&1
echo "Screenshot: $SHOT   device logs: build/logs/$SLUG-device-*.log"
