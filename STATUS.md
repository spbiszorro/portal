# Status: Android emulator setup

## Accomplished

- Lean Android emulator setup script (`scripts/setup_android_emulator.sh`) created and working:
  - Installs command-line SDK (cmdline-tools, platform-tools, emulator, platform API 35, google_apis x86_64 system image).
  - Creates AVD `lean_api35` (API 35, Google APIs, x86_64) with lean profile: 2 GiB RAM, 2 cores, 2 GiB data partition, GPU auto, audio disabled.
  - Persists `ANDROID_HOME`/`ANDROID_SDK_ROOT`/PATH in `~/.bashrc`.
  - JDK 21 (SDKMAN) preferred over JDK 25 for SDK tool compatibility.
  - Guards for curl, java, unzip; KVM availability check with actionable guidance.
- Environment verified on 4-core / 16 GiB space: KVM writable, emulator boots, `adb devices` shows `emulator-5554`.
- Missing runtime libs installed (libpulse, libXi, libxkbfile, etc.).
- README rewritten to focus solely on emulator setup.
- `kilo_mcp_server.py` removed; repo committed and pushed.

## Current blocker

- Target app `com.atompod.fsp` (Atompod Integration LLC) not installable yet: no public APK mirror (APKMirror/APKPure) hosts it, and `google_play` system images aren't available via the public CLI SDK repo, so Play Store can't be added to the emulator.
- Reached out to developer (developer@atompod.com) for the APK/test build.

## Next steps

1. Obtain the APK from Atompod (or via authenticated downloader with Google credentials).
2. `adb install -r ./your-app.apk` on the running `lean_api35` emulator and run `adb logcat` for testing.
3. If a larger machine is used, raise AVD profile to 4 GiB RAM / 4 cores.
4. Optionally tune emulator flags (`-gpu swiftshader_indirect` if KVM unavailable) for the final test run.
