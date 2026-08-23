#!/bin/zsh

set -euo pipefail

script_directory=${0:A:h}
project_directory=${script_directory:h}
developer_directory=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
release_tag=${1:-}
requested_output_directory=${2:-$project_directory/.build/releases/$release_tag}

if ! print -r -- "$release_tag" | grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+$'; then
  print -u2 "Usage: $0 vMAJOR.MINOR.PATCH [output-directory]"
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
  CODE_SIGNING_ALLOWED=NO \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=NO

built_application=$archive_path/Products/Applications/OpenYap.app
staged_application=$staging_directory/OpenYap.app
staged_info=$staged_application/Contents/Info.plist

ditto --noextattr --noqtn "$built_application" "$staged_application"
xattr -cr "$staged_application"
codesign --force --sign - "$staged_application"
codesign --verify --deep --strict --verbose=2 "$staged_application"

bundle_identifier=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$staged_info")
bundle_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$staged_info")
bundle_build=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$staged_info")
bundle_minimum_system=$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$staged_info")
binary_architectures=$(lipo -archs "$staged_application/Contents/MacOS/OpenYap")
signature_details=$(codesign -dvvv "$staged_application" 2>&1)

[[ "$bundle_identifier" == "dev.pabu.openyap" ]] || { print -u2 "Unexpected bundle identifier: $bundle_identifier"; exit 68; }
[[ "$bundle_version" == "$release_version" ]] || { print -u2 "Unexpected bundle version: $bundle_version"; exit 69; }
[[ "$bundle_build" == "$project_build" ]] || { print -u2 "Unexpected build number: $bundle_build"; exit 70; }
[[ "$bundle_minimum_system" == "26.0" ]] || { print -u2 "Unexpected minimum macOS version: $bundle_minimum_system"; exit 71; }
[[ "$binary_architectures" == "arm64" ]] || { print -u2 "Unexpected architectures: $binary_architectures"; exit 72; }
print -r -- "$signature_details" | grep -Fq 'Signature=adhoc' || { print -u2 'Release app is not ad hoc signed'; exit 73; }
print -r -- "$signature_details" | grep -Fq 'TeamIdentifier=not set' || { print -u2 'Unsigned release unexpectedly has a Team ID'; exit 74; }
[[ -f "$staged_application/Contents/Resources/CHANGELOG.md" ]] || { print -u2 'Bundled changelog is missing'; exit 75; }
[[ -f "$staged_application/Contents/Resources/AppIcon.icns" ]] || { print -u2 'Bundled app icon is missing'; exit 76; }

zip_name="OpenYap-$release_version-macOS-arm64.zip"
checksum_name="$zip_name.sha256"
zip_path=$output_directory/$zip_name
checksum_path=$output_directory/$checksum_name

if [[ -e "$zip_path" || -e "$checksum_path" ]]; then
  print -u2 "Release output already exists in $output_directory"
  exit 77
fi

ditto -c -k --sequesterRsrc --keepParent "$staged_application" "$zip_path"

(
  cd "$output_directory"
  shasum -a 256 "$zip_name" > "$checksum_name"
  shasum -a 256 -c "$checksum_name"
)

ditto -x -k "$zip_path" "$extraction_directory"
extracted_application=$extraction_directory/OpenYap.app
codesign --verify --deep --strict --verbose=2 "$extracted_application"
[[ "$(lipo -archs "$extracted_application/Contents/MacOS/OpenYap")" == "arm64" ]] || { print -u2 'ZIP architecture verification failed'; exit 78; }

if spctl --assess --type execute "$extracted_application" >/dev/null 2>&1; then
  print -u2 'Gatekeeper unexpectedly accepted the unsigned prerelease'
  exit 79
fi

print "Created $zip_path"
print "Created $checksum_path"
