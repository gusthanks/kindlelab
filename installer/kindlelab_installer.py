#!/usr/bin/env python3
"""KindleLab add-on installer. Python 3.11+, standard library only; no network or firmware writes."""
from pathlib import Path, PurePosixPath
import hashlib
import os
import re
import shutil
import stat
import json
import tempfile
import uuid
from contextlib import contextmanager
from datetime import datetime, timezone

VERSION = '0.1.0'
PATCHES = ('2-kindlelab-defaults.lua', '2-kindlelab-library.lua', '2-kindlelab-store-books.lua',
           '2-kindlelab-sleepscreen.lua')
ICONS = ('woodcut-reader.png', 'pixel-vampire.png', 'open-book-sun.png')
MODULES = ('_meta.lua', 'main.lua', 'kindlelab_icon.lua', 'kindlelab_types.lua',
           'kindlelab_intake.lua', 'kindlelab_profiles.lua', 'kindlelab_readinglist.lua')
ALLOWED = frozenset(
    ['documents/KOReader.sh']
    + ['koreader/patches/' + f for f in PATCHES]
    + ['koreader/kindlelab/icons/' + f for f in ICONS]
    + ['koreader/plugins/kindlelab.koplugin/' + f for f in MODULES]
    + ['koreader/screensavers/kindlelab-reader.png']
)


class InstallError(Exception):
    """A safe refusal, not a request to reset/update the Kindle."""


def allowed_path(rel):
    return isinstance(rel, str) and rel in ALLOWED


def digest(data):
    return hashlib.sha256(data).hexdigest()


def payload_from_repo(repo):
    repo = Path(repo)
    sources = {'documents/KOReader.sh': repo / 'kindle-files/documents/KOReader.sh'}
    for name in PATCHES:
        sources['koreader/patches/' + name] = repo / 'koreader-config/patches' / name
    for name in MODULES:
        sources['koreader/plugins/kindlelab.koplugin/' + name] = repo / 'koreader-config/plugins/kindlelab.koplugin' / name
    for name in ICONS:
        sources['koreader/kindlelab/icons/' + name] = repo / 'kindle-files/koreader-tile/icons' / name
    sources['koreader/screensavers/kindlelab-reader.png'] = repo / 'kindle-files/koreader-tile/icons/woodcut-reader.png'
    return {rel: src.read_bytes() for rel, src in sorted(sources.items())}


def load_payload(base):
    """Offline bundle loader. SHA-256 checks corruption, not the publisher's identity."""
    base = Path(base)
    manifest = base / 'manifest.json'
    if not manifest.exists() and (base.parent / 'koreader-config').is_dir():
        return payload_from_repo(base.parent)
    try:
        metadata = json.loads(manifest.read_text(encoding='utf-8'))
    except (OSError, ValueError) as e:
        raise InstallError('Missing/invalid manifest.json. Extract the complete release ZIP on your computer.') from e
    if (not isinstance(metadata, dict) or metadata.get('schema') != 1 or metadata.get('version') != VERSION
            or not isinstance(metadata.get('files'), dict) or set(metadata['files']) != ALLOWED):
        raise InstallError('Installer manifest does not match this version.')
    payload = {}
    for rel, expected in sorted(metadata['files'].items()):
        p = safe_path(base, 'payload/' + rel)
        if not p.is_file() or p.stat().st_size > 4 * 1024 * 1024:
            raise InstallError('Missing/oversized payload file: ' + rel)
        data = p.read_bytes()
        if digest(data) != expected:
            raise InstallError('SHA-256 verification failed; download the ZIP again: ' + rel)
        payload[rel] = data
    validate_payload(payload)
    return payload


def _is_link_or_reparse(path):
    """lstat exposes Windows reparse points on Python 3.11 (including junctions)."""
    try:
        info = path.lstat()
    except FileNotFoundError:
        return False
    return (stat.S_ISLNK(info.st_mode)
            or bool(getattr(info, 'st_file_attributes', 0) & stat.FILE_ATTRIBUTE_REPARSE_POINT))


