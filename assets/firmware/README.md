# Firmware Assets

This directory contains compiled Omi device firmware for over-the-air (OTA) updates.

## Current Firmware

Place compiled firmware binaries here with version-specific naming:
- `devkit-v2-firmware-VERSION.zip` - Version-specific firmware
- `devkit-v2-firmware-latest.zip` - Symlink to latest version (optional)
- `BUILD_INFO.txt` - Build metadata (auto-generated)

## Building Firmware

To build firmware and copy it here automatically:

```bash
cd firmware
./scripts/build-and-integrate.sh
```

This will:
1. Compile firmware using Docker
2. Copy `zephyr.zip` to this directory with version number
3. Create symlink for easy reference
4. Generate build information

## Manual Integration

If you've built firmware separately:

```bash
# Copy manually
cp firmware/build/docker_build/zephyr.zip assets/firmware/devkit-v2-firmware-X.Y.Z.zip

# Update pubspec.yaml if needed
flutter pub get
```

## OTA Update Flow

1. App connects to Omi device via BLE
2. App reads firmware version from device
3. If newer firmware available in assets, prompts user
4. User confirms update
5. App initiates Nordic DFU protocol
6. Device updates and reboots

## Version Management

Firmware version is defined in:
```
firmware/devkit/prj_xiao_ble_sense_devkitv2-adafruit.conf
CONFIG_BT_DIS_FW_REV_STR="X.Y.Z"
```

Asset filename must match this version for proper OTA detection.

## File Size

Typical firmware size: ~500KB - 1MB (compressed)

## Adding to Flutter Assets

Ensure `pubspec.yaml` includes:

```yaml
flutter:
  assets:
    - assets/firmware/
```

Then run `flutter pub get` to register new assets.
