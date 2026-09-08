#!/bin/zsh

set -euo pipefail

script_directory=${0:A:h}
project_directory=${script_directory:h}
developer_directory=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
release_tag=${1:-}
requested_output_directory=${2:-$project_directory/.build/releases/$release_tag}
developer_id_identity=${OPENYAP_DEVELOPER_ID_IDENTITY:-Developer ID Application}
sparkle_key_account=${OPENYAP_SPARKLE_KEY_ACCOUNT:-dev.pabu.openyap}

require_environment() {
  local variable_name=$1
  if [[ -z "${(P)variable_name:-}" ]]; then
    print -u2 "Required environment variable is missing: $variable_name"
    exit 64
  fi
}

if ! print -r -- "$release_tag" | grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+$'; then
  print -u2 "Usage: $0 vMAJOR.MINOR.PATCH [output-directory]"
  exit 64
fi

require_environment OPENYAP_DEVELOPMENT_TEAM
require_environment OPENYAP_NOTARY_KEY_ID
require_environment OPENYAP_NOTARY_ISSUER_ID
require_environment OPENYAP_NOTARY_KEY_PATH

if [[ ! -f "$OPENYAP_NOTARY_KEY_PATH" ]]; then
  print -u2 "Notary API key does not exist: $OPENYAP_NOTARY_KEY_PATH"
  exit 64
fi

if ! git -C "$project_directory" rev-parse --verify --quiet "refs/tags/$release_tag^{commit}" >/dev/null; then
  print -u2 "Tag does not exist: $release_tag"
  exit 65
fi

