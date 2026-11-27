# Build scripts

Owner: T1 (export configuration). See `docs/decisions.md` D-044, D-054 and D-058.

| Script | What it does | Status |
|---|---|---|
| `export_ios_device.sh` | Exports the iOS Xcode project (headless, preset "iOS (no shader baker)", Mobile renderer, Metal on the phone) and builds it for a real iPhone with `xcodebuild`. `--run` installs it on the paired iPhone, launches it and saves the console log. `--launch-only` relaunches the installed app and captures the log. `--verify` builds unsigned (`CODE_SIGNING_ALLOWED=NO`) to prove the export and compile without an Apple ID. `--help` lists every setting. | **`--verify` works** (2026-11-27): `** BUILD SUCCEEDED **`, export about 5 s, `xcodebuild` about 10 s on a fresh build folder. **Signed builds, install and launch wait for the user's Xcode sign-in.** Until then the script stops with "SIGNING NOT SET UP" and exit code 3. The log capture and summary were tested on the iOS simulator only. |
| `export_ios_sim.sh` | Exports the iOS Xcode project and builds it for the iPhone simulator. `--run` installs, launches and captures a screenshot. | **Boot and logic checks only.** No renderer draws on the iOS simulator here (D-044). Since Phase 3 the app loads `main.tscn` with 0 script errors, then crashes about a frame later with SIGSEGV in Godot's `RasterizerCanvasGLES3::_render_items`, because the simulator's OpenGL can't compile shaders or allocate buffers. Before Phase 3 it only showed a blank screen. See the iOS note on `production/board.md`. |
| `retarget_ios_sim_lib.py`, `ios_sim_metal_stubs.m` | **Unofficial workaround.** The stock 4.7.2 iOS template ships an x86_64-only simulator library, while this Mac's only simulator runtime is arm64-only. These rebuild the arm64 *device* library for the simulator platform and stub two Metal constants missing from the simulator SDK. | **Simulator boot checks only. Never use for device or release builds.** Drop them when an official template ships an arm64 simulator library. |
| `export_android_debug.sh` | Exports a debug APK from the prebuilt Android template (no Gradle). `--run` installs it on a running emulator, launches it and captures a screenshot and logcat. | **Deferred to the Android phase (D-054).** Not run since Phase 2, when it worked on the Pixel_9 AVD (Android 16, arm64) with the Vulkan Mobile renderer. The emulator GPU is software (llvmpipe), so its timings are not phone numbers. |

## iPhone builds (`export_ios_device.sh`)

**Local settings.** Copy `local.env.example` to `local.env` in this folder. `local.env` is gitignored. Every setting is optional:

| Setting | Unset means |
|---|---|
| `IOS_TEAM_ID` | Read from this Mac's Apple Development certificate (the certificate's team field), then from the Apple ID signed in to Xcode. |
| `IOS_DEVICE` | The first paired physical iPhone in `xcrun devicectl list devices`. A UDID, serial number or name also works. |
| `IOS_BUNDLE_ID` | `io.github.obroshnij.sourdough.dev`. The committed presets keep the `com.example.sourdough` placeholder until the release id is picked. |

The team ID and bundle id are passed to `xcodebuild` as `DEVELOPMENT_TEAM` and `PRODUCT_BUNDLE_IDENTIFIER`. They never touch a tracked file, so `git status` stays clean after a run. The exported Info.plist reads the bundle id from `$(PRODUCT_BUNDLE_IDENTIFIER)`.

**Privacy.** The team ID, UDID, serial number and device name are masked in all output: at most the first 3 characters plus "…", and fewer for short values. The raw logs in `build/logs/` are not masked. `build/` is gitignored; never commit or share those logs.

**First run on the iPhone** (the user does steps 1 to 3; the studio never handles Apple ID credentials):

1. Xcode > Settings > Accounts > + > Apple ID. A free Personal Team is enough.
2. On the iPhone, Developer Mode is on (Settings > Privacy & Security > Developer Mode). It already was on 2026-11-27.
3. Unlock the iPhone and keep it unlocked during the build. Then run `tools/build/export_ios_device.sh --run`. With `--run` the build targets the phone itself, so `-allowProvisioningDeviceRegistration` can register it with the free team. A device build waits for the phone and times out after about 60 s if it is locked.
4. The first launch fails until you trust the developer: Settings > General > VPN & Device Management > your Apple ID > Trust. Then run `tools/build/export_ios_device.sh --launch-only`.

**What `--run` prints**, labeled with the phone's model, for example "iPhone 13 Pro (device)": the renderer line, script, engine and shader error counts, launch to first engine line and to `main.tscn` loaded (Mac clock, includes the Wi-Fi log transfer), and engine start to `main.tscn` loaded (phone clock). After `WAIT_S` seconds (default 20) the script stops the app. Open it from the home screen to play. These are real device numbers (D-058). They replace Mac estimates where they exist (D-004).

**How the log is captured.** Godot logs to the unified log (os_log) on iOS, not to stdout. The script launches with `OS_ACTIVITY_DT_MODE=YES`, which copies os_log lines to stderr, as Xcode does. `devicectl ... --console` then streams them back. Every line in `build/logs/ios-device-console-*.log` starts with the Mac arrival time.

**Free team limits.** Apps signed by a free Personal Team expire after 7 days. Run `--run` again to refresh.

## Notes

- The iOS device export runs headless. With the shader baker off it needs no GPU, and headless leaves `project.godot` untouched. The simulator and Android scripts export windowed so their baker presets can run. A windowed export rewrites `project.godot`, and those scripts restore it automatically.
- Shader baker: the "iOS" and "Android" presets keep it on for the Phase 2 A/B, and their "(no shader baker)" twins have it off. Without the Metal Toolchain (not approved, D-044) the iOS baker only bakes SPIR-V. Device builds use "iOS (no shader baker)" (D-058).
- The Android export reads the JDK from Godot's own editor setting `export/android/java_sdk_path` (`JAVA_HOME` alone isn't enough). D-053 left it empty on this Mac until the Android phase.
- The Android debug keystore lives outside the repo, at `~/Library/Application Support/Godot/keystores/debug.keystore`. No keystore, password, certificate, provisioning profile or signing file is ever committed.
