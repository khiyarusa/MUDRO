# MUDRO — Android build report

Built locally on the development PC (Windows 10, i3-6100, 8 GB RAM, RX 580).

## Result

| Item | Value |
|---|---|
| APK | `local-builds/android/MUDRO-debug.apk` |
| Size | 38,087,636 bytes (36.3 MB) |
| SHA256 | 27300A666ACD01D7595A097FBA096E091DB5953970C3F9C55973261985DE4C20 |
| Package | `com.khiyarusa.mudro` |
| Version | code 1, name 1.0.0 |
| Label | MUDRO |
| minSdk | 24 |
| targetSdk / compileSdk | 36 |
| ABI | arm64-v8a |
| Orientation | userLandscape (sensor landscape) |
| Signing | debug keystore, verified by `apksigner verify --print-certs` |

## Toolchain actually used

| Component | Version / path |
|---|---|
| Godot | 4.7.2.stable.official.ed1daf0bf — `H:\Game\Engines\Godot\editor\Godot_v4.7.2-stable_win64_console.exe` |
| Export templates | 4.7.2.stable (`%APPDATA%\Godot\export_templates\4.7.2.stable`) |
| Android SDK | `F:\Unity\Editors\6000.3.11f1\Editor\Data\PlaybackEngines\AndroidPlayer\SDK` (build-tools 36.0.0, platform-tools, android-35/36 platform) |
| JDK | Temurin 17.0.20.1 (`AndroidPlayer\OpenJDK`, and `H:\Game\Engines\Android-SDK\toolchain\jdk17`) |
| adb | `…\AndroidPlayer\SDK\platform-tools\adb.exe` |

Note: Godot needs `APPDATA` to resolve `user://`, the export templates and the editor settings.
In bare automation shells that variable is missing, the engine falls back to a relative directory and
the export fails with "No export template found". `tools/local_build/common.ps1` now restores
`APPDATA`/`LOCALAPPDATA` before invoking the engine, which is why the scripted build works.

## Export command

```powershell
& $godot --headless --path . --export-debug "Android" `
    "local-builds/android/MUDRO-debug.apk"
```

or, with the helper script:

```powershell
.\tools\local_build\build_android_debug.ps1 -Install
```

## Manifest verification (`aapt2 dump badging`)

```
package: name='com.khiyarusa.mudro' versionCode='1' versionName='1.0.0'
minSdkVersion:'24'
targetSdkVersion:'36'
application-label:'MUDRO'
native-code: 'arm64-v8a'
```

`AndroidManifest.xml`:
* `screenOrientation=11` (user landscape) — the game never rotates to portrait;
* `glEsVersion=0x00030000` — OpenGL ES 3.0, matching the GL Compatibility renderer;
* no dangerous runtime permissions are requested (only Godot's debug `DUMP` permission).

## Device test — Samsung Galaxy A23

* Device: **SM-A235F**, Android 14, arm64-v8a — the exact target phone.
* `adb install -r` → `Success` (incremental install, ~5 s).
* Launched via the launcher; the game renders the main menu, career, stage select and a live race.
* Screenshots pulled from the device: `local-builds/screenshots/device_01.png` … `device_03.png`.
* No crash, no missing texture, no GL error in `logcat` during the session.

## What is *not* verified

* No formal frame-rate profiling was captured on the device (no GPU profiling tool available here);
  the desktop build runs at the 60 Hz cap with the same assets.
* Only a debug APK is produced. No release keystore exists on this machine and none is uploaded.
* The APK is intentionally **not** committed to the repository; it stays in `local-builds/android/`.
