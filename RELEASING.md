# Signing and draft releases

The manual Draft release workflow builds a universal app, then uses
`acheronfail/dist-tools/actions/apple-release@v1` (DMG support requires v1.2.0+)
for Developer ID signing, notarization and stapling. It produces:

- `PixelPicker-<version>-universal.zip`
- `PixelPicker-<version>-universal.dmg`
- `PixelPicker-<version>-universal-SHA256SUMS.txt`
- `appcast.xml`, signed with the existing Sparkle key

Checksums and the Sparkle feed are generated after both packages are finalized.
The workflow creates a draft only; an existing release makes creation fail.
Normal Build jobs and local `./scripts/build.sh` produce ad-hoc preview packages.
`./scripts/build.sh vX.Y.Z` builds the versioned app and its nested signing plan;
distribution packaging runs through the shared Action in CI.

## Apple credentials

Use the [dist-tools credential CLI](https://github.com/acheronfail/dist-tools/blob/v1/docs/credentials.md)
with `acheronfail/pixel-picker` in its repository allowlist. For team API keys,
sync these settings:

| Setting | Type |
| --- | --- |
| `MACOS_CODE_SIGN_P12_BASE64` | Secret |
| `MACOS_CODE_SIGN_P12_PASSWORD` | Secret |
| `APPLE_TEAM_ID` | Secret |
| `APPLE_NOTARY_API_KEY` | Secret |
| `APPLE_NOTARY_KEY_ID` | Secret |
| `APPLE_NOTARY_ISSUER_ID` | Secret |
| `APPLE_NOTARY_AUTH_MODE` = `api-team` | Variable |

Apple Account compatibility uses `APPLE_NOTARY_APPLE_ID` and
`APPLE_NOTARY_PASSWORD` with mode `apple-id` (the default).
Switching from the old self-signed identity may require granting Screen Recording
or Accessibility access again on the first update.

## Sparkle update signing

Sparkle's `SPARKLE_PRIVATE_ED_KEY` secret is separate from Apple credentials.
Keep the existing key and matching `SUPublicEDKey` in `Pixel Picker/Info.plist`.
The sync CLI does not change them. Feed generation verifies that they match.

For a new fork, generate and install a key pair with:

```sh
./scripts/create-sparkle-keys.swift /path/to/new-sparkle-keys
./scripts/set-sparkle-public-key.py /path/to/new-sparkle-keys/sparkle-public-key
gh secret set SPARKLE_PRIVATE_ED_KEY --repo OWNER/REPO \
  < /path/to/new-sparkle-keys/sparkle-private-key
```

Forks also need their own feed URL and repository mapping in the appcast script.

## Build a draft

Push a version tag pointing to the reviewed commit containing this workflow and
its scripts, then dispatch Draft release with that tag:

```sh
gh workflow run release.yml --repo acheronfail/pixel-picker -f tag=vX.Y.Z
```

The build checks every bundled Mach-O for both `arm64` and `x86_64`. Its signing
plan lists nested frameworks and helpers before their containers and preserves
existing helper entitlements. The shared Action verifies the app and DMG before
artifact upload or draft creation.

Draft assets do not update the public Sparkle feed. A first Sparkle-enabled
version needs manual installation. Test install/relaunch and permission retention
across two signed builds using a separate test feed before publishing updates.
