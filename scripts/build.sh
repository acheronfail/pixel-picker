#!/bin/bash

set -euo pipefail
cd "$(dirname "$0")/.."

# An optional release tag sets the version inside the app as well as artifact names.
tag="${1:-}"
version_args=("CODE_SIGN_IDENTITY=-")
if [[ -n "$tag" ]]; then
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
codesign --verify --deep --strict "$app"

version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")
name="PixelPicker-${version}-universal"
mkdir -p dist
if [[ -n "$tag" ]]; then
    python3 - "$app" <<'PYTHON'
import json
from pathlib import Path
import sys
app = Path(sys.argv[1])
frameworks = app / 'Contents/Frameworks'
targets = sorted((p for p in frameworks.rglob('*') if not p.is_symlink() and
                  (p.suffix in ('.framework', '.xpc', '.app') or p.name == 'Autoupdate')),
                 key=lambda p: (-len(p.parts), str(p)))
plan = [{'path': p.relative_to(app).as_posix(), 'preserve-entitlements': True} for p in targets]
Path('build/macos-signing-plan.json').write_text(json.dumps(plan, indent=2) + '\n')
PYTHON
    if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
        printf 'app-path=%s\narchive=%s\ndisk-image=%s\nsigning-plan=%s\nname=%s\n' \
            "$PWD/$app" "$PWD/dist/$name.zip" "$PWD/dist/$name.dmg" \
            "$PWD/build/macos-signing-plan.json" "$name" >> "$GITHUB_OUTPUT"
    fi
    echo "Built universal release app: $app"
    exit 0
fi

staging=$(mktemp -d "${TMPDIR:-/tmp}/pixel-picker-dmg.XXXXXX")
trap 'rm -rf "$staging"' EXIT
ditto "$app" "$staging/Pixel Picker.app"
ln -s /Applications "$staging/Applications"
ditto -c -k --sequesterRsrc --keepParent "$app" "dist/$name.zip"
hdiutil create -volname "Pixel Picker" -srcfolder "$staging" -ov -format UDZO "dist/$name.dmg"
(cd dist && shasum -a 256 "$name.zip" "$name.dmg" > "$name-SHA256SUMS.txt")
