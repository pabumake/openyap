#!/bin/zsh

set -euo pipefail

script_directory=${0:A:h}
project_directory=${script_directory:h}
developer_directory=/Applications/Xcode.app/Contents/Developer
built_application="$project_directory/.build/Build/Products/Debug/OpenYap.app"
installed_application=/Applications/OpenYap.app
bundle_identifier=dev.pabu.openyap
staging_directory=$(mktemp -d /private/tmp/openyap-install.XXXXXX)
staged_application="$staging_directory/OpenYap.app"

cleanup() {
  rm -rf "$staging_directory"
}
trap cleanup EXIT

cd "$project_directory"

DEVELOPER_DIR="$developer_directory" xcodegen generate
DEVELOPER_DIR="$developer_directory" xcodebuild \
  -project OpenYap.xcodeproj \
  -scheme OpenYap \
  -configuration Debug \
  -derivedDataPath .build \
  CODE_SIGNING_ALLOWED=NO \
  build

ditto --noextattr --noqtn "$built_application" "$staged_application"
xattr -cr "$staged_application"
codesign --force --deep --sign - "$staged_application"
codesign --verify --deep --strict --verbose=2 "$staged_application"

killall OpenYap 2>/dev/null || true
ditto --noextattr --noqtn "$staged_application" "$installed_application"
xattr -cr "$installed_application"
codesign --force --deep --sign - "$installed_application"
codesign --verify --deep --strict --verbose=2 "$installed_application"

if [[ "${OPENYAP_KEEP_PERMISSIONS:-0}" != "1" ]]; then
  for privacy_service in Microphone ListenEvent Accessibility; do
    tccutil reset "$privacy_service" "$bundle_identifier" 2>/dev/null || true
  done
  echo "Reset OpenYap microphone, Input Monitoring, and Accessibility grants"
fi

open "$installed_application"

echo "Installed and launched $installed_application"