def safe_path(root, rel):
    """Reject symlinks/junctions in every existing component, including the supplied root."""
    pure = PurePosixPath(rel)
    if not rel or pure.is_absolute() or '..' in pure.parts or '\\' in rel or ':' in rel:
        raise InstallError('Unsafe relative path: ' + str(rel))
    root = Path(root).absolute()
    if _is_link_or_reparse(root):
        raise InstallError('Refusing link/junction as the selected root: ' + str(root))
    # Resolve normal aliases OUTSIDE the chosen drive (e.g. macOS /var -> /private/var).
    root = root.resolve()
    dest = root.joinpath(*pure.parts)
    for p in [root] + [root.joinpath(*pure.parts[:i]) for i in range(1, len(pure.parts) + 1)]:
        if _is_link_or_reparse(p):
            raise InstallError('Refusing link/junction: ' + str(p))
        if p.exists() and p != dest and not p.is_dir():
            raise InstallError('Expected a directory: ' + str(p))
    return dest


def read_hash(path):
    if not path.exists():
        return None
    if not path.is_file() or path.stat().st_nlink > 1:
        raise InstallError('Expected a regular, unlinked file: ' + str(path))
    return digest(path.read_bytes())


def validate_payload(payload):
    if not payload:
        raise InstallError('Empty installer payload')
    for rel, data in payload.items():
        if not allowed_path(rel) or not isinstance(data, bytes) or len(data) > 4 * 1024 * 1024:
            raise InstallError('Invalid installer payload: ' + str(rel))


def make_plan(root, payload, *, model='unknown', allow_untested=False):
    """Read-only preview. No directory creation, setting edits or writes of any kind."""
    validate_payload(payload)
    root = Path(root).absolute()
    if not safe_path(root, 'documents').is_dir() or not safe_path(root, 'system').is_dir():
        raise InstallError('Choose the Kindle drive itself (the folder containing documents and system).')
    if not safe_path(root, 'koreader/reader.lua').is_file() or not safe_path(root, 'koreader/koreader.sh').is_file():
        raise InstallError('KOReader must already be installed at koreader/. See the guide, step 7.')
    version_file = safe_path(root, 'system/version.txt')
    version_text = version_file.read_text(errors='replace')[:512] if version_file.is_file() else ''
    match = re.search(r'Kindle\s+(\d+(?:\.\d+)+)', version_text)
    firmware = match.group(1) if match else None
    revision = safe_path(root, 'koreader/git-rev')
    koreader_version = revision.read_text(errors='replace')[:128].strip() if revision.is_file() else None
    tested = model == 'pw3' and firmware == '5.16.2.1.1' and koreader_version == 'v2026.07.1'
    if not tested and not allow_untested:
        raise InstallError('This model/firmware/KOReader combination is untested. Read compatibility and explicitly allow untested devices.')
    warnings = ['model-not-auto-detected', 'ota-not-checked']
    if not tested:
        warnings.append('untested')
    if not safe_path(root, 'koreader/plugins/simpleui.koplugin').is_dir():
        warnings.append('simpleui-not-installed')
    changes, unchanged, preserved = [], [], []
    for rel, data in sorted(payload.items()):
        path = safe_path(root, rel)
        before = read_hash(path)
        after = digest(data)
        if before == after:
            unchanged.append(rel)
        elif rel == 'documents/KOReader.sh' and before is not None:
            preserved.append(rel)
        else:
            changes.append({'path': rel, 'before': before, 'after': after})
    needed = 20 * 1024 * 1024 + sum(len(payload[i['path']]) + (root / i['path']).stat().st_size
                                    if i['before'] else len(payload[i['path']]) for i in changes)
    if shutil.disk_usage(root).free < needed:
        raise InstallError('Not enough free space. Keep airplane mode on; free at least 20 MB plus the backup size.')
    return {'root': str(root), 'firmware': firmware, 'koreader': koreader_version, 'model': model, 'changes': changes,
            'unchanged': unchanged, 'preserved': preserved, 'warnings': warnings}


STATE = '.kindlelab-installer'
SHA = re.compile(r'^[0-9a-f]{64}$')


def _sync_directory(path):
    """Order directory entries on POSIX; errors must stop receipt completion.

    Windows os.fsync flushes regular files via the CRT, but the stdlib has no
    directory-fsync equivalent. Directory/volume FlushFileBuffers is not a
    portable unprivileged substitute, so do not claim power-loss safety there.
    Even POSIX fsync depends on filesystem, USB bridge and device-cache behavior;
    it is not a hardware guarantee (nor macOS F_FULLFSYNC).
    """
    if os.name == 'nt':
        return
    fd = os.open(path, os.O_RDONLY | getattr(os, 'O_DIRECTORY', 0))
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def _mkdir_parents(root, rel):
    """Sync directory ancestry too: a previous attempt may have failed after mkdir."""
    path = safe_path(root, rel)
    boundary = Path(root).resolve()
    directories = []
    current = path
    while current != boundary:
        directories.append(current)
        current = current.parent
    for directory in reversed(directories):
        directory.mkdir(exist_ok=True)
        _sync_directory(directory)
        _sync_directory(directory.parent)
    return path


