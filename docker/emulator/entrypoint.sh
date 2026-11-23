#!/usr/bin/env bash
# Starts Xvfb + VNC + noVNC, boots the Pixel 8 AVD, installs the debug APK and launches it.
set -euo pipefail

APK="${APK:-/workspace/app/build/outputs/apk/debug/app-debug.apk}"
PACKAGE="${PACKAGE:-com.example.skeleton}"
export ANDROID_AVD_HOME="$HOME/.android/avd"
mkdir -p "$ANDROID_AVD_HOME"

[[ -e /dev/kvm ]] || { echo "emulator: /dev/kvm is not available (pass --device /dev/kvm)" >&2; exit 1; }
[[ -f "$APK" ]] || { echo "emulator: no debug APK at $APK (run ./dev.sh assembleDebug)" >&2; exit 1; }

Xvfb :0 -screen 0 600x1250x24 -nolisten tcp &
for _ in $(seq 1 50); do xdpyinfo -display :0 > /dev/null 2>&1 && break || sleep 0.2; done
x11vnc -display :0 -forever -shared -nopw -rfbport 5900 -quiet &
websockify --web /usr/share/novnc 6080 localhost:5900 > /dev/null 2>&1 &

if ! avdmanager list avd | grep -q "Name: ${AVD_NAME}"; then
  # This SDK's device list stops at pixel_7 (same 1080x2400 panel as the Pixel 8): start from it.
  echo "no" | avdmanager create avd -n "$AVD_NAME" -k "$SYSTEM_IMAGE" -d pixel_7 --force
fi
# Applied on every start (the AVD persists in a volume): Pixel 8 name and density, and 3 GB of RAM because
# the 1.5 GB default makes System UI stop responding under software rendering.
sed -i -e 's/^hw.lcd.density *=.*/hw.lcd.density = 428/' \
  -e 's/^hw.device.name *=.*/hw.device.name = pixel_8/' \
  -e 's/^hw.ramSize *=.*/hw.ramSize = 3072/' \
  "$ANDROID_AVD_HOME/${AVD_NAME}.avd/config.ini"

# The AVD lives in a persistent volume; an unclean stop leaves lock files that make the emulator refuse to start.
# Only one container uses this volume at a time, so stale locks are safe to remove.
rm -rf "$ANDROID_AVD_HOME/${AVD_NAME}.avd/"*.lock

"$ANDROID_HOME/emulator/emulator" -avd "$AVD_NAME" -gpu swiftshader_indirect -no-audio -no-boot-anim -no-snapshot -no-metrics \
  -netfast -scale 0.5 > /tmp/emulator.log 2>&1 &
EMULATOR_PID=$!

echo "waiting for the emulator to boot (about a minute)..."
until [[ "$(adb shell getprop sys.boot_completed 2> /dev/null | tr -d '\r')" == "1" ]]; do
  if ! kill -0 "$EMULATOR_PID" 2> /dev/null; then
    echo "emulator exited before booting; last lines of its log:" >&2
    tail -n 20 /tmp/emulator.log >&2
    exit 1
  fi
  sleep 2
done
# Fewer animations and a settled launcher keep System UI responsive while the app starts.
for scale in window_animation_scale transition_animation_scale animator_duration_scale; do
  adb shell settings put global "$scale" 0
done
for _ in $(seq 1 60); do
  adb shell dumpsys window | grep -m1 mCurrentFocus | grep -qi launcher && break
  sleep 2
done

if ! adb install -r "$APK"; then
  # Signature differs from the installed build (e.g. keystore regenerated): reinstall from scratch.
  echo "install failed, uninstalling the old build and retrying (app data is lost)"
  adb uninstall "$PACKAGE" || true
  adb install "$APK"
fi
adb shell monkey -p "$PACKAGE" -c android.intent.category.LAUNCHER 1 > /dev/null
# The app's own animations must play to be reviewed; window and transition ones stay off.
adb shell settings put global animator_duration_scale 1

echo
echo "emulator ready: open http://localhost:6080/vnc.html?autoconnect=true&resize=scale"
wait
