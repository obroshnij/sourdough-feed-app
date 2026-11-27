#!/usr/bin/env bash
# iOS export for the user's iPhone (D-058): Godot project export, Xcode device build, optional install, launch and log.
#
#   tools/build/export_ios_device.sh                # export + signed device build
#   tools/build/export_ios_device.sh --run          # also install on the iPhone, launch it and capture its console log
#   tools/build/export_ios_device.sh --launch-only  # launch the installed app and capture its log (no export, no build)
#   tools/build/export_ios_device.sh --verify       # export + unsigned device build (CODE_SIGNING_ALLOWED=NO), no Apple ID needed
#
# Local settings come from tools/build/local.env (gitignored; copy local.env.example). Environment variables win over it.
#   IOS_TEAM_ID    Apple team ID. Unset: read from the keychain's Apple Development certificate, then Xcode's account list.
#   IOS_DEVICE     UDID, serial number or name of the iPhone. Unset: the first paired physical iPhone in devicectl.
#   IOS_BUNDLE_ID  Development bundle id. Default io.github.obroshnij.sourdough.dev.
# Other overrides: GODOT; PRESET (default "iOS (no shader baker)": D-044, D-058); WAIT_S (seconds of log capture, default 20);
#   IOS_DESTINATION ("device" or "generic"; default "device" with --run, because free provisioning registers only a
#   destination phone, which must be unlocked; "generic/platform=iOS" otherwise); LAUNCH_ARGS (Godot arguments, default
#   --verbose, which prints the "Completed load" line the timing needs).
#
# Privacy: the team ID, UDID, serial number and device name never go into tracked files. Output shows at most their first
# 3 characters plus "…" (less for short values). Raw logs in build/logs/ are not masked: build/ is gitignored, never
# commit or share them.
# The export runs headless: with the shader baker off it needs no GPU, and headless leaves project.godot untouched.
# The script still snapshots project.godot and puts it back if anything rewrote it.
# Exit codes: 0 done, 1 failed, 2 bad usage or settings, 3 signing not set up (sign in to Xcode).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
PRESET="${PRESET:-iOS (no shader baker)}"
WAIT_S="${WAIT_S:-20}"
LAUNCH_ARGS="${LAUNCH_ARGS-"--verbose"}"
OUT="$ROOT/build/ios-device"
LOGS="$ROOT/build/logs"
LOCAL_ENV="$ROOT/tools/build/local.env"

MODE=build
case "${1:-}" in
	"") ;;
	--run) MODE=run ;;
	--launch-only) MODE=launch ;;
	--verify) MODE=verify ;;
	-h | --help) awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"; exit 0 ;;
	*) echo "ERROR: unknown option '$1'. Use --run, --launch-only, --verify or --help."; exit 2 ;;
esac
[[ "$WAIT_S" =~ ^[0-9]+$ && "$WAIT_S" -gt 0 ]] || { echo "ERROR: WAIT_S must be a whole number of seconds above 0."; exit 2; }
mkdir -p "$OUT" "$LOGS"

# ---------- helpers ----------
nap() { perl -e "select(undef, undef, undef, $1)"; }
# Shows at most the first 3 characters and never more than a third of the value, so a short device name stays hidden.
mask() {
	local s="${1:-}" k
	[[ -n "$s" ]] || { printf '(none)'; return; }
	k=$(( ${#s} / 3 )); (( k > 3 )) && k=3; (( k < 1 )) && k=1
	printf '%s…' "${s:0:$k}"
}
SECRETS=()
# Masks every known identifier in piped text, with the same rule as mask(). Values under 8 characters (a short device
# name) are masked only as whole words, so they don't cut into unrelated text.
scrub() {
	perl -CSDA -pe 'BEGIN { @s = grep { length($_) >= 3 } @ARGV; @ARGV = (); }
		for my $x (@s) { my $k = int(length($x) / 3); $k = 3 if $k > 3; $k = 1 if $k < 1;
			my $m = substr($x, 0, $k) . "\x{2026}";
			if (length($x) < 8) { s/(?<![[:alnum:]])\Q$x\E(?![[:alnum:]])/$m/g } else { s/\Q$x\E/$m/g } }' \
		-- ${SECRETS[@]+"${SECRETS[@]}"}
}
sign_in_help() {
	cat <<EOF
SIGNING NOT SET UP: $1
  1. Open Xcode > Settings > Accounts, click +, choose Apple ID and sign in. A free Personal Team is enough.
     The studio never handles Apple ID credentials (D-058).
  2. On the iPhone, Developer Mode must be on: Settings > Privacy & Security > Developer Mode.
  3. Run tools/build/export_ios_device.sh --run again. After the first install, trust the developer on the iPhone:
     Settings > General > VPN & Device Management > your Apple ID > Trust. Then run it with --launch-only.
  To prove the export and compile without signing: tools/build/export_ios_device.sh --verify
EOF
}

# ---------- 1. local settings (KEY=value lines; the environment wins) ----------
if [[ -f "$LOCAL_ENV" ]]; then
	while IFS='=' read -r key value || [[ -n "$key" ]]; do
		key="$(printf '%s' "$key" | tr -d '[:space:]')"
		case "$key" in IOS_TEAM_ID | IOS_DEVICE | IOS_BUNDLE_ID) ;; *) continue ;; esac
		value="$(printf '%s' "${value:-}" | sed -e 's/\r$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'$/\1/")"
		[[ -z "${!key:-}" && -n "$value" ]] && export "$key=$value"
	done <"$LOCAL_ENV"
	echo "Settings: tools/build/local.env"
