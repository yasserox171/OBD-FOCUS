# Setup Guide — Focus OBD2 Scanner

## Prerequisites

| Tool | Version |
|---|---|
| Flutter SDK | 3.27 or newer (stable channel) |
| Dart | 3.x (bundled with Flutter) |
| Android SDK | Platform 34, build-tools 34 |
| JDK | 17 |
| Device | Android 5.0+ (API 21+) with Bluetooth |
| Adapter | Any ELM327-compatible Bluetooth OBD2 dongle (classic Bluetooth / SPP) |

## 1. Clone & bootstrap

```bash
git clone <repo-url>
cd OBD-FOCUS

# Regenerate platform boilerplate that is intentionally not committed
# (gradle wrapper JAR, launcher icons). Existing files are NOT overwritten.
flutter create --platforms=android .

flutter pub get
```

## 2. Run

```bash
flutter run            # debug on a connected phone
flutter build apk      # release APK (signed with debug key by default)
```

> The Android module pins **AGP 7.4.2 / Gradle 7.6.3 / Kotlin 1.8.22** for
> compatibility with `flutter_bluetooth_serial`; a namespace shim in
> `android/build.gradle` keeps older plugins building on modern AGP.

## 3. Permissions

The app requests at runtime:

- **Android 12+**: `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`
- **Android 6–11**: `ACCESS_FINE_LOCATION` (required by the OS for Bluetooth discovery)
- **Android 13+**: `POST_NOTIFICATIONS`

## 4. Google Drive backup (optional)

Drive export uses Google Sign-In. To enable it you must register the app in Google Cloud:

1. Create a project at <https://console.cloud.google.com>.
2. Enable the **Google Drive API**.
3. Configure the OAuth consent screen (External → test users → add your Gmail).
4. Create an **OAuth client ID → Android**:
   - Package name: `com.focus.obd2scanner`
   - SHA-1: `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android`
5. No key file is needed in the app — Google Sign-In matches by package + SHA-1.

The requested scope is `drive.file` only: the app can see and manage **only files it created** in your Drive.

## 5. Pairing the adapter

1. Plug the ELM327 into the car's OBD2 port (usually under the steering wheel).
2. Turn the ignition on.
3. Pair the adapter in Android Bluetooth settings (typical PIN: `1234` or `0000`).
4. Open the app → **Scan for devices** → **Connect**.

## 6. Try it without a car

Home screen → **Demo mode** — a built-in simulator produces a realistic drive cycle (warm-up, speed changes, a couple of stored DTCs) so every screen works without hardware.

## Troubleshooting

| Symptom | Fix |
|---|---|
| Adapter not found when scanning | Make sure it's paired in system settings first; grant nearby-devices permission |
| Connects then times out | Ignition must be ON; try re-plugging the adapter |
| `NO DATA` for some gauges | Not all cars implement all PIDs (fuel level and O₂ are the most commonly missing) — those tiles show `—` |
| Drive sign-in fails | Check the SHA-1 registered in Google Cloud matches your build keystore |
| Daily report notification missing | Battery optimization may block alarms — allow the app in system battery settings |
