#!/bin/bash

set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$#" != 1 || ! "$1" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
    echo 'Usage: ./scripts/generate-appcast.sh v1.2.3' >&2
    echo 'Creates a signed feed from an already-built release ZIP; it does not generate keys.' >&2
    echo 'For one-time key setup, see RELEASING.md: Sparkle update signing.' >&2
    exit 1
fi
tag="$1"
: "${SPARKLE_PRIVATE_ED_KEY:?Set this environment variable to the exported Sparkle private key. GitHub Actions secrets are only injected by the Release workflow; see RELEASING.md}"
repository="${GITHUB_REPOSITORY:-acheronfail/pixel-picker}"
[[ "$repository" == acheronfail/pixel-picker ]] || {
    echo 'Forks must configure their own SUFeedURL before publishing updates.' >&2
    exit 1
}
tools=build/SourcePackages/artifacts/sparkle/Sparkle/bin
archive="PixelPicker-${tag#v}-universal.zip"
staging=$(mktemp -d "${TMPDIR:-/tmp}/pixel-picker-appcast.XXXXXX")
trap 'rm -rf "$staging"' EXIT
# Only the current ZIP goes into the feed: no stale packages or duplicate DMGs.
cp "dist/$archive" "$staging/"
printf '%s' "$SPARKLE_PRIVATE_ED_KEY" | "$tools/generate_appcast" \
    --ed-key-file - --maximum-deltas 0 \
    --download-url-prefix "https://github.com/$repository/releases/download/$tag/" \
    --link "https://github.com/$repository/releases/tag/$tag" \
    "$staging"
# generate_appcast verifies the archive signature against the app's embedded
# public key. Refuse to upload an empty/unsigned feed even if generation succeeds.
python3 - "$staging/appcast.xml" "$archive" "$tag" <<'PYTHON'
import sys
import xml.etree.ElementTree as ET
root = ET.parse(sys.argv[1]).getroot()
ns = {'sparkle': 'http://www.andymatuschak.org/xml-namespaces/sparkle'}
items = root.findall('./channel/item')
assert len(items) == 1, 'Expected exactly one update'
item = items[0]
enclosure = item.find('enclosure')
assert enclosure is not None
assert enclosure.get('url') == f'https://github.com/acheronfail/pixel-picker/releases/download/{sys.argv[3]}/{sys.argv[2]}'
assert enclosure.get('{'+ns['sparkle']+'}edSignature'), 'Missing archive signature'
assert item.findtext('sparkle:shortVersionString', namespaces=ns) == sys.argv[3][1:]
assert int(enclosure.get('length', '0')) > 0
PYTHON
printf '%s' "$SPARKLE_PRIVATE_ED_KEY" | "$tools/sign_update" \
    --ed-key-file - --verify "$staging/appcast.xml"
cp "$staging/appcast.xml" dist/appcast.xml