else
	echo "Settings: no tools/build/local.env (optional; see local.env.example), using detection and defaults"
fi
IOS_BUNDLE_ID="${IOS_BUNDLE_ID:-io.github.obroshnij.sourdough.dev}"
[[ "$IOS_BUNDLE_ID" =~ ^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$ ]] || { echo "ERROR: IOS_BUNDLE_ID '$IOS_BUNDLE_ID' is not a reverse-DNS id."; exit 2; }
echo "Bundle id: $IOS_BUNDLE_ID"

# ---------- 2. the iPhone (needed to install and launch, and as the signed build's destination) ----------
DEVICECTL="$(xcrun -f devicectl)"
DEV_UDID="" DEV_ID="" DEV_NAME="" DEV_SERIAL="" DEV_ECID="" DEV_MODEL="" DEV_OS="" DEV_MODE="" DEV_PAIRING="" DEV_REALITY=""
if [[ "$MODE" != verify || "${IOS_DESTINATION:-}" == device ]]; then
	"$DEVICECTL" list devices --json-output "$LOGS/ios-device-devices.json" >/dev/null 2>&1 || true
	if [[ -s "$LOGS/ios-device-devices.json" ]]; then
		# Heredoc to a file, not inside $( ): bash 3.2 misparses heredocs within command substitution.
		python3 -I - "$LOGS/ios-device-devices.json" "${IOS_DEVICE:-}" >"$LOGS/.ios-device-pick" <<'EOF'
import json, sys
devs = json.load(open(sys.argv[1]))["result"]["devices"]
want = sys.argv[2]
def fields(d):
    hw, dp, cp = d.get("hardwareProperties", {}), d.get("deviceProperties", {}), d.get("connectionProperties", {})
    return [str(v or "") for v in (hw.get("udid"), d.get("identifier"), dp.get("name"), hw.get("serialNumber"), hw.get("ecid"),
            hw.get("marketingName") or hw.get("productType"), dp.get("osVersionNumber"), dp.get("developerModeStatus"),
            cp.get("pairingState"), hw.get("reality"))] + [hw.get("platform"), hw.get("deviceType")]
rows = [fields(d) for d in devs]
if want:  # any device devicectl knows, matched by UDID, CoreDevice id, name, serial number or ECID
    hits = [r for r in rows if want in r[:5]]
else:     # the first paired physical iPhone
    hits = [r for r in rows if r[9] == "physical" and r[10] == "iOS" and r[11] == "iPhone"]
if hits:
    print("\x1f".join(hits[0][:10]))
EOF
		IFS=$'\x1f' read -r DEV_UDID DEV_ID DEV_NAME DEV_SERIAL DEV_ECID DEV_MODEL DEV_OS DEV_MODE DEV_PAIRING DEV_REALITY \
			<"$LOGS/.ios-device-pick" || true
		rm -f "$LOGS/.ios-device-pick"
	fi
