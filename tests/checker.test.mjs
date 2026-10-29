// Unit tests for the "Where am I?" checker. Run: node --test tests/
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { analyze } from '../checker/analyze.js';

// A snapshot is what the page reads from the drive: root entry names, the entries of a few folders,
// and the text of a few small files. Nothing else.
const kindle = (extra = {}) => ({
  root: ['documents', 'system', 'fonts', 'voice', ...(extra.root || [])],
  dirs: { documents: ['My Clippings.txt', 'Some Book.azw3', ...(extra.documents || [])], ...(extra.dirs || {}) },
  texts: { 'system/version.txt': 'Kindle 5.16.2.1.1 (409747 002)', ...(extra.texts || {}) },
});

test('a folder that is not a Kindle is rejected', () => {
  const r = analyze({ root: ['Photos', 'Music'], dirs: {}, texts: {} });
  assert.equal(r.kind, 'not-kindle');
});

test('picking the documents folder instead of the drive is recognized', () => {
  const r = analyze({ root: ['A Book.azw3', 'dictionaries', 'Other.pdf'], dirs: {}, texts: {} });
  assert.equal(r.kind, 'subfolder');
});

test('a Kindle with nothing done yet starts at step 1', () => {
  const r = analyze(kindle());
  assert.equal(r.kind, 'kindle');
  assert.equal(r.step, 1);
  assert.equal(r.next, 'start');
  assert.equal(r.steps[1], 'now');
  assert.equal(r.steps[5], 'todo');
});

test('the firmware version is read from system/version.txt', () => {
  assert.equal(analyze(kindle()).firmware, '5.16.2.1.1');
  assert.equal(analyze({ ...kindle(), texts: {} }).firmware, null);
});

test('a downloaded update waiting in the root is the first warning', () => {
  for (const name of ['update_kindle_all_new_paperwhite_v2_5.18.2.bin', 'update.bin.tmp.partial']) {
    const r = analyze(kindle({ root: [name, 'fill_disk'] }));
    assert.equal(r.notes[0], 'update-file', name);
  }
  assert.ok(!analyze(kindle()).notes.includes('update-file'));
});

test('filler files mean step 3 is done and the wizard comes next', () => {
  const r = analyze(kindle({ root: ['fill_disk', 'Filler.sh'] }));
  assert.equal(r.step, 4);
  assert.equal(r.next, 'wizard');
  assert.deepEqual([r.steps[1], r.steps[2], r.steps[3], r.steps[4]], ['done', 'done', 'done', 'now']);
  assert.ok(r.notes.includes('check-free-space'));
});

test('WinterBreak files copied but not run yet means step 5 is under way', () => {
  const r = analyze(kindle({
    root: ['fill_disk', 'mesquito', 'apps', '.active_content_sandbox'],
    dirs: { apps: ['tech.hackerdude.winterbreak'] },
  }));
  assert.equal(r.step, 5);
  assert.equal(r.next, 'run-jailbreak');
  assert.equal(r.steps[5], 'now');
  assert.ok(!r.notes.includes('wb-too-new'));
});

test('WinterBreak on firmware 5.18.1 or newer gets a warning', () => {
  const wb = (fw) => analyze(kindle({
    root: ['fill_disk', 'mesquito', 'apps'],
    dirs: { apps: ['tech.hackerdude.winterbreak'] },
    texts: { 'system/version.txt': `Kindle ${fw} (123456 789)` },
  }));
  assert.ok(wb('5.18.1').notes.includes('wb-too-new'));
  assert.ok(wb('5.18.10.0.1').notes.includes('wb-too-new'));
  assert.ok(!wb('5.17.3').notes.includes('wb-too-new'));
});

// Legacy path, modeled on our own Paperwhite 3 (names only; the books are placeholders).
const legacy = (extra = {}) => kindle({
  root: ['winterbreak.log', 'jb.sh', 'mesquito', 'apps', 'mrpackages', 'Filler.ps1', ...(extra.root || [])],
  documents: ['Run Hotfix.run_hotfix', 'KPPMainAppV2_123_crash.tgz', ...(extra.documents || [])],
  dirs: { apps: ['tech.hackerdude.winterbreak'], extensions: ['MRInstaller', ...(extra.extensions || [])], ...(extra.dirs || {}) },
  texts: extra.texts || {},
});
const KOREADER = {
  koreader: ['reader.lua', 'koreader.sh', 'patches', 'plugins'],
  'koreader/patches': ['2-kindlelab-library.lua', '2-kindlelab-store-books.lua'],
  'koreader/plugins': ['kindlelab.koplugin', 'statistics.koplugin'],
};

