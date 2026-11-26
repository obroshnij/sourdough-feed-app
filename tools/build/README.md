# Build scripts

Owner: T1 (export configuration). See `docs/decisions.md` D-044.

| Script | What it does | Status |
|---|---|---|
| `export_android_debug.sh` | Exports a debug APK from the prebuilt Android template (no Gradle). `--run` installs it on a running emulator, launches it and captures a screenshot and logcat. | Works. Verified on the Pixel_9 AVD (Android 16, arm64) with the Vulkan Mobile renderer. The emulator GPU is software (llvmpipe), so its timings are not phone numbers. |
| `export_ios_sim.sh` | Exports the iOS Xcode project and builds it for the iPhone simulator. `--run` installs, launches and captures a screenshot. | **Boot and logic checks only.** No renderer draws on the iOS simulator here (Metal, Vulkan and Compatibility all fail to start), so the screen stays blank. |
| `retarget_ios_sim_lib.py`, `ios_sim_metal_stubs.m` | **Unofficial workaround.** The stock 4.7.2 iOS template ships an x86_64-only simulator library, while this Mac's only simulator runtime is arm64-only. These rebuild the arm64 *device* library for the simulator platform and stub two Metal constants missing from the simulator SDK. | **Simulator boot checks only. Never use for device or release builds.** Drop them when an official template ships an arm64 simulator library. |

Notes:
- The Android export reads the JDK from Godot's own editor setting `export/android/java_sdk_path` (`JAVA_HOME` alone isn't enough). On this Mac it points to Android Studio's JDK at `/Applications/Android Studio.app/Contents/jbr/Contents/Home`.
- The debug keystore lives outside the repo, at `~/Library/Application Support/Godot/keystores/debug.keystore`. No keystore, password or signing file is ever committed.
- The shader baker is off in development presets until real-device data exists (D-044).
- A windowed export rewrites `project.godot`. Both scripts restore it automatically.
