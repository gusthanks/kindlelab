// Unit tests for reading a drive into a snapshot. Run: node --test tests/
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { snapshotFromHandle, snapshotFromFileList, WANTED_TEXTS } from '../checker/snapshot.js';
import { analyze } from '../checker/analyze.js';

// In-memory stand-ins for the browser's File and FileSystemDirectoryHandle (same methods the code uses).
const fakeFile = (content) => {
  const make = (s) => ({
    size: Buffer.byteLength(s),
    text: async () => s,
    slice: (start) => make(Buffer.from(s).subarray(start).toString()),
  });
  return make(content);
};
function fakeDir(tree) {
  return {
    kind: 'directory',
    async *entries() {
      for (const [name, value] of Object.entries(tree)) {
        yield [name, typeof value === 'string' ? { kind: 'file' } : { kind: 'directory' }];
      }
    },
    async getDirectoryHandle(name) {
      if (typeof tree[name] !== 'object') throw Object.assign(new Error(name), { name: 'NotFoundError' });
      return fakeDir(tree[name]);
    },
    async getFileHandle(name) {
      if (typeof tree[name] !== 'string') throw Object.assign(new Error(name), { name: 'NotFoundError' });
      return { kind: 'file', getFile: async () => fakeFile(tree[name]) };
    },
  };
}

const DRIVE = {
  documents: { 'JAILBROKEN.txt': 'You are jailbroken!\n(jb.sh 2.4.1)\n', 'Book.azw3': 'x', 'Other.pdf': 'x' },
  system: { 'version.txt': 'Kindle 5.17.1.0.3 (1234 5)', thumbnails: {} },
  extensions: {},
  fill_disk: { 'filler_1.bin': 'x' },
  'jb.sh.log': 'log',
};

test('a picked folder handle becomes a snapshot with names and the three small texts', async () => {
  const s = await snapshotFromHandle(fakeDir(DRIVE));
  assert.deepEqual(s.root.sort(), ['documents', 'extensions', 'fill_disk', 'jb.sh.log', 'system']);
  assert.deepEqual(s.dirs.documents.sort(), ['Book.azw3', 'JAILBROKEN.txt', 'Other.pdf']);
  assert.deepEqual(s.dirs.extensions, []);
  assert.equal(s.dirs.koreader, undefined);
  assert.equal(s.texts['system/version.txt'], 'Kindle 5.17.1.0.3 (1234 5)');
  assert.match(s.texts['documents/JAILBROKEN.txt'], /jb\.sh 2\.4\.1/);
  assert.equal(s.texts['extensions/MRInstaller/log/mrinstaller.log'], undefined);
  assert.equal(analyze(s).next, 'modern-cleanup');
});

test('only the end of a big log is read', async () => {
  const log = 'x'.repeat(200 * 1024) + '\nNot enough space left to process KUALBooklet';
  const s = await snapshotFromHandle(fakeDir({
    documents: {}, extensions: { MRInstaller: { log: { 'mrinstaller.log': log } } },
  }));
  const text = s.texts['extensions/MRInstaller/log/mrinstaller.log'];
  assert.ok(text.length <= 64 * 1024);
  assert.match(text, /Not enough space/);
});

// <input type="file" webkitdirectory> gives a flat list of files with paths that start with the folder name.
const listFile = (path, content = 'x') => ({ webkitRelativePath: path, ...fakeFile(content) });

test('a folder picked through a file list becomes the same kind of snapshot', async () => {
  const s = await snapshotFromFileList([
    listFile('Kindle/documents/Run Hotfix.run_hotfix'),
    listFile('Kindle/documents/KUAL.sh'),
    listFile('Kindle/extensions/MRInstaller/bin/mrinstaller.sh'),
    listFile('Kindle/extensions/renameotabin/config.xml'),
    listFile('Kindle/koreader/reader.lua'),
    listFile('Kindle/koreader/plugins/kindlelab.koplugin/main.lua'),
    listFile('Kindle/system/version.txt', 'Kindle 5.16.2.1.1 (409747 002)'),
  ]);
  assert.deepEqual(s.root.sort(), ['documents', 'extensions', 'koreader', 'system']);
  assert.deepEqual(s.dirs.extensions.sort(), ['MRInstaller', 'renameotabin']);
  assert.deepEqual(s.dirs['koreader/plugins'], ['kindlelab.koplugin']);
  assert.equal(s.texts['system/version.txt'], 'Kindle 5.16.2.1.1 (409747 002)');
  const r = analyze(s);
  assert.equal(r.method, 'legacy');
  assert.equal(r.next, 'all-done');
});

test('picking the documents folder through a file list is caught', async () => {
  const s = await snapshotFromFileList([listFile('documents/Book.azw3'), listFile('documents/dictionaries/d.mobi')]);
  assert.equal(analyze(s).kind, 'subfolder');
});

test('the texts read are exactly the three documented files', () => {
  assert.deepEqual(WANTED_TEXTS, [
    'system/version.txt', 'extensions/MRInstaller/log/mrinstaller.log', 'documents/JAILBROKEN.txt',
  ]);
});
