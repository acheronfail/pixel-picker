#!/bin/bash

set -euo pipefail

# Never import certificates into a developer's keychain. This wrapper is CI-only.
if [[ "${GITHUB_ACTIONS:-}" != true || "${RUNNER_ENVIRONMENT:-}" != github-hosted || "${RUNNER_OS:-}" != macOS ]]; then
    echo 'Signing identities may only be imported on a GitHub-hosted macOS runner.' >&2
    exit 1
fi
: "${MACOS_CODE_SIGN_P12_BASE64:?Add MACOS_CODE_SIGN_P12_BASE64 to GitHub Actions secrets}"
: "${MACOS_CODE_SIGN_P12_PASSWORD:?Add MACOS_CODE_SIGN_P12_PASSWORD to GitHub Actions secrets}"
if [[ "$#" -eq 0 ]]; then
    echo "Usage: $0 command [arguments...]" >&2
    exit 1
fi

# Apple's bundled LibreSSL does not support the PKCS#12 -legacy option.
openssl_bin="$(brew --prefix openssl@3)/bin/openssl"
"$openssl_bin" version | grep -q '^OpenSSL 3\.'
umask 077
working_directory="$(mktemp -d "$RUNNER_TEMP/pixel-picker-signing.XXXXXX")"
keychain_path="$working_directory/signing.keychain-db"
identity_path="$working_directory/identity.p12"
certificate_path="$working_directory/certificate.pem"
keychain_password="$("$openssl_bin" rand -hex 32)"
certificate_trusted=false
original_keychains=()
while read -r keychain; do
    # security indents and quotes each path. read strips the indentation.
    keychain="${keychain#\"}"
    keychain="${keychain%\"}"
    original_keychains+=("$keychain")
done < <(security list-keychains -d user)

# Security services can stall during runner teardown. Bound each cleanup command;
# the hosted VM is discarded after the job even if a service stops responding.
cleanup_command() {
    python3 - "$@" <<'PYTHON'
import subprocess
import sys
try:
    result = subprocess.run(sys.argv[1:], timeout=15, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if result.returncode:
        print("::warning::A CI keychain cleanup command failed; the hosted runner will be discarded.")
except subprocess.TimeoutExpired:
    print("::warning::A CI keychain cleanup command timed out; the hosted runner will be discarded.")
PYTHON
}

cleanup() {
    if [[ "$certificate_trusted" == true ]]; then
        echo 'Removing temporary CI certificate trust.'
        cleanup_command sudo -n security remove-trusted-cert -d "$certificate_path" || true
        cleanup_command sudo -n security delete-certificate -Z "$certificate_sha1" /Library/Keychains/System.keychain || true
    fi
    if [[ "${#original_keychains[@]}" -gt 0 ]]; then
        echo 'Restoring the CI keychain search list.'
        cleanup_command security list-keychains -d user -s "${original_keychains[@]}" || true
    fi
    echo 'Deleting temporary CI keychain and private files.'
    cleanup_command security delete-keychain "$keychain_path" || true
    rm -rf "$working_directory"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

printf '%s' "$MACOS_CODE_SIGN_P12_BASE64" | /usr/bin/base64 -D > "$identity_path"
security create-keychain -p "$keychain_password" "$keychain_path"
security set-keychain-settings -lut 21600 "$keychain_path"
security unlock-keychain -p "$keychain_password" "$keychain_path"
security import "$identity_path" -k "$keychain_path" -f pkcs12 \
    -P "$MACOS_CODE_SIGN_P12_PASSWORD" -T /usr/bin/codesign >/dev/null
"$openssl_bin" pkcs12 -legacy -in "$identity_path" -clcerts -nokeys \
    -passin env:MACOS_CODE_SIGN_P12_PASSWORD -out "$certificate_path"
certificate_sha1="$("$openssl_bin" x509 -in "$certificate_path" -noout -fingerprint -sha1 | sed 's/.*=//; s/://g')"
[[ "$certificate_sha1" =~ ^[A-F0-9]{40}$ ]]

# Trust applies only to this disposable runner, and is removed by the EXIT trap.
sudo -n security add-trusted-cert -d -r trustRoot -p codeSign \
    -k /Library/Keychains/System.keychain "$certificate_path"
certificate_trusted=true
security set-key-partition-list -S apple-tool:,apple: -s -k "$keychain_password" "$keychain_path" >/dev/null
if [[ "${#original_keychains[@]}" -gt 0 ]]; then
    security list-keychains -d user -s "$keychain_path" "${original_keychains[@]}"
else
    security list-keychains -d user -s "$keychain_path"
fi
identities="$(security find-identity -v -p codesigning "$keychain_path")"
identity_count="$(printf '%s\n' "$identities" | awk '/"Pixel Picker Code Signing"/{count++} END {print count+0}')"
if [[ "$identity_count" != 1 ]]; then
    echo "Expected exactly one 'Pixel Picker Code Signing' identity, found $identity_count." >&2
    exit 1
fi
CODE_SIGN_IDENTITY="$(printf '%s\n' "$identities" | awk '/"Pixel Picker Code Signing"/{print $2; exit}')"
[[ "$CODE_SIGN_IDENTITY" == "$certificate_sha1" ]]
CODE_SIGN_KEYCHAIN="$keychain_path"
CODE_SIGN_REQUIREMENT="anchor = H\"$certificate_sha1\" and identifier \"fail.acheron.pixel-picker\""
CODE_SIGN_REQUIREMENTS="$working_directory/requirements.txt"
printf 'designated => %s\n' "$CODE_SIGN_REQUIREMENT" > "$CODE_SIGN_REQUIREMENTS"
export CODE_SIGN_IDENTITY CODE_SIGN_KEYCHAIN CODE_SIGN_REQUIREMENT CODE_SIGN_REQUIREMENTS
# The child build needs the imported identity, not the PKCS#12 secrets.
unset MACOS_CODE_SIGN_P12_BASE64 MACOS_CODE_SIGN_P12_PASSWORD
"$@"
