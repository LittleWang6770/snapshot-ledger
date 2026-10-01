"""Audit staged blobs only; do not print potentially sensitive matched content."""
from pathlib import Path
import re
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[1]
ALLOWED = {'.gitignore', 'README.md', 'AGENTS.md', 'tools/check_privacy.py',
           'src/macapp/Models.swift', 'src/macapp/Views.swift', 'src/macapp/Charts.swift',
           'src/macapp/main.swift', 'src/macapp/build.py',
           'src/macapp/assets/AppIcon.png', 'src/macapp/assets/README.md'}

def git(*args):
    return subprocess.check_output(['git', '-C', str(ROOT), *args])

paths = git('ls-files', '-z').decode().strip('\0').split('\0')
assert paths != [''], 'Stage reviewed files before audit.'
assert set(paths) == ALLOWED, 'Tracked files must exactly match the reviewed allowlist.'
for path in paths:
    data = git('show', ':' + path)
    if path.endswith('.png'):
        assert data[:8] == b'\x89PNG\r\n\x1a\n'
        offset = 8
        while offset < len(data):
            n = struct.unpack('>I', data[offset:offset+4])[0]
            assert data[offset+4:offset+8] in {b'IHDR', b'IDAT', b'IEND', b'PLTE', b'tRNS', b'sRGB', b'gAMA', b'cHRM', b'iCCP'}, 'Unexpected image metadata'
            offset += n + 12
        continue
    text = data.decode('utf-8')
    # Assemble patterns so this audit source does not match its own checks.
    patterns = [r'/' + r'Users/[^/\s]+', r'gh' + r'[pousr]_[A-Za-z0-9]{20,}',
                r'github' + r'_pat_[A-Za-z0-9_]+', '-----' + 'BEGIN ' + r'.*PRIVATE' + ' KEY-----']
    assert not any(re.search(p, text) for p in patterns), f'Private path or credential detected: {path}'
build = git('show', ':src/macapp/build.py').decode()
assert 'normalized' not in build and 'seed.json' not in build, 'Build must not embed ledger data'
print(f'Privacy audit passed: {len(paths)} reviewed files, no ledger artifacts or image text metadata.')
