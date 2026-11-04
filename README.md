# Lean Android emulator setup (headless)

Command-line SDK only (no Android Studio). Targets API 35 (Google APIs, x86_64) with a lean profile: 2 GiB RAM, 2 cores, 2 GiB data partition.

## Prerequisites

- Java 17 or 21 (JDK 25 is not validated; the setup script prefers the SDKMAN JDK 21 at `/usr/local/sdkman/candidates/java/21.0.13.0+2-ms`).
- `curl`, `unzip`.
- KVM access for hardware acceleration: the codespace user must be in the `kvm` group. Activate with `newgrp kvm` or run commands via `sg kvm -c '...'`.

## Install

```bash
./scripts/setup_android_emulator.sh
source ~/.bashrc   # non-interactive shells: export vars manually (see below)
```

Environment variables (add to your shell if `source ~/.bashrc` is a no-op):

```bash
export ANDROID_HOME="$HOME/.android-sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export JAVA_HOME=/usr/local/sdkman/candidates/java/21.0.13.0+2-ms
export PATH="$JAVA_HOME/bin:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$ANDROID_SDK_ROOT/emulator:$PATH"
```

## Run (headless)

```bash
sg kvm -c 'emulator -avd lean_api35 -no-window -no-audio -no-boot-anim -no-snapshot -accel on'
```

Verify acceleration:

```bash
sg kvm -c 'emulator -accel-check'
```

## Debug an app

```bash
adb install -r ./your-app.apk
adb logcat
```

## Tuning for a bigger machine

The script is parameterized. On a 4-core / 16 GiB VM, override:

```bash
ANDROID_API_LEVEL=35 ANDROID_AVD_NAME=lean_api35 ./scripts/setup_android_emulator.sh
```

Then edit `~/.android/avd/lean_api35.avd/config.ini` to set `hw.ramSize=4096` and `hw.cpu.ncore=4` (or re-run after editing the script).

## Limitations in this Codespace

- 2 CPUs and ~7.8 GiB RAM (smaller than the recommended 4 cores / 16 GiB).
- `/dev/kvm` is group-owned by `kvm`; the user is a member but must activate the group (`newgrp kvm`) for writable access. Without it, the emulator falls back to software rendering (slow).
- Google Play system images are not published in the public command-line SDK repository, so a Play Store–bundled AVD cannot be created from the CLI. Use an authenticated downloader (e.g. `apkeep`/`gplaycli`) or obtain the APK from the developer.
- Do not run nested emulator setups inside a regular Docker container unless it has the required device access; prefer a VM with nested virtualization exposed.
- For app UI testing that needs a usable display, use a remote VNC or browser-based Android environment instead of a headless emulator.
