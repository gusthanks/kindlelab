"""Safety tests for the USB-drive installer. All writes stay in an isolated temporary directory."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
import subprocess
import sys
import zipfile
from unittest import mock

REPO = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('kindlelab_installer', REPO / 'installer/kindlelab_installer.py')
mod = importlib.util.module_from_spec(SPEC)
assert SPEC and SPEC.loader
SPEC.loader.exec_module(mod)


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='kindlelab-test-')
        self.addCleanup(self.tmp.cleanup)
        self.root = (Path(self.tmp.name) / 'Kindle').resolve()
        self.root.mkdir()
        for name, data in {
            'system/version.txt': b'Kindle 5.16.2.1.1 (409747 002)',
            'koreader/reader.lua': b'-- installed KOReader',
            'koreader/koreader.sh': b'#!/bin/sh\n',
            'koreader/git-rev': b'v2026.07.1\n',
            'documents/Example.epub': b'UNCHANGED BOOK',
            'koreader/settings.reader.lua': b'return { mascot = "mine" }',
        }.items():
            p = self.root / name
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_bytes(data)
        self.payload = mod.payload_from_repo(REPO)

    def tree(self):
        return {p.relative_to(self.root).as_posix(): p.read_bytes()
                for p in self.root.rglob('*') if p.is_file()}

    def test_plan_is_read_only_and_preserves_existing_launcher(self):
        p = self.root / 'documents/KOReader.sh'
        p.write_bytes(b'# Icon: my-own-icon.png\ncustom launcher')
        before = self.tree()
        plan = mod.make_plan(self.root, self.payload, model='pw3')
        self.assertEqual(plan['preserved'], ['documents/KOReader.sh'])
        self.assertNotIn('documents/KOReader.sh', [i['path'] for i in plan['changes']])
        self.assertEqual(self.tree(), before)

    def test_preflight_refuses_wrong_folder_missing_koreader_and_untested_model(self):
        with self.assertRaisesRegex(mod.InstallError, 'Kindle'):
            mod.make_plan(self.root / 'documents', self.payload, model='pw3')
        (self.root / 'koreader/reader.lua').unlink()
        with self.assertRaisesRegex(mod.InstallError, 'KOReader'):
            mod.make_plan(self.root, self.payload, model='pw3')
        (self.root / 'koreader/reader.lua').write_bytes(b'-- KOReader')
        with self.assertRaisesRegex(mod.InstallError, 'untested'):
            mod.make_plan(self.root, self.payload, model='unknown')
        self.assertTrue(mod.make_plan(self.root, self.payload, model='unknown', allow_untested=True)['warnings'])

    def test_preflight_rejects_payload_paths_outside_its_exact_allowlist(self):
        before = self.tree()
        for p in ['../outside', '/etc/passwd', 'documents/Example.epub', 'koreader/settings.reader.lua',
                  'koreader/plugins/kindlelab.koplugin/../other.lua']:
            with self.assertRaises(mod.InstallError, msg=p):
                mod.make_plan(self.root, {p: b'bad'}, model='pw3')
        self.assertEqual(self.tree(), before)

    def test_preflight_rejects_symlink_destinations(self):
        dest = self.root / 'koreader/patches'
        outside = Path(self.tmp.name) / 'outside'
        outside.mkdir()
        try:
            dest.symlink_to(outside, target_is_directory=True)
        except OSError:
            self.skipTest('Symlinks need privileges on this platform')
        with self.assertRaisesRegex(mod.InstallError, 'link'):
            mod.make_plan(self.root, self.payload, model='pw3')

    def test_reparse_attributes_are_rejected_without_path_is_junction(self):
        from types import SimpleNamespace
        real_lstat = Path.lstat
        for suspect in (self.root, self.root / 'koreader', self.root / 'koreader/reader.lua'):
            def lstat(path, *args, **kwargs):
                info = real_lstat(path, *args, **kwargs)
                if path == suspect:
                    return SimpleNamespace(st_mode=info.st_mode,
                                           st_file_attributes=mod.stat.FILE_ATTRIBUTE_REPARSE_POINT)
                return info
            with self.subTest(suspect=suspect), mock.patch.object(Path, 'lstat', lstat), \
                    mock.patch.object(Path, 'is_junction', return_value=False, create=True):
                with self.assertRaisesRegex(mod.InstallError, 'link'):
                    mod.safe_path(self.root, 'koreader/reader.lua')

    @unittest.skipUnless(sys.platform == 'win32', 'Real junctions require Windows')
    def test_real_windows_junction_root_and_inner_components_are_refused(self):
        outside = Path(self.tmp.name) / 'outside'
        outside.mkdir()
        for junction in (Path(self.tmp.name) / 'root-junction', self.root / 'koreader/patches'):
            target = self.root if junction.name == 'root-junction' else outside
            p = subprocess.run(['cmd', '/c', 'mklink', '/J', str(junction), str(target)],
                               capture_output=True, text=True)
            self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
            self.addCleanup(junction.rmdir)
            chosen = junction if junction.name == 'root-junction' else self.root
            with self.assertRaisesRegex(mod.InstallError, 'link'):
                mod.safe_path(chosen, 'koreader/patches/test.lua')

    def test_install_backs_up_verifies_reinstalls_and_can_be_undone(self):
        rel = 'koreader/patches/2-kindlelab-library.lua'
        previous = self.root / rel
        previous.parent.mkdir()
        previous.write_bytes(b'-- previous version')
        before = self.tree()
        result = mod.install(self.root, self.payload, model='pw3', closed=True)
        self.assertEqual(result['status'], 'committed')
        self.assertTrue(result['id'])
        for p, data in self.payload.items():
            self.assertEqual((self.root / p).read_bytes(), data)
        self.assertEqual((self.root / 'documents/Example.epub').read_bytes(), before['documents/Example.epub'])
        self.assertEqual((self.root / 'koreader/settings.reader.lua').read_bytes(), before['koreader/settings.reader.lua'])
        again = mod.install(self.root, self.payload, model='pw3', closed=True)
        self.assertEqual(again['status'], 'unchanged')
        undone = mod.undo(self.root, result['id'], closed=True)
        self.assertEqual(undone['status'], 'restored')
        after = {p: data for p, data in self.tree().items() if not p.startswith('.kindlelab-installer/')}
        self.assertEqual(after, before)

    @unittest.skipIf(sys.platform == 'win32', 'POSIX directory fsync ordering')
    def test_atomic_write_syncs_created_directories_and_replacement(self):
        events = []
        real_mkdir, real_replace, real_fsync = mod.os.mkdir, mod.os.replace, mod.os.fsync
        def mkdir(path, *args, **kwargs):
            result = real_mkdir(path, *args, **kwargs)
            events.append(('mkdir', Path(path)))
            return result
        def replace(src, dst):
            result = real_replace(src, dst)
            events.append(('replace', Path(dst)))
            return result
        def fsync(fd):
            events.append(('fsync', mod.stat.S_ISDIR(mod.os.fstat(fd).st_mode)))
            return real_fsync(fd)
        real_sync = getattr(mod, '_sync_directory', lambda path: None)
        def sync(path):
            real_sync(path)
            events.append(('sync', Path(path)))
        with mock.patch.object(mod.os, 'mkdir', side_effect=mkdir), \
                mock.patch.object(mod.os, 'replace', side_effect=replace), \
                mock.patch.object(mod.os, 'fsync', side_effect=fsync), \
                mock.patch.object(mod, '_sync_directory', side_effect=sync, create=True):
            mod.atomic_write(self.root, 'koreader/new/nested/file.lua', b'new')
        target = self.root / 'koreader/new/nested/file.lua'
        replaced = events.index(('replace', target))
        self.assertIn(('sync', target.parent), events[replaced + 1:])
        self.assertIn(('fsync', True), events)
        self.assertIn(('fsync', False), events[:replaced])
        for directory in (target.parent.parent, target.parent):
            created = events.index(('mkdir', directory))
            self.assertIn(('sync', directory), events[created + 1:replaced])
            self.assertIn(('sync', directory.parent), events[created + 1:replaced])

    @unittest.skipIf(sys.platform == 'win32', 'POSIX directory fsync interruption')
    def test_directory_creation_sync_is_retried_for_existing_ancestors(self):
        rel = 'koreader/new/nested/file.lua'
        directory = self.root / 'koreader/new'
        real_sync = mod._sync_directory
        def interrupt(path):
            if path == directory:
                raise OSError('interrupted mkdir sync')
            return real_sync(path)
        with mock.patch.object(mod, '_sync_directory', side_effect=interrupt):
            with self.assertRaisesRegex(OSError, 'interrupted mkdir sync'):
                mod.atomic_write(self.root, rel, b'new')
        self.assertTrue(directory.is_dir())
        with mock.patch.object(mod, '_sync_directory', wraps=real_sync) as sync:
            mod.atomic_write(self.root, rel, b'new')
        self.assertIn(mock.call(directory.parent), sync.call_args_list)
        self.assertEqual((self.root / rel).read_bytes(), b'new')

    @unittest.skipIf(sys.platform == 'win32', 'POSIX directory fsync ordering')
    def test_preparation_publication_and_state_parents_sync_before_targets(self):
        old = self.root / 'koreader/patches/2-kindlelab-library.lua'
        old.parent.mkdir()
        old.write_bytes(b'original')
        events = []
        real_replace, real_sync, real_write = mod.os.replace, mod._sync_directory, mod.atomic_write
        real_save = mod.save_receipt
        def replace(src, dst):
            real_replace(src, dst)
            events.append(('replace', Path(src), Path(dst)))
        def sync(path):
            real_sync(path)
            events.append(('sync', Path(path)))
        def write(root, rel, data, mode=0o644):
            if not rel.startswith(mod.STATE + '/'):
                events.append(('target', rel))
            return real_write(root, rel, data, mode)
        def save(root, receipt, **kwargs):
            events.append(('receipt', receipt['status']))
            return real_save(root, receipt, **kwargs)
        with mock.patch.object(mod.os, 'replace', side_effect=replace), \
                mock.patch.object(mod, '_sync_directory', side_effect=sync), \
                mock.patch.object(mod, 'atomic_write', side_effect=write), \
                mock.patch.object(mod, 'save_receipt', side_effect=save):
            result = mod.install(self.root, self.payload, model='pw3', closed=True)
        staged = self.root / mod.STATE / 'preparing' / result['id']
        published = self.root / mod.STATE / 'transactions' / result['id']
        publication = events.index(('replace', staged, published))
        target = next(i for i, event in enumerate(events) if event[0] == 'target')
        self.assertIn(('sync', staged), events[:publication])
        for parent in (staged.parent, published.parent):
            self.assertIn(('sync', parent), events[publication + 1:target])
        for directory in (self.root, self.root / mod.STATE, published.parent):
            self.assertIn(('sync', directory), events[:publication])
        backup = staged / 'originals/koreader/patches/2-kindlelab-library.lua'
        backed_up = next(i for i, event in enumerate(events)
                         if event[0] == 'replace' and event[2] == backup)
        self.assertIn(('sync', backup.parent), events[backed_up + 1:publication])
        committed = events.index(('receipt', 'committed'))
        for entry in result['files']:
            dest = self.root / entry['path']
            replaced = next(i for i, event in enumerate(events)
                            if event[0] == 'replace' and event[2] == dest)
            self.assertIn(('sync', dest.parent), events[replaced + 1:committed])

    @unittest.skipIf(sys.platform == 'win32', 'POSIX directory fsync interruption')
    def test_publication_sync_failure_never_touches_targets_and_is_recoverable(self):
        before = self.tree()
        real_sync = mod._sync_directory
        transaction_parent = self.root / mod.STATE / 'transactions'
        def interrupt(path):
            if path == transaction_parent and any(path.iterdir()):
                raise OSError('interrupted publication sync')
            return real_sync(path)
        with mock.patch.object(mod, '_sync_directory', side_effect=interrupt):
            with self.assertRaisesRegex(OSError, 'interrupted publication sync'):
                mod.install(self.root, self.payload, model='pw3', closed=True)
        after = {p: data for p, data in self.tree().items() if not p.startswith(mod.STATE + '/')}
        self.assertEqual(after, before)
        pending = mod.transactions(self.root)
        self.assertEqual(len(pending), 1)
        self.assertEqual(pending[0]['status'], 'prepared')
        self.assertEqual(mod.undo(self.root, pending[0]['id'], closed=True)['status'], 'restored')
        self.assertEqual(mod.install(self.root, self.payload, model='pw3', closed=True)['status'], 'committed')

    @unittest.skipIf(sys.platform == 'win32', 'POSIX directory fsync ordering')
    def test_undo_syncs_deleted_and_replaced_entries_before_completion(self):
        old = 'koreader/patches/2-kindlelab-library.lua'
        new = 'koreader/screensavers/kindlelab-reader.png'
        (self.root / old).parent.mkdir()
        (self.root / old).write_bytes(b'original')
        receipt = mod.install(self.root, {p: self.payload[p] for p in (old, new)}, model='pw3', closed=True)
        events = []
        real_unlink, real_replace = Path.unlink, mod.os.replace
        real_sync, real_save = mod._sync_directory, mod.save_receipt
        def unlink(path, *args, **kwargs):
            result = real_unlink(path, *args, **kwargs)
            events.append(('unlink', Path(path)))
            return result
        def replace(src, dst):
            real_replace(src, dst)
            events.append(('replace', Path(dst)))
        def sync(path):
            real_sync(path)
            events.append(('sync', Path(path)))
        def save(root, receipt, **kwargs):
            events.append(('receipt', receipt['status']))
            return real_save(root, receipt, **kwargs)
        with mock.patch.object(Path, 'unlink', unlink), \
                mock.patch.object(mod.os, 'replace', side_effect=replace), \
                mock.patch.object(mod, '_sync_directory', side_effect=sync), \
                mock.patch.object(mod, 'save_receipt', side_effect=save):
            mod.undo(self.root, receipt['id'], closed=True)
        complete = events.index(('receipt', 'restored'))
        started = events.index(('receipt', 'recovery-required'))
        for operation, rel in (('unlink', new), ('replace', old)):
            changed = events.index((operation, self.root / rel))
            self.assertLess(started, changed)
            self.assertIn(('sync', (self.root / rel).parent), events[changed + 1:complete])

    @unittest.skipIf(sys.platform == 'win32', 'POSIX directory fsync interruption')
    def test_interrupted_undo_retries_sync_of_already_deleted_entry(self):
        old = 'koreader/patches/2-kindlelab-library.lua'
        new = 'koreader/screensavers/kindlelab-reader.png'
        (self.root / old).parent.mkdir()
        (self.root / old).write_bytes(b'original')
        receipt = mod.install(self.root, {p: self.payload[p] for p in (old, new)}, model='pw3', closed=True)
        deleted_parent = (self.root / new).parent
        real_sync = mod._sync_directory
        def interrupt(path):
            if path == deleted_parent:
                raise OSError('interrupted deletion sync')
            return real_sync(path)
        with mock.patch.object(mod, '_sync_directory', side_effect=interrupt):
            with self.assertRaisesRegex(OSError, 'interrupted deletion sync'):
                mod.undo(self.root, receipt['id'], closed=True)
        self.assertEqual(mod.load_receipt(self.root, receipt['id'])['status'], 'recovery-required')
        self.assertFalse((self.root / new).exists())
        self.assertEqual((self.root / old).read_bytes(), self.payload[old])
        with mock.patch.object(mod, '_sync_directory', wraps=real_sync) as sync:
            result = mod.undo(self.root, receipt['id'], closed=True)
        self.assertIn(mock.call(deleted_parent), sync.call_args_list)
        self.assertEqual(result['status'], 'restored')
        self.assertEqual(mod.load_receipt(self.root, receipt['id'])['status'], 'restored')
        self.assertEqual((self.root / old).read_bytes(), b'original')
        self.assertFalse((self.root / new).exists())

    def test_install_requires_explicit_closed_koreader_confirmation(self):
        before = self.tree()
        with self.assertRaisesRegex(mod.InstallError, 'KOReader'):
            mod.install(self.root, self.payload, model='pw3')
        self.assertEqual(self.tree(), before)

    def test_no_space_is_refused_before_any_write(self):
        before = self.tree()
        with mock.patch.object(mod.shutil, 'disk_usage', return_value=type('Usage', (), {'free': 0})()):
            with self.assertRaisesRegex(mod.InstallError, 'space'):
                mod.install(self.root, self.payload, model='pw3', closed=True)
        self.assertEqual(self.tree(), before)

    def test_io_failure_halfway_rolls_back_every_target(self):
        before = self.tree()
        real_write, failed = mod.atomic_write, []
        def fault(root, rel, data, mode=0o644):
            if rel.endswith('/main.lua') and not failed:
                failed.append(True)
                raise OSError('simulated unplug')
            return real_write(root, rel, data, mode)
        with mock.patch.object(mod, 'atomic_write', side_effect=fault):
            with self.assertRaisesRegex(mod.InstallError, 'originals restored'):
                mod.install(self.root, self.payload, model='pw3', closed=True)
        after = {p: b for p, b in self.tree().items() if not p.startswith('.kindlelab-installer/')}
        self.assertEqual(after, before)
        self.assertEqual(mod.transactions(self.root)[-1]['status'], 'rolled-back')

    def test_undo_does_not_overwrite_files_edited_after_installation(self):
        result = mod.install(self.root, self.payload, model='pw3', closed=True)
        (self.root / 'koreader/patches/2-kindlelab-library.lua').write_bytes(b'-- MY EDIT')
        before = self.tree()
        with self.assertRaisesRegex(mod.InstallError, 'changed'):
            mod.undo(self.root, result['id'], closed=True)
        self.assertEqual(self.tree(), before)

    def test_corrupted_backup_blocks_undo_before_any_target_changes(self):
        rel = 'koreader/patches/2-kindlelab-library.lua'
        p = self.root / rel
        p.parent.mkdir()
        p.write_bytes(b'old patch')
        result = mod.install(self.root, self.payload, model='pw3', closed=True)
        (self.root / mod.STATE / 'transactions' / result['id'] / 'originals' / rel).write_bytes(b'CORRUPT')
        before = self.tree()
        with self.assertRaisesRegex(mod.InstallError, 'SHA-256'):
            mod.undo(self.root, closed=True)
        self.assertEqual(self.tree(), before)

    def test_concurrent_installer_lock_blocks_installation(self):
        (self.root / mod.STATE / 'lock').mkdir(parents=True)
        before = self.tree()
        with self.assertRaisesRegex(mod.InstallError, 'lock'):
            mod.install(self.root, self.payload, model='pw3', closed=True)
        self.assertEqual(self.tree(), before)

    def test_unfinished_transaction_requires_recovery_even_if_code_is_unchanged(self):
        result = mod.install(self.root, self.payload, model='pw3', closed=True)
        result['status'] = 'prepared'
        mod.save_receipt(self.root, result)
        with self.assertRaisesRegex(mod.InstallError, 'Unfinished'):
            mod.install(self.root, self.payload, model='pw3', closed=True)
        self.assertEqual(mod.undo(self.root, result['id'], closed=True)['status'], 'restored')

    def test_malicious_receipt_cannot_restore_a_book_or_escape_the_root(self):
        result = mod.install(self.root, self.payload, model='pw3', closed=True)
        for bad in ('../outside', 'documents/Example.epub'):
            result['files'][0]['path'] = bad
            mod.save_receipt(self.root, result)
            before = self.tree()
            with self.assertRaisesRegex(mod.InstallError, 'Unsafe'):
                mod.undo(self.root, result['id'], closed=True)
            self.assertEqual(self.tree(), before)

    def bundle(self):
        output = Path(self.tmp.name) / 'KindleLab.zip'
        p = subprocess.run([sys.executable, str(REPO / 'scripts/build-installer.py'), '--output', str(output)],
                           capture_output=True, text=True)
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
        into = Path(self.tmp.name) / 'Unpacked with spaces'
        with zipfile.ZipFile(output) as z:
            self.assertEqual(z.testzip(), None)
            z.extractall(into)
        return into / ('KindleLab-' + mod.VERSION)

    def test_zip_is_offline_and_cli_dry_run_apply_undo_work_from_any_folder(self):
        bundle = self.bundle()
        script = bundle / 'install.py'
        before = self.tree()
        cmd = [sys.executable, str(script), '--target', str(self.root), '--model', 'pw3', '--lang', 'pt']
        p = subprocess.run(cmd + ['--dry-run'], cwd=self.tmp.name, capture_output=True, text=True)
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
        self.assertIn('Simulação', p.stdout)
        self.assertEqual(self.tree(), before)
        p = subprocess.run(cmd + ['--yes', '--closed'], capture_output=True, text=True)
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
        self.assertIn('SHA-256', p.stdout)
        p = subprocess.run(cmd + ['--undo', '--yes', '--closed'], capture_output=True, text=True)
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
        after = {p: b for p, b in self.tree().items() if not p.startswith('.kindlelab-installer/')}
        self.assertEqual(after, before)

    def test_corrupted_payload_in_zip_is_rejected_before_writes(self):
        bundle = self.bundle()
        (bundle / 'payload/koreader/plugins/kindlelab.koplugin/main.lua').write_bytes(b'corrupted download')
        before = self.tree()
        p = subprocess.run([sys.executable, str(bundle / 'install.py'), '--target', str(self.root),
                            '--model', 'pw3', '--dry-run'], capture_output=True, text=True)
        self.assertNotEqual(p.returncode, 0)
        self.assertIn('SHA-256', p.stderr)
        self.assertEqual(self.tree(), before)

    def test_host_path_symlinks_are_canonicalized_but_chosen_root_links_are_refused(self):
        alias = Path(self.tmp.name) / 'host-alias'
        try:
            alias.symlink_to(self.root.parent, target_is_directory=True)
        except OSError:
            self.skipTest('Symlinks need privileges on this platform')
        # macOS /var -> /private/var is a normal host alias, not a link inside the chosen drive.
        self.assertTrue(mod.make_plan(alias / 'Kindle', self.payload, model='pw3')['changes'])
        root_alias = Path(self.tmp.name) / 'kindle-alias'
        root_alias.symlink_to(self.root, target_is_directory=True)
        with self.assertRaisesRegex(mod.InstallError, 'link'):
            mod.make_plan(root_alias, self.payload, model='pw3')

    def test_backup_failure_cannot_leave_an_unrecoverable_transaction(self):
        rel = 'koreader/patches/2-kindlelab-library.lua'
        p = self.root / rel
        p.parent.mkdir()
        p.write_bytes(b'old patch')
        before = self.tree()
        real = mod.atomic_write
        def failure(root, path, data, mode=0o644):
            if '/originals/' in path:
                real(root, path, data, mode)
                raise OSError('simulated interruption after backing up a file')
            return real(root, path, data, mode)
        with mock.patch.object(mod, 'atomic_write', side_effect=failure):
            with self.assertRaises((mod.InstallError, OSError)):
                mod.install(self.root, self.payload, model='pw3', closed=True)
        after = {p: b for p, b in self.tree().items() if not p.startswith('.kindlelab-installer/')}
        self.assertEqual(after, before)
        self.assertEqual(mod.install(self.root, self.payload, model='pw3', closed=True)['status'], 'committed')

    def test_malformed_manifest_and_missing_receipt_fields_are_safe_refusals(self):
        bundle = self.bundle()
        import json
        for malformed in ([], None, {'schema': 1, 'version': mod.VERSION, 'files': list(mod.ALLOWED)}):
            (bundle / 'manifest.json').write_text(json.dumps(malformed), encoding='utf-8')
            with self.assertRaises(mod.InstallError):
                mod.load_payload(bundle)
        receipt = mod.install(self.root, self.payload, model='pw3', closed=True)
        del receipt['files'][0]['before']
        mod.save_receipt(self.root, receipt)
        before = self.tree()
        with self.assertRaises(mod.InstallError):
            mod.undo(self.root, receipt['id'], closed=True)
        self.assertEqual(self.tree(), before)

    def test_unknown_or_other_koreader_version_requires_explicit_override(self):
        for value in (b'v2025.01', b'v2026.09', b'unknown'):
            (self.root / 'koreader/git-rev').write_bytes(value)
            with self.assertRaisesRegex(mod.InstallError, 'KOReader'):
                mod.make_plan(self.root, self.payload, model='pw3')
            p = mod.make_plan(self.root, self.payload, model='pw3', allow_untested=True)
            self.assertIn('untested', p['warnings'])
        (self.root / 'koreader/git-rev').unlink()
        with self.assertRaisesRegex(mod.InstallError, 'KOReader'):
            mod.make_plan(self.root, self.payload, model='pw3')

    def test_payload_contains_only_kindlelab_files_and_no_personal_settings(self):
        payload = mod.payload_from_repo(REPO)
        self.assertIn('koreader/plugins/kindlelab.koplugin/main.lua', payload)
        self.assertIn('koreader/patches/2-kindlelab-library.lua', payload)
        self.assertIn('koreader/kindlelab/icons/woodcut-reader.png', payload)
        self.assertIn('documents/KOReader.sh', payload)
        self.assertTrue(all(mod.allowed_path(p) for p in payload))
        self.assertNotIn('koreader/settings.reader.lua', payload)
        self.assertTrue(all(not p.startswith('koreader/settings/') for p in payload))
        self.assertTrue(all(not p.startswith('documents/') or p == 'documents/KOReader.sh' for p in payload))


if __name__ == '__main__':
    unittest.main()
