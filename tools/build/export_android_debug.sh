#!/usr/bin/env bash
# Debug APK from the prebuilt template (no Gradle), optionally installed and launched on an emulator.
#
#   tools/build/export_android_debug.sh            # export build/android/Sourdough-debug.apk
#   tools/build/export_android_debug.sh --run      # also boot the AVD, install, launch, capture
#
# Env overrides: GODOT, JAVA_HOME, ANDROID_HOME, AVD (default Pixel_9), CAPTURE_DIR (default captures/toolchain),
# PRESET (default "Android"; "Android (no shader baker)" for the A/B), RUNS (cold launches with --run, 1).
# No secrets live here. The debug keystore path and password are read from Godot's editor settings
# (export/android/debug_keystore, export/android/debug_keystore_pass), and the keystore is created
# there, outside the repo, only if it is missing.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
export JAVA_HOME="${JAVA_HOME:-/Applications/Android Studio.app/Contents/jbr/Contents/Home}"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
AVD="${AVD:-Pixel_9}"
CAPTURE_DIR="${CAPTURE_DIR:-$ROOT/captures/toolchain}"
EDITOR_SETTINGS="$HOME/Library/Application Support/Godot/editor_settings-4.7.tres"
PRESET="${PRESET:-Android}"
SLUG="$(echo "$PRESET" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9\n' '-' | tr -s '-' | sed 's/-*$//')"
APK="$ROOT/build/$SLUG/Sourdough-debug.apk"
PACKAGE="com.example.sourdough"
ADB="$ANDROID_HOME/platform-tools/adb"
RUN=0
[[ "${1:-}" == "--run" ]] && RUN=1

setting() { # value of a string editor setting, empty if absent
	sed -n "s|^$1 = \"\(.*\)\"$|\1|p" "$EDITOR_SETTINGS" | head -1
}

# 1. Preconditions Godot checks only late, with vague errors.
[[ -x "$JAVA_HOME/bin/java" ]] || { echo "ERROR: no java in JAVA_HOME=$JAVA_HOME"; exit 1; }
[[ -n "$(setting export/android/java_sdk_path)" ]] || {
	echo "ERROR: Godot editor setting export/android/java_sdk_path is empty. Godot refuses Android exports"
	echo "       without it. Set it once in Editor Settings > Export > Android to: $JAVA_HOME"
	exit 1
}
KEYSTORE="${GODOT_ANDROID_KEYSTORE_DEBUG_PATH:-$(setting export/android/debug_keystore)}"
[[ -n "$KEYSTORE" ]] || { echo "ERROR: editor setting export/android/debug_keystore is empty"; exit 1; }
case "$KEYSTORE" in "$ROOT"/*) echo "ERROR: keystore must live outside the repo: $KEYSTORE"; exit 1;; esac
if [[ ! -f "$KEYSTORE" ]]; then
	PASS="$(setting export/android/debug_keystore_pass)"
	[[ -n "$PASS" ]] || { echo "ERROR: editor setting export/android/debug_keystore_pass is empty"; exit 1; }
	mkdir -p "$(dirname "$KEYSTORE")"
	"$JAVA_HOME/bin/keytool" -genkeypair -v -keystore "$KEYSTORE" -storepass "$PASS" -keypass "$PASS" \
		-alias androiddebugkey -keyalg RSA -keysize 2048 -validity 10000 \
		-dname "CN=Android Debug,O=Android,C=US" >/dev/null
	echo "Created debug keystore (outside the repo): $KEYSTORE"
fi

# 2. Import, then export. Windowed (no --headless) so the shader baker has a rendering device.
cd "$ROOT"
mkdir -p "$(dirname "$APK")" build/logs
# build/ is gitignored but sits in the project root: without .gdignore the import scans earlier
# export output (Xcode assets) and the export packs it into the PCK.
touch "$ROOT/build/.gdignore"
# A windowed run is the editor, and it rewrites project.godot (drops default-valued keys and T1's header).
# Snapshot it first and put the snapshot back, so the export never leaves an edit to commit.
cp project.godot build/logs/project.godot.before-export
"$GODOT" --headless --path . --import >build/logs/android_import.log 2>&1
T0=$(date +%s)
set +e
"$GODOT" --path . --export-debug "$PRESET" "$APK" >"build/logs/$SLUG-export.log" 2>&1
EXPORT_RC=$?
set -e
cp build/logs/project.godot.before-export project.godot
echo "Godot export ($PRESET): exit $EXPORT_RC in $(( $(date +%s) - T0 )) s (log: build/logs/$SLUG-export.log)"
grep -E "^(ERROR|WARNING)" "build/logs/$SLUG-export.log" | sed 's/\x1b\[[0-9;]*m//g' | sort | uniq -c || true
[[ $EXPORT_RC -eq 0 && -f "$APK" ]] || { echo "ERROR: export failed"; exit 1; }
APKSIGNER="$(ls -d "$ANDROID_HOME"/build-tools/*/apksigner | sort -V | tail -1)"
"$APKSIGNER" verify --print-certs "$APK" | head -3
ls -la "$APK"
[[ $RUN -eq 1 ]] || exit 0

