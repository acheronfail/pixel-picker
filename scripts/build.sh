#!/bin/bash

set -euo pipefail
cd "$(dirname "$0")/.."

# An optional release tag sets the version inside the app as well as artifact names.
tag="${1:-}"
version_args=("CODE_SIGN_IDENTITY=-")
if [[ -n "$tag" || ( -n "${CODE_SIGN_IDENTITY:-}" && "$CODE_SIGN_IDENTITY" != - ) ]]; then
    python3 - <<'PYTHON'
import base64
import plistlib
with open('Pixel Picker/Info.plist', 'rb') as source:
    public_key = plistlib.load(source)['SUPublicEDKey']
assert len(base64.b64decode(public_key, validate=True)) == 32, 'Invalid Sparkle public key'
PYTHON
fi
if [[ -n "$tag" ]]; then
    if [[ ! "$tag" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
        echo "Expected a release tag in the form v1.2.3, got: $tag" >&2
        exit 1
    fi
    if [[ -z "${CODE_SIGN_IDENTITY:-}" || "$CODE_SIGN_IDENTITY" == - ]]; then
        echo 'Release packages require scripts/with-code-signing-identity.sh in CI.' >&2
        exit 1
    fi
    version_args+=("MARKETING_VERSION=${tag#v}")
fi
# Use one increasing series across Build and Release workflows (run numbers are
# workflow-specific). Seconds since 2020 also stay above the legacy build 30.
if [[ "${GITHUB_ACTIONS:-}" == true ]]; then
    version_args+=("CURRENT_PROJECT_VERSION=$(( $(date -u +%s) - 1577836800 ))")
fi

xcodebuild -project "Pixel Picker.xcodeproj" -scheme "Pixel Picker" \
    -configuration Release -destination 'generic/platform=macOS' \
    -derivedDataPath build/DerivedData -clonedSourcePackagesDirPath build/SourcePackages \
    -onlyUsePackageVersionsFromResolvedFile -archivePath build/PixelPicker.xcarchive \
    ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO \
    "${version_args[@]}" archive

app="build/PixelPicker.xcarchive/Products/Applications/Pixel Picker.app"
# Reject Intel-only artifacts, including any nested executables or libraries.
while IFS= read -r -d '' binary; do
    if file -b "$binary" | grep -q 'Mach-O'; then
        lipo "$binary" -verify_arch arm64 x86_64
    fi
done < <(find "$app" -type f -print0)
lipo -archs "$app/Contents/MacOS/Pixel Picker"
if [[ -n "${CODE_SIGN_IDENTITY:-}" && "$CODE_SIGN_IDENTITY" != - ]]; then
    : "${CODE_SIGN_KEYCHAIN:?Use scripts/with-code-signing-identity.sh in CI}"
    : "${CODE_SIGN_REQUIREMENTS:?The stable designated requirement is required}"
    : "${CODE_SIGN_REQUIREMENT:?The stable verification requirement is required}"
    # Sign Sparkle's nested code inside-out before sealing the enclosing app.
    # Each helper keeps its own identifier; the app's custom requirement is only
    # applied to the outer bundle.
    while IFS= read -r -d '' bundle; do
        codesign --force --sign "$CODE_SIGN_IDENTITY" --keychain "$CODE_SIGN_KEYCHAIN" \
            --preserve-metadata=entitlements --timestamp=none "$bundle"
    done < <(find "$app/Contents/Frameworks" -depth \( -name '*.xpc' -o -name '*.app' -o -name '*.framework' -o -name Autoupdate \) -print0)
    codesign --force --sign "$CODE_SIGN_IDENTITY" --keychain "$CODE_SIGN_KEYCHAIN" \
        --requirements "$CODE_SIGN_REQUIREMENTS" --timestamp=none "$app"
    codesign --verify --deep --strict --test-requirement "=$CODE_SIGN_REQUIREMENT" "$app"
    codesign --display --requirements - "$app"
else
    # Ad-hoc signing is only for development/PR builds, never tagged releases.
    if [[ -n "$tag" ]]; then
        echo 'Release packages require the long-lived CI signing identity.' >&2
        exit 1
    fi
    codesign --verify --deep --strict "$app"
fi

version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")
name="PixelPicker-${version}-universal"
mkdir -p dist
staging=$(mktemp -d "${TMPDIR:-/tmp}/pixel-picker-dmg.XXXXXX")
trap 'rm -rf "$staging"' EXIT
ditto "$app" "$staging/Pixel Picker.app"
ln -s /Applications "$staging/Applications"
ditto -c -k --sequesterRsrc --keepParent "$app" "dist/$name.zip"
hdiutil create -volname "Pixel Picker" -srcfolder "$staging" -ov -format UDZO "dist/$name.dmg"
(cd dist && shasum -a 256 "$name.zip" "$name.dmg" > "$name-SHA256SUMS.txt")
