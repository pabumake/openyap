#!/usr/bin/env bash
set -euo pipefail

prototype_root="$(cd "$(dirname "$0")" && pwd)"
developer_directory="/Applications/Xcode.app/Contents/Developer"
derived_data="/private/tmp/openyap-ios-capture-prototype-derived"
device_json="/private/tmp/openyap-ios-capture-prototype-devices.json"

export DEVELOPER_DIR="$developer_directory"

xcrun devicectl list devices --timeout 20 --json-output "$device_json" >/dev/null

device_udid="$(jq -r '.result.devices[] | select(.hardwareProperties.platform == "iOS" and .hardwareProperties.reality == "physical" and .deviceProperties.developerModeStatus == "enabled" and .connectionProperties.tunnelState == "connected") | .hardwareProperties.udid' "$device_json" | head -n 1)"
device_identifier="$(jq -r '.result.devices[] | select(.hardwareProperties.udid == "'"$device_udid"'") | .identifier' "$device_json" | head -n 1)"

if [[ -z "$device_udid" || "$device_udid" == "null" ]]; then
  echo "No connected physical iPhone with Developer Mode enabled was found." >&2
  exit 1
fi

cd "$prototype_root"
xcodegen generate --spec project.yml

xcodebuild \
  -project OpenYapCapturePrototype.xcodeproj \
  -scheme OpenYapCapturePrototype \
  -configuration Debug \
  -destination "platform=iOS,id=$device_udid" \
  -derivedDataPath "$derived_data" \
  -allowProvisioningUpdates \
  -allowProvisioningDeviceRegistration \
  build

app_path="$derived_data/Build/Products/Debug-iphoneos/OpenYapCapturePrototype.app"
xcrun devicectl device install app --device "$device_identifier" "$app_path"
xcrun devicectl device process launch --device "$device_identifier" dev.pabu.openyap.prototype.ios

echo "OpenYap Capture Prototype is installed and running."