fi
SECRETS=("${IOS_TEAM_ID:-}" "$DEV_UDID" "$DEV_ID" "$DEV_NAME" "$DEV_SERIAL" "$DEV_ECID")
if [[ -n "$DEV_UDID" ]]; then
	[[ "$DEV_REALITY" == physical ]] && LABEL="$DEV_MODEL (device)" || LABEL="$DEV_MODEL (simulator)"
	echo "iPhone: $LABEL, iOS $DEV_OS, UDID $(mask "$DEV_UDID"), name $(mask "$DEV_NAME"), Developer Mode ${DEV_MODE:-n/a}, ${DEV_PAIRING:-unknown pairing}"
elif [[ "$MODE" == run || "$MODE" == launch || "${IOS_DESTINATION:-}" == device ]]; then
	if [[ -n "${IOS_DEVICE:-}" ]]; then
		echo "ERROR: devicectl does not know the device in IOS_DEVICE ($(mask "$IOS_DEVICE"))."
	else
		echo "ERROR: no paired iPhone found. Pair it once over USB (tap Trust on the phone), then check: xcrun devicectl list devices"
	fi
	exit 1
elif [[ "$MODE" == verify ]]; then
	echo "iPhone: not needed for --verify"
else
	echo "iPhone: none paired (only --run and --launch-only need one)"
fi
if [[ "$MODE" == run || "$MODE" == launch ]]; then
	[[ "$DEV_PAIRING" == paired || "$DEV_REALITY" != physical ]] || { echo "ERROR: the iPhone is not paired (state '$DEV_PAIRING'). Connect it over USB once and tap Trust."; exit 1; }
	[[ "$DEV_MODE" != disabled ]] || { echo "ERROR: Developer Mode is off on the iPhone. Turn it on: Settings > Privacy & Security > Developer Mode (the phone restarts)."; exit 1; }
fi

# ---------- 3. the team (signed builds only) ----------
if [[ "$MODE" == build || "$MODE" == run ]]; then
	if [[ -z "${IOS_TEAM_ID:-}" ]]; then
		python3 -I - >"$LOGS/.ios-device-teams" <<'EOF'
import plistlib, re, subprocess
seen = []
def add(team, source):
    if re.fullmatch(r"[A-Z0-9]{10}", team or "") and team not in [t for t, _ in seen]:
        seen.append((team, source))
# 1. Valid Apple Development signing identities. The team ID is the certificate subject's OU, not the ID in its name.
ids = subprocess.run(["security", "find-identity", "-v", "-p", "codesigning"], capture_output=True, text=True).stdout
valid = set(re.findall(r'\)\s+([0-9A-F]{40})\s+"Apple Development:', ids))
if valid:
    pems = subprocess.run(["security", "find-certificate", "-a", "-Z", "-p", "-c", "Apple Development"], capture_output=True, text=True).stdout
    for sha1, pem in re.findall(r"SHA-1 hash: ([0-9A-F]{40})\s+?.*?(-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----)", pems, re.S):
        if sha1 in valid:
            subj = subprocess.run(["openssl", "x509", "-noout", "-subject"], input=pem, capture_output=True, text=True).stdout
            m = re.search(r"OU\s*=\s*([A-Z0-9]{10})\b", subj)
            if m:
                add(m.group(1), "keychain certificate")
# 2. Teams of Apple IDs signed in to Xcode, which exist before Xcode makes a certificate. The key layout is not
#    documented, so search every dictionary that has a teamID.
try:
    raw = subprocess.run(["defaults", "export", "com.apple.dt.Xcode", "-"], capture_output=True).stdout
    def walk(o):
        if isinstance(o, dict):
            if isinstance(o.get("teamID"), str):
                add(o["teamID"], "Xcode account")
            for v in o.values():
                walk(v)
        elif isinstance(o, list):
            for v in o:
                walk(v)
    walk(plistlib.loads(raw))
except Exception:
    pass
for t, s in seen:
    print(t + "\t" + s)
EOF
		TEAMS="$(cat "$LOGS/.ios-device-teams")"
		rm -f "$LOGS/.ios-device-teams"
		COUNT="$(printf '%s' "$TEAMS" | grep -c . || true)"
		if [[ "$COUNT" -eq 0 ]]; then
			sign_in_help "no Apple development team on this Mac (no Apple Development certificate, no Apple ID in Xcode)."
			exit 3
		elif [[ "$COUNT" -gt 1 ]]; then
			echo "ERROR: several Apple teams found. Put the one to use in tools/build/local.env as IOS_TEAM_ID:"
			while IFS=$'\t' read -r t s; do echo "  $(mask "$t") ($s)"; done <<<"$TEAMS"
			exit 2
		fi
		IOS_TEAM_ID="${TEAMS%%$'\t'*}"
		TEAM_SOURCE="${TEAMS#*$'\t'}"
	else
		TEAM_SOURCE="tools/build/local.env or the environment"
	fi
	[[ "$IOS_TEAM_ID" =~ ^[A-Z0-9]{10}$ ]] || { echo "ERROR: IOS_TEAM_ID must be 10 capital letters or digits (got $(mask "$IOS_TEAM_ID"))."; exit 2; }
	SECRETS[0]="$IOS_TEAM_ID"
	echo "Team: $(mask "$IOS_TEAM_ID") (from $TEAM_SOURCE)"