test('legacy: stuck because the storage was full when KUAL was installed (our case)', () => {
  const r = analyze(legacy({
    texts: { 'extensions/MRInstaller/log/mrinstaller.log': '[MRPI r19303] Not enough space left to process KUALBooklet HDRepack, skipping' },
  }));
  assert.equal(r.method, 'legacy');
  assert.equal(r.step, 6);
  assert.equal(r.steps[5], 'done');
  assert.equal(r.steps[6], 'warn');
  assert.equal(r.next, 'free-space-kual');
  assert.ok(r.notes.includes('mrpi-no-space'));
});

test('legacy: KUAL missing without an error asks to install KUAL and MRPI', () => {
  const r = analyze(legacy());
  assert.equal(r.step, 6);
  assert.equal(r.steps[6], 'now');
  assert.equal(r.next, 'install-kual');
});

test('legacy: KUAL and MRPI present, renameotabin missing asks to block updates', () => {
  const r = analyze(legacy({ documents: ['KUAL.sh'] }));
  assert.equal(r.step, 6);
  assert.equal(r.next, 'block-updates');
});

test('legacy: updates blocked, KOReader missing asks for KOReader', () => {
  const r = analyze(legacy({ documents: ['KUAL.sh'], extensions: ['renameotabin'] }));
  assert.equal(r.step, 7);
  assert.equal(r.next, 'install-koreader');
  assert.equal(r.steps[6], 'done');
  assert.ok(r.notes.includes('check-ota'));
});

test('legacy: KOReader without KindleLab offers the optional step 8', () => {
  const r = analyze(legacy({
    root: ['koreader'], documents: ['KUAL.sh'], extensions: ['renameotabin'],
    dirs: { koreader: KOREADER.koreader },
  }));
  assert.equal(r.step, 8);
  assert.equal(r.next, 'kindlelab');
  assert.equal(r.steps[8], 'optional');
});

test('legacy: everything in place, like our Kindle today', () => {
  const r = analyze(legacy({
    root: ['koreader', 'usbnet'], documents: ['KUAL.sh', 'KUAL.sh.sdr', 'KOReader.sh'],
    extensions: ['KUAL.cfg', 'renameotabin', 'usbnet', 'koreader'], dirs: KOREADER,
  }));
  assert.equal(r.step, 9);
  assert.equal(r.next, 'all-done');
  assert.ok(Object.values(r.steps).every((s) => s === 'done'));
  assert.ok(r.notes.includes('check-ota'));
  assert.ok(!r.notes.includes('legacy-filler'));
});

test('legacy: filler still there after blocking updates gets a reminder', () => {
  const r = analyze(legacy({ root: ['fill_disk'], documents: ['KUAL.sh'], extensions: ['renameotabin'] }));
  assert.ok(r.notes.includes('legacy-filler'));
  assert.ok(!r.notes.includes('check-free-space'));
});

// Modern path: the jailbreak script leaves documents/JAILBROKEN.txt and blocks updates by itself.
const JB_TXT = { 'documents/JAILBROKEN.txt': 'You are jailbroken!\n(jb.sh 2.4.1)\nhttps://kindlemodding.org\n' };
const modern = (extra = {}) => kindle({
  root: ['jb.sh.log', 'libkh', ...(extra.root || [])],
  documents: ['JAILBROKEN.txt', ...(extra.documents || [])],
  dirs: extra.dirs || {},
  texts: { ...JB_TXT, ...(extra.texts || {}) },
});

test('modern: right after the jailbreak, the filler can go', () => {
  const r = analyze(modern({ root: ['fill_disk'] }));
  assert.equal(r.method, 'modern');
  assert.equal(r.jbVersion, '2.4.1');
  assert.equal(r.step, 6);
  assert.equal(r.next, 'modern-cleanup');
  assert.equal(r.steps[5], 'done');
  assert.ok(!r.notes.includes('check-free-space'));
});

test('modern: a leftover update file also means cleanup first', () => {
  const r = analyze(modern({ root: ['update.bin.tmp.partial'] }));
  assert.equal(r.step, 6);
  assert.equal(r.notes[0], 'update-file');
});

test('modern: clean storage moves on to KOReader, then KindleLab', () => {
  assert.equal(analyze(modern()).next, 'install-koreader');
  const done = analyze(modern({ root: ['koreader'], dirs: KOREADER }));
  assert.equal(done.step, 9);
  assert.ok(!done.notes.includes('check-ota'));
});

test('modern wins over a leftover hotfix booklet', () => {
  assert.equal(analyze(modern({ documents: ['Run Hotfix.run_hotfix'] })).method, 'modern');
});

test('a jailbreak log without the success file means the jailbreak did not finish', () => {
  const r = analyze(kindle({ root: ['jb.sh.log', 'fill_disk'] }));
  assert.equal(r.method, null);
  assert.equal(r.step, 5);
  assert.equal(r.steps[5], 'warn');
  assert.equal(r.next, 'jb-failed');
  assert.ok(r.notes.includes('jb-failed'));
  assert.ok(!analyze(legacy()).notes.includes('jb-failed'));
});