def atomic_write(root, rel, data, mode=0o644):
    path = safe_path(root, rel)
    parent_rel = PurePosixPath(rel).parent.as_posix()
    _mkdir_parents(root, parent_rel)
    safe_path(root, rel)  # recheck after mkdir; no symlink following
    fd, name = tempfile.mkstemp(prefix='.kindlelab-', dir=str(path.parent))
    tmp = Path(name)
    try:
        with os.fdopen(fd, 'wb') as f:
            f.write(data)
            os.chmod(tmp, mode)
            f.flush()
            os.fsync(f.fileno())
        if digest(tmp.read_bytes()) != digest(data):
            raise InstallError('Staged file failed SHA-256 verification: ' + rel)
        safe_path(root, rel)
        os.replace(tmp, path)
        _sync_directory(path.parent)
        if read_hash(path) != digest(data):
            raise InstallError('Written file failed SHA-256 verification: ' + rel)
    finally:
        if tmp.exists():
            tmp.unlink()


def save_receipt(root, receipt, *, area='transactions'):
    if area not in ('transactions', 'preparing'):
        raise InstallError('Invalid receipt area')
    rel = STATE + '/' + area + '/' + receipt['id'] + '/receipt.json'
    atomic_write(root, rel, (json.dumps(receipt, indent=2, sort_keys=True) + '\n').encode(), 0o600)


def load_receipt(root, transaction_id):
    if not re.fullmatch(r'[A-Za-z0-9-]{1,80}', transaction_id):
        raise InstallError('Invalid backup id')
    f = safe_path(root, STATE + '/transactions/' + transaction_id + '/receipt.json')
    try:
        receipt = json.loads(f.read_text(encoding='utf-8'))
    except (OSError, ValueError) as e:
        raise InstallError('Cannot read backup receipt: ' + transaction_id) from e
    if not isinstance(receipt, dict) or receipt.get('schema') != 1 or receipt.get('id') != transaction_id:
        raise InstallError('Invalid backup receipt')
    if receipt.get('status') not in ('prepared', 'committed', 'restored', 'rolled-back', 'recovery-required'):
        raise InstallError('Invalid transaction state')
    entries = receipt.get('files')
    if not isinstance(entries, list) or not entries or len(entries) > len(ALLOWED):
        raise InstallError('Invalid backup file list')
    seen = set()
    for entry in entries:
        if not isinstance(entry, dict) or not allowed_path(entry.get('path')) or entry['path'] in seen:
            raise InstallError('Unsafe/duplicate path in backup receipt')
        seen.add(entry['path'])
        if not {'path', 'before', 'after', 'mode'}.issubset(entry):
            raise InstallError('Missing field in backup receipt')
        if not isinstance(entry.get('after'), str) or not SHA.fullmatch(entry['after']):
            raise InstallError('Invalid SHA-256 in backup receipt')
        before = entry.get('before')
        if before is not None and (not isinstance(before, str) or not SHA.fullmatch(before)):
            raise InstallError('Invalid backup SHA-256')
        if not isinstance(entry.get('mode'), int) or not 0 <= entry['mode'] <= 0o777:
            raise InstallError('Invalid backup file mode')
    return receipt


def transactions(root):
    base = safe_path(root, STATE + '/transactions')
    if not base.exists():
        return []
    return [load_receipt(root, p.name) for p in sorted(base.iterdir()) if p.is_dir()]


@contextmanager
def installer_lock(root):
    lock = safe_path(root, STATE + '/lock')
    _mkdir_parents(root, STATE)
    try:
        lock.mkdir()
    except FileExistsError as e:
        raise InstallError('Installer lock exists. Close the other installer. If it crashed, see Recovery in the guide.') from e
    try:
        _sync_directory(lock)
        _sync_directory(lock.parent)
        yield
    finally:
        lock.rmdir()
        _sync_directory(lock.parent)


