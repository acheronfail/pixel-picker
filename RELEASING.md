# Signing and draft releases

Pixel Picker follows Apptivator's signing strategy: one dedicated 20-year
self-signed certificate named **Pixel Picker Code Signing**, reused for every
release, with this stable designated requirement:

```text
designated => anchor = H"<certificate SHA-1 fingerprint>" and identifier "fail.acheron.pixel-picker"
```

The identity is intended to preserve macOS permission grants across updates.
The first upgrade from an old/ad-hoc signature may require granting Screen
Recording or Accessibility access again. Keep the same certificate and bundle
identifier; replacing the certificate changes the app's identity. This is not
Apple Developer ID signing or notarization, so it does not remove Gatekeeper's
restrictions on downloaded apps.

Key generation below writes files only. Do not use Keychain Access or Sparkle's
`generate_keys` command: that tool stores keys in the login keychain. Signing
imports are allowed only on disposable GitHub-hosted macOS runners; the wrapper
refuses to run locally or on self-hosted runners. It creates a temporary CI
keychain, temporarily trusts the certificate on that runner, signs and verifies,
then removes trust/private files and restores the runner's keychain search list.
No developer keychain changes are needed.

## 1. Generate your keys once

Run from this repository. Choose fresh output paths outside the checkout:

```bash
OPENSSL_BIN="$(brew --prefix openssl@3)/bin/openssl" \
  ./scripts/create-code-signing-identity.sh /private/tmp/pixel-picker-code-signing.p12

./scripts/create-sparkle-keys.swift /private/tmp/pixel-picker-sparkle
```

The first command prompts twice for a strong P12 password. The second uses
CryptoKit to generate an Ed25519 seed and public key, writing two files:
`/private/tmp/pixel-picker-sparkle/sparkle-private-key` and `sparkle-public-key`.
The private file is Sparkle 2.9's base64-encoded 32-byte seed format. Both commands
refuse to overwrite existing output. Back up the P12, its password, and the
Sparkle keys in your secrets manager before removing temporary files. Reuse
these keys for future releases; never commit or paste private keys into chat.

## 2. Configure the repository

These are the only three secrets required. Run the password command interactively
so `gh` prompts without recording the password in shell history:

```bash
/usr/bin/base64 -i /private/tmp/pixel-picker-code-signing.p12 | \
  gh secret set MACOS_CODE_SIGN_P12_BASE64 --repo acheronfail/pixel-picker

gh secret set MACOS_CODE_SIGN_P12_PASSWORD --repo acheronfail/pixel-picker

gh secret set SPARKLE_PRIVATE_ED_KEY --repo acheronfail/pixel-picker \
  < /private/tmp/pixel-picker-sparkle/sparkle-private-key

gh secret list --repo acheronfail/pixel-picker
```

Install the public key in the plist (this is public, committed configuration):

```bash
./scripts/set-sparkle-public-key.py /private/tmp/pixel-picker-sparkle/sparkle-public-key

git diff -- 'Pixel Picker/Info.plist'
```

Commit the resulting `SUPublicEDKey` together with these project/workflow changes.
`SUFeedURL` is already configured as:
`https://github.com/acheronfail/pixel-picker/releases/latest/download/appcast.xml`.
`SURequireSignedFeed` and `SUVerifyUpdateBeforeExtraction` are enabled.
No team ID, Apple account, identity fingerprint, or keychain-password secret is
needed. CI derives the certificate fingerprint and uses GitHub's automatic token.

The public key is committed in `Info.plist`; forks must replace it with their own.
Debug and unconfigured builds do not start Sparkle. Tagged/signed builds reject an absent or malformed key.
Appcast generation rejects a private key that does not match the embedded key.

## 3. Test without publishing

For a branch containing the workflow (after the workflow is registered on the
default branch), replace `YOUR_BRANCH` with that branch:

```bash
gh workflow run build.yml --repo acheronfail/pixel-picker --ref YOUR_BRANCH
gh run list --repo acheronfail/pixel-picker --workflow build.yml --limit 5
gh run watch RUN_ID --repo acheronfail/pixel-picker --exit-status
gh run download RUN_ID --repo acheronfail/pixel-picker --dir /private/tmp/pixel-picker-build
```

The Build workflow has no signing secrets or release permissions. It tests on
both native architectures and uploads ad-hoc universal artifacts.

For a signed draft, commit the public key and push a version tag pointing to the
reviewed commit containing these scripts. Replace `v1.7.0` as appropriate; pushing
a tag does not automatically trigger publication:

```bash
git tag v1.7.0
git push origin v1.7.0
gh workflow run release.yml --repo acheronfail/pixel-picker --ref YOUR_BRANCH -f tag=v1.7.0
gh run list --repo acheronfail/pixel-picker --workflow release.yml --limit 5
gh run watch RUN_ID --repo acheronfail/pixel-picker --exit-status
gh release view v1.7.0 --repo acheronfail/pixel-picker --json isDraft,tagName,assets
gh release download v1.7.0 --repo acheronfail/pixel-picker --dir /private/tmp/pixel-picker-draft
```

The workflow checks out the requested tag, tests, archives, verifies every Mach-O
contains `arm64` and `x86_64`, signs the nested Sparkle code and app, verifies the
stable designated requirement, and produces:

- `PixelPicker-<version>-universal.zip`
- `PixelPicker-<version>-universal.dmg`
- `PixelPicker-<version>-universal-SHA256SUMS.txt`
- `appcast.xml`, with signed archive metadata and a signed feed

It creates a draft with `--draft --verify-tag` and **stops there**. Existing
releases cause creation to fail; they are never edited. There is no publish step,
no automatic tag release trigger, and no command here to publish a release.
CI uses seconds since 2020 as the increasing build number, shared across
workflows; tagged versions must progress in order. Do not rerun an older tag
as a newer update. The workflow serializes draft builds.

Draft assets are private and do not update GitHub's public `latest/download`
redirect. Sparkle cannot consume them through the production feed. The first
Sparkle-enabled version needs manual installation; a draft build/signature check
is not an end-to-end updater test. To test installation privately, use downloaded
signed old/new builds and a separately hosted test appcast with reachable archive
URLs; generate/sign that feed using the same Sparkle tools and `--ed-key-file -`,
then use Sparkle's test feed override. Do not publish a release just to test it.

Manual smoke checks still needed on real Intel and Apple silicon Macs: screen
recording permission denied/granted, accurate RGB values, mixed-scale monitors
and screen edges, focus-mode motion, shortcut activation, launch at login,
Check for Updates, install/relaunch, and permission persistence across two signed
builds. The default feed intentionally remains unavailable until a future,
separately authorized production release includes an appcast.

## References

- [Sparkle setup and signed feeds](https://sparkle-project.org/documentation/)
- [Sparkle 2.9.6 key format](https://github.com/sparkle-project/Sparkle/blob/2.9.6/generate_keys/main.swift)
- [Apple code signing and designated requirements](https://developer.apple.com/library/archive/technotes/tn2206/)
