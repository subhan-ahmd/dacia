
# OBD Smoke Test (APK-ready)

Build the APK:
- macOS/Linux: `./gradlew assembleDebug`
- Windows: `gradlew.bat assembleDebug`
APK will be at: `app/build/outputs/apk/debug/app-debug.apk`

Flow:
1) Pair vLinker BM+ in system Bluetooth; plug in, ignition ON.
2) App: Scan → select adapter → Connect → Init → Read Once.
3) Shows Speed (010D) and Ambient temp (0146) if the pipe works.

Tip: If you get NO DATA, force CAN-11bit or 29-bit by editing `ElmProtocol.initMode01()`:
- Replace `ATSP0` with `ATSP6` (11-bit) or `ATSP7` (29-bit) and rebuild.