def _restore(root, receipt, *, status='restored'):
    """Preflight ALL hashes before restoring any file. Refuse edited files, never force overwrite."""
    recovering = receipt['status'] in ('prepared', 'recovery-required')
    prepared = []
    for entry in receipt['files']:
        rel = entry['path']
        dest = safe_path(root, rel)
        current = read_hash(dest)
        accepted = {entry['after'], entry['before']} if recovering else {entry['after']}
        if current not in accepted:
            raise InstallError('File changed since installation; undo stopped without overwriting it: ' + rel)
        original = None
        if entry['before'] is not None:
            b = safe_path(root, STATE + '/transactions/' + receipt['id'] + '/originals/' + rel)
            original = b.read_bytes()
            if digest(original) != entry['before']:
                raise InstallError('Backup failed SHA-256 verification: ' + rel)
        prepared.append((entry, original))
    # Mark the restore as recoverable before the first modification. Retry undo with this id if interrupted.
    receipt['status'] = 'recovery-required'
    save_receipt(root, receipt)
    for entry, original in reversed(prepared):
        rel = entry['path']
        if original is None:
            path = safe_path(root, rel)
            if path.exists():
                path.unlink()
            # Retry the entry sync even if an earlier undo unlinked it then failed.
            # An untouched prepared target may never have had a parent directory.
            if path.parent.exists():
                _sync_directory(path.parent)
        else:
            atomic_write(root, rel, original, entry['mode'])
        if read_hash(safe_path(root, rel)) != entry['before']:
            raise InstallError('Restore failed verification: ' + rel)
    receipt['status'] = status
    save_receipt(root, receipt)
    return receipt


def install(root, payload, *, model='unknown', allow_untested=False, closed=False):
    if not closed:
        raise InstallError('Close KOReader first and explicitly confirm it is closed.')
    plan = make_plan(root, payload, model=model, allow_untested=allow_untested)
    root = Path(plan['root'])
    with installer_lock(root):
        pending = [t for t in transactions(root) if t['status'] in ('prepared', 'recovery-required')]
        if pending:
            raise InstallError('Unfinished installation found. Undo/recover this backup first: ' + pending[-1]['id'])
        if not plan['changes']:
            return {'status': 'unchanged', 'id': None, 'files': []}
        ident = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ-') + uuid.uuid4().hex[:12]
        receipt = {'schema': 1, 'id': ident, 'version': VERSION, 'status': 'prepared', 'files': []}
        for entry in plan['changes']:
            rel = entry['path']
            p = safe_path(root, rel)
            if read_hash(p) != entry['before']:
                raise InstallError('File changed while planning; nothing installed: ' + rel)
            mode = stat.S_IMODE(p.stat().st_mode) & 0o777 if p.exists() else (0o755 if rel.endswith('.sh') else 0o644)
            if entry['before'] is not None:
                data = p.read_bytes()
                if digest(data) != entry['before']:
                    raise InstallError('File changed while backing up: ' + rel)
                atomic_write(root, STATE + '/preparing/' + ident + '/originals/' + rel, data, 0o600)
            receipt['files'].append(dict(entry, mode=mode))
        # An interrupted backup is only a preparing directory: target files have never been changed.
        # Publish the COMPLETE verified backup + receipt in one directory rename before any target write.
        save_receipt(root, receipt, area='preparing')
        staged = safe_path(root, STATE + '/preparing/' + ident)
        published = safe_path(root, STATE + '/transactions/' + ident)
        _mkdir_parents(root, STATE + '/transactions')
        _sync_directory(staged)
        os.replace(staged, published)
        _sync_directory(published.parent)
        _sync_directory(staged.parent)
        try:
            for entry in receipt['files']:
                rel = entry['path']
                if read_hash(safe_path(root, rel)) != entry['before']:
                    raise InstallError('File changed during installation: ' + rel)
                atomic_write(root, rel, payload[rel], entry['mode'])
            receipt['status'] = 'committed'
            save_receipt(root, receipt)
        except Exception as e:
            try:
                receipt['status'] = 'prepared'
                _restore(root, receipt, status='rolled-back')
            except Exception as undo_error:
                raise InstallError('Installation interrupted; keep the backup and recover id ' + ident
                                   + '. Cause: ' + str(e) + '; recovery: ' + str(undo_error)) from e
            raise InstallError('Installation failed; originals restored and verified. ' + str(e)) from e
        return receipt


def undo(root, transaction_id=None, *, closed=False):
    if not closed:
        raise InstallError('Close KOReader before undoing the installation.')
    root = Path(root).absolute()
    with installer_lock(root):
        if transaction_id is None:
            candidates = [t for t in transactions(root) if t['status'] in ('committed', 'prepared', 'recovery-required')]
            if not candidates:
                raise InstallError('No installation to undo on this Kindle.')
            receipt = candidates[-1]
        else:
            receipt = load_receipt(root, transaction_id)
        if receipt['status'] in ('restored', 'rolled-back'):
            return receipt
        return _restore(root, receipt)
