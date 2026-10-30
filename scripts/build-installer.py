#!/usr/bin/env python3
"""Build the offline installer ZIP, containing only files authored by KindleLab."""
import argparse
import importlib.util
import json
from pathlib import Path
import zipfile

REPO = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('kindlelab_installer', REPO / 'installer/kindlelab_installer.py')
assert SPEC and SPEC.loader
installer = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(installer)


def build(output):
    payload = installer.payload_from_repo(REPO)
    manifest = {'schema': 1, 'version': installer.VERSION,
                'files': {rel: installer.digest(b) for rel, b in payload.items()}}
    files = {'payload/' + rel: data for rel, data in payload.items()}
    for name in ('install.py', 'kindlelab_installer.py', 'Install-Windows.cmd', 'Install-macOS.command', 'Install-Linux.sh'):
        files[name] = (REPO / 'installer' / name).read_bytes()
    for name in ('INSTALL.md', 'INSTALL.pt-BR.md'):
        files[name] = (REPO / 'installer' / name).read_bytes()
    files['LICENSE'] = (REPO / 'LICENSE').read_bytes()
    files['manifest.json'] = (json.dumps(manifest, sort_keys=True, indent=2) + '\n').encode()
    output = Path(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for rel, data in sorted(files.items()):
            info = zipfile.ZipInfo('KindleLab-' + installer.VERSION + '/' + rel, (2026, 1, 1, 0, 0, 0))
            info.create_system = 3
            info.external_attr = (0o100755 if rel.endswith(('.sh', '.command')) else 0o100644) << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            z.writestr(info, data)
    checksum = output.with_name(output.name + '.sha256')
    checksum.write_text(installer.digest(output.read_bytes()) + '  ' + output.name + '\n', encoding='utf-8')
    print(f'{output.name}: {len(payload)} payload files; ZIP SHA-256 in {checksum.name}')
    return output


if __name__ == '__main__':
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--output', required=True, help='Output ZIP path (outside the repo is recommended)')
    build(ap.parse_args().output)