fi

# ---------- 4. export and build ----------
# --run builds for the paired iPhone itself: free provisioning only registers a destination device, and xcodebuild needs the
# phone unlocked for that. A plain build and --verify use generic/platform=iOS and need no phone.
if [[ "$MODE" == verify ]]; then DD="$ROOT/build/ios-device-unsigned-dd"; else DD="$ROOT/build/ios-device-dd"; fi
if [[ "$MODE" == run ]]; then DEST_KIND="${IOS_DESTINATION:-device}"; else DEST_KIND="${IOS_DESTINATION:-generic}"; fi
case "$DEST_KIND" in
	device) DEST="id=$DEV_UDID" ;;
	generic) DEST="generic/platform=iOS" ;;
	*) echo "ERROR: IOS_DESTINATION must be 'device' or 'generic'."; exit 2 ;;
esac
APP="$DD/Build/Products/Debug-iphoneos/Sourdough.app"

if [[ "$MODE" != launch ]]; then
	cd "$ROOT"
	# build/ is gitignored but sits in the project root: without .gdignore the import scans earlier export output.
	touch "$ROOT/build/.gdignore"
	cp project.godot "$LOGS/project.godot.before-device-export"
	"$GODOT" --headless --path . --import >"$LOGS/ios-device-import.log" 2>&1 \
		|| { echo "ERROR: Godot import failed (log: build/logs/ios-device-import.log)"; exit 1; }
	T0=$(date +%s)
	set +e
	"$GODOT" --headless --path . --export-debug "$PRESET" "$OUT/Sourdough.ipa" >"$LOGS/ios-device-export.log" 2>&1
	RC=$?
	set -e
	if ! cmp -s project.godot "$LOGS/project.godot.before-device-export"; then
		cp "$LOGS/project.godot.before-device-export" project.godot
		echo "Note: the export rewrote project.godot; restored it."
	fi
	echo "Godot export ($PRESET, headless): exit $RC in $(( $(date +%s) - T0 )) s (log: build/logs/ios-device-export.log)"
	sed 's/\x1b\[[0-9;]*m//g' "$LOGS/ios-device-export.log" | grep -E "^(ERROR|WARNING)" | sort | uniq -c || true
	[[ $RC -eq 0 && -d "$OUT/Sourdough.xcodeproj" ]] || { echo "ERROR: export failed"; exit 1; }
	echo "PCK: $(( $(stat -f %z "$OUT/Sourdough.pck") / 1024 )) KiB"

	XB=(xcodebuild -project "$OUT/Sourdough.xcodeproj" -scheme Sourdough -configuration Debug -destination "$DEST" -derivedDataPath "$DD")
	if [[ "$MODE" == verify ]]; then
		XB+=(PRODUCT_BUNDLE_IDENTIFIER="$IOS_BUNDLE_ID" CODE_SIGNING_ALLOWED=NO build)
		XLOG="$LOGS/ios-device-unsigned-xcodebuild.log"
		KIND="unsigned"
	else
		XB+=(-allowProvisioningUpdates)
		[[ "$DEST_KIND" == device ]] && XB+=(-allowProvisioningDeviceRegistration)
		XB+=(DEVELOPMENT_TEAM="$IOS_TEAM_ID" PRODUCT_BUNDLE_IDENTIFIER="$IOS_BUNDLE_ID" CODE_SIGN_STYLE=Automatic build)
		XLOG="$LOGS/ios-device-xcodebuild.log"
		KIND="signed"
	fi
	[[ "$DEST_KIND" == device ]] && SHOWN_DEST="id=$(mask "$DEV_UDID")" || SHOWN_DEST="$DEST"
	echo "xcodebuild: $KIND Debug build for $SHOWN_DEST ..."
	T0=$(date +%s)
	set +e
	"${XB[@]}" >"$XLOG" 2>&1
	RC=$?
	set -e
	echo "xcodebuild: exit $RC in $(( $(date +%s) - T0 )) s (log: build/logs/$(basename "$XLOG"))"
	grep -E "error:|\*\* BUILD" "$XLOG" | head -6 | sed "s#$ROOT/##g" | scrub || true
	if [[ $RC -ne 0 || ! -d "$APP" ]]; then
		if grep -q -E "to be unlocked|Please unlock|Timed out waiting for all destinations|Unable to find a destination|is not connected|is busy" "$XLOG"; then
			echo "DEVICE: xcodebuild could not use the iPhone. Unlock it, keep it unlocked and on the same Wi-Fi (or on the cable) during"
			echo "  the build, then run again. A build without the phone: IOS_DESTINATION=generic (signing needs the phone registered once)."
		elif [[ "$KIND" == signed ]]; then
			if grep -q -E "No Account for Team|No Accounts|There are no accounts|requires a development team|No signing certificate|not signed in|session has expired|Sign in with your Apple ID" "$XLOG"; then
				sign_in_help "Xcode has no signed-in Apple ID for team $(mask "$IOS_TEAM_ID"), or no certificate for it."
				exit 3
			elif grep -q -E "has no devices|no devices from which to generate" "$XLOG"; then
				echo "PROVISIONING: the team has no registered iPhone yet. Unlock the iPhone and run with --run once; that build registers it."
			elif grep -q -E "Failed Registering Bundle Identifier|is not available|cannot be registered" "$XLOG"; then
				echo "PROVISIONING: Apple refused the bundle id '$IOS_BUNDLE_ID'. Set another IOS_BUNDLE_ID in tools/build/local.env."
			fi
		fi
		exit 1
	fi
	echo "App: ${APP#"$ROOT/"} ($(du -sh "$APP" | cut -f1 | tr -d ' '), bundle id $(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist"), $(lipo -archs "$APP/Sourdough"))"
	if [[ "$KIND" == unsigned ]]; then
		echo "Unsigned: proves the export and the device compile and link. It cannot be installed; sign in to Xcode for --run."
		exit 0
	fi
	codesign -dv "$APP" 2>&1 | grep -E "^(Authority|TeamIdentifier)=" | head -2 | scrub || true
