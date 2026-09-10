#!/usr/bin/env python3
"""Exercise real Sparkle signing using PUBLIC RFC 8032 fixtures, never release keys."""
import base64
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parent.parent
app = root / 'build/PixelPicker.xcarchive/Products/Applications/Pixel Picker.app'
if not app.is_dir():
    raise SystemExit('Run scripts/build.sh first.')
# RFC 8032 section 7.1 test vector 1: public test material, not an identity.
seed = base64.b64encode(bytes.fromhex('9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60')).decode()
public = base64.b64encode(bytes.fromhex('d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a')).decode()

def run(*args, **kwargs):
    return subprocess.run(args, check=True, **kwargs)

with tempfile.TemporaryDirectory(prefix='pixel-picker-release-test-') as temporary:
    workspace = Path(temporary)
    (workspace / 'scripts').mkdir()
    (workspace / 'dist').mkdir()
    (workspace / 'build').symlink_to(root / 'build', target_is_directory=True)
    shutil.copy2(root / 'scripts/generate-appcast.sh', workspace / 'scripts')
    fixture = workspace / 'Pixel Picker.app'
    shutil.copytree(app, fixture, symlinks=True)
    plist = fixture / 'Contents/Info.plist'
    info = plistlib.loads(plist.read_bytes())
    info.update(SUPublicEDKey=public, CFBundleShortVersionString='99.0.0', CFBundleVersion='999999999')
    plist.write_bytes(plistlib.dumps(info))
    run('codesign', '--force', '--sign', '-', str(fixture))
    archive = workspace / 'dist/PixelPicker-99.0.0-universal.zip'
    run('ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', str(fixture), str(archive))
    environment = dict(os.environ, SPARKLE_PRIVATE_ED_KEY=seed, GITHUB_REPOSITORY='acheronfail/pixel-picker')
    run(str(workspace / 'scripts/generate-appcast.sh'), 'v99.0.0', env=environment)
    assert (workspace / 'dist/appcast.xml').is_file()
    # A different public fixture seed must not be allowed to sign this archive.
    environment['SPARKLE_PRIVATE_ED_KEY'] = base64.b64encode(bytes(32)).decode()
    result = subprocess.run([str(workspace / 'scripts/generate-appcast.sh'), 'v99.0.0'],
                            env=environment, capture_output=True)
    assert result.returncode != 0, 'Mismatched private key was accepted'
print('Sparkle signed feed, archive signature, and wrong-key rejection passed (public test fixtures only).')
