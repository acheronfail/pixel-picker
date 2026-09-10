#!/bin/bash

set -euo pipefail
cd "$(dirname "$0")/.."
xcodebuild -project 'Pixel Picker.xcodeproj' -scheme 'Pixel Picker' \
    -configuration Testing -destination "platform=macOS,arch=$(uname -m)" \
    -derivedDataPath build/DerivedData -clonedSourcePackagesDirPath build/SourcePackages \
    -onlyUsePackageVersionsFromResolvedFile CODE_SIGN_IDENTITY=- ONLY_ACTIVE_ARCH=YES test