fi
[[ "$MODE" == run || "$MODE" == launch ]] || exit 0

# ---------- 5. install (with --run), launch and capture the console log ----------
if [[ "$MODE" == run ]]; then
	T0=$(date +%s)
	if ! "$DEVICECTL" device install app --device "$DEV_UDID" "$APP" >"$LOGS/ios-device-install.log" 2>&1; then
		echo "ERROR: install failed (log: build/logs/ios-device-install.log):"
		grep -E "ERROR|rror:|Reason" "$LOGS/ios-device-install.log" | head -4 | scrub || true
		grep -q -i "developer mode" "$LOGS/ios-device-install.log" && echo "Turn on Developer Mode: Settings > Privacy & Security > Developer Mode."
		exit 1
	fi
	echo "Installed on $LABEL in $(( $(date +%s) - T0 )) s"
fi

CONSOLE="$LOGS/ios-device-console-$(date +%Y%m%d-%H%M%S).log"
PIDF="$LOGS/.ios-device-devicectl.pid"
rm -f "$PIDF"
LARGS=()
[[ -n "$LAUNCH_ARGS" ]] && read -r -a LARGS <<<"$LAUNCH_ARGS"
LAUNCH_T="$(perl -MTime::HiRes=time -e 'printf "%.3f", time')"
# Godot logs to os_log on iOS. OS_ACTIVITY_DT_MODE mirrors os_log to stderr, which --console streams back (as Xcode does).
# Every captured line gets the Mac's arrival time in front.
(
	DEVICECTL_CHILD_OS_ACTIVITY_DT_MODE=YES "$DEVICECTL" device process launch --device "$DEV_UDID" --terminate-existing \
		--console "$IOS_BUNDLE_ID" -- ${LARGS[@]+"${LARGS[@]}"} 2>&1 &
	echo $! >"$PIDF"
	wait
) 2>/dev/null | perl -MTime::HiRes=time -ne 'BEGIN { $| = 1 } printf "%.3f %s", time, $_' >"$CONSOLE" &
READER=$!
for _ in $(seq 1 50); do [[ -s "$PIDF" ]] && break; nap 0.1; done
DPID="$(cat "$PIDF")"
echo "Launched on $LABEL; capturing the console for up to $WAIT_S s ..."
END=$(( $(date +%s) + WAIT_S ))
while kill -0 "$DPID" 2>/dev/null && [[ $(date +%s) -lt $END ]]; do nap 0.2; done

