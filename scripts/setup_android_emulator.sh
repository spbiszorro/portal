#!/usr/bin/env bash
set -euo pipefail

ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$HOME/.android-sdk}"
ANDROID_API_LEVEL="${ANDROID_API_LEVEL:-35}"
ANDROID_AVD_NAME="${ANDROID_AVD_NAME:-lean_api35}"

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required" >&2
  exit 1
fi

if ! command -v java >/dev/null 2>&1; then
  echo "Java 17 or newer is required" >&2
  exit 1
fi

# Prefer a JDK 17/21 when the default java is newer (Android SDK tools are validated on LTS JDKs).
if [[ -x /usr/local/sdkman/candidates/java/21.0.13.0+2-ms/bin/java ]]; then
  export JAVA_HOME=/usr/local/sdkman/candidates/java/21.0.13.0+2-ms
  export PATH="$JAVA_HOME/bin:$PATH"
elif [[ -x /usr/local/sdkman/candidates/java/17.*/bin/java ]]; then
  export JAVA_HOME=$(ls -d /usr/local/sdkman/candidates/java/17.* | head -n1)
  export PATH="$JAVA_HOME/bin:$PATH"
fi

if ! command -v unzip >/dev/null 2>&1; then
  echo "unzip is required" >&2
  exit 1
fi

mkdir -p "$ANDROID_SDK_ROOT/cmdline-tools"

download_and_install_cmdline_tools() {
  local archive repository_xml zip_url
  archive=$(mktemp --suffix=.zip)
  repository_xml=$(mktemp)

  curl -fsSL "https://dl.google.com/android/repository/repository2-3.xml" -o "$repository_xml"
  zip_url=$(sed -n 's/.*<url>\([^<]*commandlinetools-linux-[^<]*\.zip\)<\/url>.*/https:\/\/dl.google.com\/android\/repository\/\1/p' "$repository_xml" | sort -V | tail -n 1)
  rm -f "$repository_xml"

  if [[ -z "$zip_url" ]]; then
    echo "Could not determine the latest Android command-line tools URL" >&2
    rm -f "$archive"
    exit 1
  fi

  echo "Downloading Android command-line tools from $zip_url"
  curl -fL "$zip_url" -o "$archive"
  rm -rf "$ANDROID_SDK_ROOT/cmdline-tools/latest"
  unzip -q "$archive" -d "$ANDROID_SDK_ROOT/cmdline-tools"
  mv "$ANDROID_SDK_ROOT/cmdline-tools/cmdline-tools" "$ANDROID_SDK_ROOT/cmdline-tools/latest"
  rm -f "$archive"
}

if [[ ! -x "$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager" ]]; then
  download_and_install_cmdline_tools
fi

export ANDROID_SDK_ROOT
export ANDROID_HOME="$ANDROID_SDK_ROOT"
export PATH="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$ANDROID_SDK_ROOT/emulator:$PATH"

system_image="system-images;android-${ANDROID_API_LEVEL};google_apis;x86_64"
echo "Installing lean Android SDK packages"
yes | sdkmanager --sdk_root="$ANDROID_SDK_ROOT" --licenses >/dev/null 2>&1 || true
sdkmanager --sdk_root="$ANDROID_SDK_ROOT" \
  "platform-tools" \
  "emulator" \
  "platforms;android-${ANDROID_API_LEVEL}" \
  "$system_image"

if [[ ! -e "/dev/kvm" ]]; then
  echo "WARNING: /dev/kvm is not present." >&2
  echo "The emulator will run slowly with software rendering unless nested KVM is enabled." >&2
elif [[ ! -r "/dev/kvm" || ! -w "/dev/kvm" ]]; then
  echo "WARNING: /dev/kvm is not readable/writable by this user." >&2
  echo "Membership in the kvm group is already present; activate it with: newgrp kvm" >&2
  echo "Or run the emulator under: sg kvm -c 'emulator -avd ...'" >&2
  echo "The emulator will run slowly with software rendering until KVM access is active." >&2
fi

if ! avdmanager list avd | grep -q "Name: $ANDROID_AVD_NAME"; then
  printf 'no\n' | avdmanager create avd \
    --name "$ANDROID_AVD_NAME" \
    --package "$system_image" \
    --device "pixel_2" \
    --force
fi

avd_dir="$HOME/.android/avd/${ANDROID_AVD_NAME}.avd"
config_tmp=$(mktemp)
sed -i 's/^hw\.gpu\.mode=.*/hw.gpu.mode=auto/' "$avd_dir/config.ini"
grep -v -E '^(hw\.ramSize|vm\.heapSize|disk\.dataPartition\.size|hw\.gpu|hw\.gpu\.mode|hw\.audioInput|hw\.audioOutput|hw\.cpu\.ncore)=' "$avd_dir/config.ini" > "$config_tmp"
cat >> "$config_tmp" <<EOF

# Lean Codespaces profile
hw.ramSize=2048
vm.heapSize=256
disk.dataPartition.size=2048M
hw.cpu.ncore=2
hw.gpu=yes
hw.gpu.mode=auto
hw.audioInput=no
hw.audioOutput=no
EOF
mv "$config_tmp" "$avd_dir/config.ini"

bashrc_marker="# >>> Android SDK (${ANDROID_SDK_ROOT}) >>>"
bashrc_end_marker="# <<< Android SDK (${ANDROID_SDK_ROOT}) <<<"
if [[ -f "$HOME/.bashrc" ]]; then
  sed -i '/^# >>> Android SDK (/,/^# <<< Android SDK (/d' "$HOME/.bashrc"
fi
cat >> "$HOME/.bashrc" <<EOF
${bashrc_marker}
export ANDROID_HOME="${ANDROID_SDK_ROOT}"
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT}"
export PATH="\$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:\$ANDROID_SDK_ROOT/platform-tools:\$ANDROID_SDK_ROOT/emulator:\$PATH"
${bashrc_end_marker}
EOF

export ANDROID_HOME="$ANDROID_SDK_ROOT"
export ANDROID_SDK_ROOT="$ANDROID_SDK_ROOT"
export PATH="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$ANDROID_SDK_ROOT/emulator:$PATH"

cat <<EOF

Android SDK installed at: $ANDROID_SDK_ROOT
AVD created: $ANDROID_AVD_NAME
Android environment variables were added to ~/.bashrc.

Apply them to this shell:
source ~/.bashrc

Start headless:
emulator -avd $ANDROID_AVD_NAME -no-window -no-audio -no-boot-anim -no-snapshot -accel on

Install a debug APK:
adb install -r /workspaces/portal/your-app.apk

Check acceleration:
emulator -accel-check
EOF