release_version=${release_tag#v}
temporary_directory=$(mktemp -d /private/tmp/openyap-release.XXXXXX)
source_directory=$temporary_directory/source
archive_path=$temporary_directory/OpenYap.xcarchive
export_path=$temporary_directory/export
export_options_path=$temporary_directory/ExportOptions.plist
derived_data_path=$temporary_directory/DerivedData
staging_directory=$temporary_directory/staging
extraction_directory=$temporary_directory/extracted

cleanup() {
  rm -rf "$temporary_directory"
}
trap cleanup EXIT

mkdir -p "$source_directory" "$staging_directory" "$extraction_directory" "$requested_output_directory"
output_directory=$(cd "$requested_output_directory" && pwd -P)

git -C "$project_directory" archive "$release_tag" | tar -x -C "$source_directory"

project_version=$(sed -n 's/^[[:space:]]*MARKETING_VERSION:[[:space:]]*//p' "$source_directory/project.yml" | head -n 1 | tr -d '"')
project_build=$(sed -n 's/^[[:space:]]*CURRENT_PROJECT_VERSION:[[:space:]]*//p' "$source_directory/project.yml" | head -n 1 | tr -d '"')

if [[ "$project_version" != "$release_version" ]]; then
  print -u2 "Tag $release_tag does not match MARKETING_VERSION $project_version"
  exit 66
fi

if ! grep -Fq "## $release_version -" "$source_directory/CHANGELOG.md"; then
  print -u2 "CHANGELOG.md has no release section for $release_version"
  exit 67
fi

print "Testing OpenYap $release_version"
DEVELOPER_DIR="$developer_directory" xcodebuild test -quiet \
  -project "$source_directory/OpenYap.xcodeproj" \
  -scheme OpenYap \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$temporary_directory/TestDerivedData" \
  CODE_SIGNING_ALLOWED=NO \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=NO

print "Archiving OpenYap $release_version for Apple silicon"
DEVELOPER_DIR="$developer_directory" xcodebuild archive -quiet \
  -project "$source_directory/OpenYap.xcodeproj" \
  -scheme OpenYap \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$archive_path" \
  -derivedDataPath "$derived_data_path" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$developer_id_identity" \
  DEVELOPMENT_TEAM="$OPENYAP_DEVELOPMENT_TEAM" \
  OTHER_CODE_SIGN_FLAGS=--timestamp \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=NO

cat > "$export_options_path" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>destination</key>
  <string>export</string>
  <key>method</key>
  <string>developer-id</string>
  <key>signingCertificate</key>
  <string>$developer_id_identity</string>
  <key>signingStyle</key>
  <string>manual</string>
  <key>teamID</key>
  <string>$OPENYAP_DEVELOPMENT_TEAM</string>
</dict>
</plist>
PLIST

print "Exporting OpenYap $release_version with Developer ID"
DEVELOPER_DIR="$developer_directory" xcodebuild -exportArchive -quiet \
  -archivePath "$archive_path" \
  -exportPath "$export_path" \
  -exportOptionsPlist "$export_options_path"

built_application=$export_path/OpenYap.app
staged_application=$staging_directory/OpenYap.app
staged_info=$staged_application/Contents/Info.plist

ditto --noextattr --noqtn "$built_application" "$staged_application"
codesign --verify --deep --strict --verbose=2 "$staged_application"

bundle_identifier=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$staged_info")
bundle_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$staged_info")
bundle_build=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$staged_info")
bundle_minimum_system=$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$staged_info")
binary_architectures=$(lipo -archs "$staged_application/Contents/MacOS/OpenYap")
signature_details=$(codesign -dvvv "$staged_application" 2>&1)
update_feed=$(/usr/libexec/PlistBuddy -c 'Print :SUFeedURL' "$staged_info")
update_public_key=$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$staged_info")
update_interval=$(/usr/libexec/PlistBuddy -c 'Print :SUScheduledCheckInterval' "$staged_info")

[[ "$bundle_identifier" == "dev.pabu.openyap" ]] || { print -u2 "Unexpected bundle identifier: $bundle_identifier"; exit 68; }
[[ "$bundle_version" == "$release_version" ]] || { print -u2 "Unexpected bundle version: $bundle_version"; exit 69; }
[[ "$bundle_build" == "$project_build" ]] || { print -u2 "Unexpected build number: $bundle_build"; exit 70; }
[[ "$bundle_minimum_system" == "26.0" ]] || { print -u2 "Unexpected minimum macOS version: $bundle_minimum_system"; exit 71; }
[[ "$binary_architectures" == "arm64" ]] || { print -u2 "Unexpected architectures: $binary_architectures"; exit 72; }
[[ "$update_feed" == "https://pabumake.github.io/openyap/appcast.xml" ]] || { print -u2 'Unexpected Sparkle feed URL'; exit 72; }
[[ "$update_public_key" == "n/N7vrOCRMwHYm+pVafKTu0FWnp466unUYVOOmn0cRY=" ]] || { print -u2 'Unexpected Sparkle public key'; exit 72; }
[[ "$update_interval" == "86400" ]] || { print -u2 'Unexpected Sparkle check interval'; exit 72; }
/usr/libexec/PlistBuddy -c 'Print :SURequireSignedFeed' "$staged_info" | grep -Fq true || { print -u2 'Signed Sparkle feeds are not required'; exit 72; }
/usr/libexec/PlistBuddy -c 'Print :SUVerifyUpdateBeforeExtraction' "$staged_info" | grep -Fq true || { print -u2 'Sparkle does not verify updates before extraction'; exit 72; }
/usr/libexec/PlistBuddy -c 'Print :SUAllowsAutomaticUpdates' "$staged_info" | grep -Fq false || { print -u2 'Unattended update installation is enabled'; exit 72; }
print -r -- "$signature_details" | grep -Fq 'Authority=Developer ID Application:' || { print -u2 'Release app is not Developer ID signed'; exit 73; }
print -r -- "$signature_details" | grep -Fq "TeamIdentifier=$OPENYAP_DEVELOPMENT_TEAM" || { print -u2 'Release app has the wrong Team ID'; exit 74; }

sparkle_framework=$staged_application/Contents/Frameworks/Sparkle.framework
sparkle_version=$sparkle_framework/Versions/B
sparkle_signed_items=(
  "$sparkle_version/XPCServices/Downloader.xpc"
  "$sparkle_version/XPCServices/Installer.xpc"
  "$sparkle_version/Autoupdate"
  "$sparkle_version/Updater.app"
  "$sparkle_framework"
)
for signed_item in "${sparkle_signed_items[@]}"; do
  signed_item_details=$(codesign -dvvv "$signed_item" 2>&1)
  print -r -- "$signed_item_details" | grep -Fq 'Authority=Developer ID Application:' || {
    print -u2 "Sparkle component is not Developer ID signed: $signed_item"
    exit 75
  }
  print -r -- "$signed_item_details" | grep -Fq 'Timestamp=' || {
    print -u2 "Sparkle component has no secure timestamp: $signed_item"
    exit 75
  }
done
[[ -f "$staged_application/Contents/Resources/CHANGELOG.md" ]] || { print -u2 'Bundled changelog is missing'; exit 75; }
[[ -f "$staged_application/Contents/Resources/AppIcon.icns" ]] || { print -u2 'Bundled app icon is missing'; exit 76; }

zip_name="OpenYap-$release_version-macOS-arm64.zip"
checksum_name="$zip_name.sha256"
notes_name="OpenYap-$release_version-macOS-arm64.md"
zip_path=$output_directory/$zip_name
checksum_path=$output_directory/$checksum_name
notes_path=$output_directory/$notes_name

if [[ -e "$zip_path" || -e "$checksum_path" || -e "$notes_path" ]]; then
  print -u2 "Release output already exists in $output_directory"
  exit 77
fi

print "Submitting OpenYap $release_version for notarization"
notary_zip=$temporary_directory/OpenYap-notary.zip
ditto -c -k --sequesterRsrc --keepParent "$staged_application" "$notary_zip"
DEVELOPER_DIR="$developer_directory" xcrun notarytool submit "$notary_zip" \
  --key "$OPENYAP_NOTARY_KEY_PATH" \
  --key-id "$OPENYAP_NOTARY_KEY_ID" \
  --issuer "$OPENYAP_NOTARY_ISSUER_ID" \
  --wait

DEVELOPER_DIR="$developer_directory" xcrun stapler staple "$staged_application"
DEVELOPER_DIR="$developer_directory" xcrun stapler validate "$staged_application"
spctl --assess --type execute --verbose=2 "$staged_application"

ditto -c -k --sequesterRsrc --keepParent "$staged_application" "$zip_path"

awk -v version="$release_version" '
  $0 ~ "^## " version " -" { in_release = 1; next }
  in_release && /^## / { exit }
  in_release { print }
' "$source_directory/CHANGELOG.md" > "$notes_path"

(
  cd "$output_directory"
  shasum -a 256 "$zip_name" > "$checksum_name"
  shasum -a 256 -c "$checksum_name"
)

ditto -x -k "$zip_path" "$extraction_directory"
extracted_application=$extraction_directory/OpenYap.app
codesign --verify --deep --strict --verbose=2 "$extracted_application"
[[ "$(lipo -archs "$extracted_application/Contents/MacOS/OpenYap")" == "arm64" ]] || { print -u2 'ZIP architecture verification failed'; exit 78; }
spctl --assess --type execute --verbose=2 "$extracted_application"

sparkle_tools=$derived_data_path/SourcePackages/artifacts/sparkle/Sparkle/bin
generate_appcast=$sparkle_tools/generate_appcast
if [[ ! -x "$generate_appcast" ]]; then
  print -u2 "Sparkle generate_appcast was not found at $generate_appcast"
  exit 79
fi

appcast_arguments=(
  --download-url-prefix "https://github.com/pabumake/openyap/releases/download/$release_tag/"
  --embed-release-notes
  --link "https://github.com/pabumake/openyap/releases/tag/$release_tag"
  --maximum-deltas 0
  --maximum-versions 3
  --disable-signing-warning
  -o "$output_directory/appcast.xml"
)

if [[ -n "${OPENYAP_SPARKLE_PRIVATE_KEY:-}" ]]; then
  print -rn -- "$OPENYAP_SPARKLE_PRIVATE_KEY" | "$generate_appcast" --ed-key-file - "${appcast_arguments[@]}" "$output_directory"
else
  "$generate_appcast" --account "$sparkle_key_account" "${appcast_arguments[@]}" "$output_directory"
fi

[[ -f "$output_directory/appcast.xml" ]] || { print -u2 'Sparkle appcast was not generated'; exit 80; }
grep -Fq 'sparkle:edSignature=' "$output_directory/appcast.xml" || { print -u2 'Sparkle archive signature is missing'; exit 81; }
grep -Fq '<!-- sparkle-signatures:' "$output_directory/appcast.xml" || { print -u2 'Sparkle feed signature is missing'; exit 82; }

print "Created $zip_path"
print "Created $checksum_path"
print "Created $output_directory/appcast.xml"