# devicectl --console waits for the app to exit. Stop the app by its pid (from its own log lines), then let devicectl end.
STOP="the app exited by itself"
if kill -0 "$DPID" 2>/dev/null; then
	APID="$(grep -o -E 'Sourdough\[[0-9]+:' "$CONSOLE" | head -1 | tr -dc '0-9' || true)"
	STOP="log capture stopped after $WAIT_S s"
	if [[ -n "$APID" ]] && "$DEVICECTL" device process terminate --device "$DEV_UDID" --pid "$APID" >"$LOGS/ios-device-terminate.log" 2>&1; then
		STOP="app stopped after $WAIT_S s"
	fi
	for _ in $(seq 1 50); do kill -0 "$DPID" 2>/dev/null || break; nap 0.2; done
	if kill -0 "$DPID" 2>/dev/null; then
		kill -TERM "$DPID" 2>/dev/null || true
		nap 2
		kill -KILL "$DPID" 2>/dev/null || true
		STOP="$STOP; devicectl did not end, so it was killed and the app may still be running"
	fi
fi
wait "$READER" 2>/dev/null || true
rm -f "$PIDF"

# The summary is masked, then each line gets the label (kept out of the masking: a phone may be named like its model).
python3 -I - "$CONSOLE" "$LAUNCH_T" <<'EOF' | scrub | while IFS= read -r line; do echo "$LABEL: $line"; done
import datetime, re, sys
log, launch = sys.argv[1], float(sys.argv[2])
lines = open(log, errors="replace").read().splitlines()
def find(pattern):
    return next((l for l in lines if re.search(pattern, l)), None)
def mac(line):
    return float(line.split(" ", 1)[0])
def phone(line):
    m = re.match(r"\S+ (\d{4}-\d\d-\d\d \d\d:\d\d:\d\d\.\d+)([+-]\d{4})", line)
    return datetime.datetime.strptime(m.group(1) + m.group(2), "%Y-%m-%d %H:%M:%S.%f%z").timestamp() if m else None
renderer = r"\] ((OpenGL API|Vulkan [\d.]+|Metal [\d.]+) .*)"
r = find(renderer)
print("renderer: %s" % (re.search(renderer, r).group(1) if r else "not found"))
n = lambda tag: sum(1 for l in lines if "] [%s] " % tag in l)
print("script errors %d, engine errors %d, shader errors %d, warnings %d"
      % (n("SCRIPT ERROR"), n("ERROR"), n("SHADER ERROR"), n("WARNING")))
first = find(r"Godot Engine v")
main = find(r"Completed load for: 'res://src/main/main\.tscn'")
for name, line in (("first engine line", first), ("main.tscn loaded", main)):
    print("launch -> %s: %s" % (name, "%d ms (Mac clock, includes the log transfer)" % round((mac(line) - launch) * 1000) if line else "not found"))
if first and main and phone(first) and phone(main):
    print("engine start -> main.tscn loaded: %d ms (phone clock)" % round((phone(main) - phone(first)) * 1000))
crash = find(r"App terminated due to signal \d+")
if crash:
    print(crash.split(" ", 1)[1].strip())
if not first:
    for l in [l for l in lines if "ERROR" in l or "rror:" in l][:4]:
        print("  " + l.split(" ", 1)[1][:240])
    text = "\n".join(lines)
    if re.search(r"not been explicitly trusted|Untrusted|invalid code signature", text):
        print("TRUST: on the iPhone open Settings > General > VPN & Device Management, tap your Apple ID's developer app, tap Trust,"
              " then run: tools/build/export_ios_device.sh --launch-only")
    elif re.search(r"[Ll]ocked", text):
        print("LOCKED: unlock the iPhone, then run: tools/build/export_ios_device.sh --launch-only")
EOF
echo "$LABEL: $STOP. Console log: build/logs/$(basename "$CONSOLE")"
grep -q -E "Completed load for: 'res://src/main/main\.tscn'" "$CONSOLE" || exit 1