# 3. Boot the AVD if no device is attached, install, launch, capture.
if ! "$ADB" devices | grep -q "device$"; then
	"$ANDROID_HOME/emulator/emulator" -avd "$AVD" -no-snapshot-save -no-boot-anim >build/logs/emulator.log 2>&1 &
	"$ADB" wait-for-device
	until [[ "$("$ADB" shell getprop sys.boot_completed | tr -d '\r')" == "1" ]]; do perl -e 'select(undef,undef,undef,1)'; done
fi
# Each run is a fresh install (cold: no shader cache, no save). Two timings, both emulator estimates:
#  - TotalTime from `am start -W` (activity window's first frame)
#  - process start (logcat "Start proc") -> save.json written by Session.start() from Main._ready
mkdir -p "$CAPTURE_DIR"
for i in $(seq 1 "${RUNS:-1}"); do
	"$ADB" uninstall "$PACKAGE" >/dev/null 2>&1 || true
	"$ADB" install "$APK" >/dev/null
	"$ADB" logcat -c
	ACTIVITY="$("$ADB" shell cmd package resolve-activity --brief -c android.intent.category.LAUNCHER "$PACKAGE" | tail -1 | tr -d '\r')"
	echo "Run $i: $("$ADB" shell am start -W -n "$ACTIVITY" | grep -E "LaunchState|TotalTime" | tr -d '\r' | tr '\n' ' ')"
	SAVED=""
	for _ in $(seq 1 90); do # poll up to ~90 s; never fatal under set -e
		SAVED="$("$ADB" shell run-as "$PACKAGE" stat -c %y files/saves/save.json 2>/dev/null | tr -d '\r' || true)"
		[[ "$SAVED" == 20* ]] && break
		SAVED=""
		perl -e 'select(undef,undef,undef,1)'
	done
	perl -e 'select(undef,undef,undef,2)'
	LOGCAT="build/logs/$SLUG-logcat-$i.txt"
	"$ADB" logcat -d >"$LOGCAT"
	python3 -I - "$LOGCAT" "$SAVED" "$i" "$PACKAGE" <<'EOF'
import datetime, sys
logcat, saved, run, pkg = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
start = next((l for l in open(logcat, errors="replace") if "Start proc" in l and pkg in l), None)
if start is None or not saved:
    print("Run %s: proc start -> save.json: not measurable (start=%s, saved=%r)" % (run, start is not None, saved))
    sys.exit(0)
year = saved[:4]
t0 = datetime.datetime.strptime(year + "-" + start[:18], "%Y-%m-%d %H:%M:%S.%f")
t1 = datetime.datetime.strptime(saved[:26], "%Y-%m-%d %H:%M:%S.%f")
print("Run %s: proc start -> save.json written: %d ms (emulator estimate)" % (run, round((t1 - t0).total_seconds() * 1000)))
EOF
	echo "Run $i: $(grep " godot " "$LOGCAT" | grep -o -E "(Vulkan|OpenGL).*" | head -1); script errors $(grep -c "SCRIPT ERROR" "$LOGCAT" || true)"
done
"$ADB" exec-out screencap -p >"$CAPTURE_DIR/${SLUG}_${AVD}.png"
echo "Screenshot: $CAPTURE_DIR/${SLUG}_${AVD}.png   logcat: build/logs/$SLUG-logcat-*.txt"
