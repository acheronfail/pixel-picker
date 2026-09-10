#!/usr/bin/env python3
"""Validate and install a public key without reading the private key."""
import base64
import pathlib
import plistlib
import sys

if len(sys.argv) != 2:
    sys.exit('Usage: scripts/set-sparkle-public-key.py /path/to/sparkle-public-key')
key = pathlib.Path(sys.argv[1]).read_text().strip()
try:
    if len(base64.b64decode(key, validate=True)) != 32:
        raise ValueError('Expected 32 bytes')
except (ValueError, base64.binascii.Error) as error:
    sys.exit(f'Invalid Sparkle public key: {error}')
plist = pathlib.Path(__file__).resolve().parent.parent / 'Pixel Picker/Info.plist'
with plist.open('rb') as source:
    info = plistlib.load(source)
info['SUPublicEDKey'] = key
plist.write_bytes(plistlib.dumps(info, sort_keys=False))
print(f'Updated SUPublicEDKey in {plist}')
