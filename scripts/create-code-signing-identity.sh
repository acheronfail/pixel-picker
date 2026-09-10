#!/bin/bash

set -euo pipefail

identity_name="Pixel Picker Code Signing"
output_path="${1:-}"
repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

if [[ -z "$output_path" ]]; then
    echo "Usage: $0 /absolute/path/pixel-picker-code-signing.p12" >&2
    exit 1
fi

if [[ "$output_path" != /* ]]; then
    echo "The output path must be absolute and outside the repository." >&2
    exit 1
fi

output_parent="$(cd "$(dirname "$output_path")" 2>/dev/null && pwd -P)" || {
    echo "The output directory does not exist: $(dirname "$output_path")" >&2
    exit 1
}

if [[ "$output_parent/" == "$repository_root/"* ]]; then
    echo "Refusing to write a signing identity inside the repository." >&2
    exit 1
fi

if [[ -e "$output_path" ]]; then
    echo "Refusing to overwrite existing file: $output_path" >&2
    exit 1
fi

openssl_bin="${OPENSSL_BIN:-openssl}"
"$openssl_bin" version | grep -q '^OpenSSL 3\.' || {
    echo "OpenSSL 3 is required (set OPENSSL_BIN to its executable)." >&2
    exit 1
}

read -r -s -p "Choose a strong password for the PKCS#12 file: " p12_password
echo
read -r -s -p "Confirm the password: " p12_password_confirmation
echo

if [[ -z "$p12_password" ]]; then
    echo "The password must not be empty." >&2
    exit 1
fi

if [[ "$p12_password" != "$p12_password_confirmation" ]]; then
    echo "Passwords do not match." >&2
    exit 1
fi

umask 077
working_directory="$(mktemp -d /tmp/pixel-picker-identity.XXXXXX)"
trap 'rm -rf "$working_directory"' EXIT

export PIXEL_PICKER_P12_PASSWORD="$p12_password"

"$openssl_bin" req \
    -x509 \
    -newkey rsa:3072 \
    -sha256 \
    -days 7300 \
    -nodes \
    -subj "/CN=$identity_name/" \
    -addext "basicConstraints=critical,CA:TRUE" \
    -addext "keyUsage=critical,digitalSignature,keyCertSign" \
    -addext "extendedKeyUsage=codeSigning" \
    -keyout "$working_directory/private-key.pem" \
    -out "$working_directory/certificate.pem"

"$openssl_bin" pkcs12 \
    -export \
    -legacy \
    -inkey "$working_directory/private-key.pem" \
    -in "$working_directory/certificate.pem" \
    -name "$identity_name" \
    -passout env:PIXEL_PICKER_P12_PASSWORD \
    -out "$output_path"

unset PIXEL_PICKER_P12_PASSWORD p12_password p12_password_confirmation

chmod 600 "$output_path"

echo
echo "Created: $output_path"
"$openssl_bin" x509 \
    -in "$working_directory/certificate.pem" \
    -noout \
    -subject \
    -dates \
    -fingerprint \
    -sha256
echo
echo "Back up this file and its password in an approved secrets manager."
