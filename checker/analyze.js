// Pure analysis of a Kindle drive snapshot. No DOM, no network.
//
// snapshot = { root: [names at the top of the drive],
//              dirs:  { 'documents': [names], 'extensions': [names], ... },
//              texts: { 'system/version.txt': '...', ... } }

const BOOK = /\.(azw\d?|kfx|mobi|prc|pdf|epub|txt|cbz|fb2|djvu)$/i;
const UPDATE_FILE = /^update.*\.bin$|^update\.bin\.tmp\.partial$/i;
const STEPS = [1, 2, 3, 4, 5, 6, 7, 8];

// The whole vocabulary of results: what to do next, and extra notes.
export const NEXT_KEYS = ['start', 'wizard', 'run-jailbreak', 'jb-failed', 'modern-cleanup', 'free-space-kual',
  'install-kual', 'block-updates', 'install-koreader', 'kindlelab', 'all-done'];
export const NOTE_KEYS = ['update-file', 'check-free-space', 'wb-too-new', 'mrpi-no-space', 'jb-failed', 'check-ota',
  'legacy-filler'];

const has = (list = [], name) => list.some((n) => n.toLowerCase() === name.toLowerCase());

function kindOf(root) {
  if (has(root, 'documents')) return 'kindle';
  if (has(root, 'dictionaries') || root.some((n) => BOOK.test(n) || /\.sdr$/i.test(n))) return 'subfolder';
  return 'not-kindle';
}

// Numeric comparison of dotted versions: compareVersions('5.18.10', '5.18.1') > 0
export function compareVersions(a, b) {
  const pa = a.split('.').map(Number);
  const pb = b.split('.').map(Number);
  for (let i = 0; i < Math.max(pa.length, pb.length); i++) {
    const d = (pa[i] || 0) - (pb[i] || 0);
    if (d) return d;
  }
  return 0;
}

export function analyze(snapshot) {
  const root = snapshot.root || [];
  const dirs = snapshot.dirs || {};
  const texts = snapshot.texts || {};
  const kind = kindOf(root);
  if (kind !== 'kindle') return { kind };

  const firmware = (/Kindle\s+(\d+(?:\.\d+)+)/.exec(texts['system/version.txt'] || '') || [])[1] || null;
  const updateFiles = root.filter((n) => UPDATE_FILE.test(n));
  const filler = has(root, 'fill_disk');
  const wbCopied = has(root, 'mesquito') || (dirs.apps || []).some((n) => /winterbreak/i.test(n));
  const docs = dirs.documents || [];
  const ext = dirs.extensions || [];
  const modern = has(docs, 'JAILBROKEN.txt');
  const legacy = !modern && docs.some((n) => /\.run_hotfix$/i.test(n));
  const jbVersion = (/\(jb\.sh\s+([^)\s]+)\)/.exec(texts['documents/JAILBROKEN.txt'] || '') || [])[1] || null;
  const kual = docs.some((n) => /^kual/i.test(n) && !/\.sdr$/i.test(n));
  const mrpi = has(ext, 'MRInstaller');
  const renameota = has(ext, 'renameotabin');
  const mrpiNoSpace = /not enough space/i.test(texts['extensions/MRInstaller/log/mrinstaller.log'] || '');
  const koreader = has(root, 'koreader') && (has(dirs.koreader, 'reader.lua') || has(dirs.koreader, 'koreader.sh'));
  const kindlelab = (dirs['koreader/patches'] || []).some((n) => /^2-kindlelab-/i.test(n))
    || has(dirs['koreader/plugins'], 'kindlelab.koplugin');
  const jailbroken = modern || legacy;
  const jbFailed = !jailbroken && has(root, 'jb.sh.log');

  const notes = [];
  if (updateFiles.length) notes.push('update-file');

  let step = 1;
  let next = 'start';
  let warn = false;
  let method = null;
  // After the jailbreak: what is still missing, in the order of the guide.
  const afterJailbreak = () => {
    if (!koreader) return [7, 'install-koreader'];
    if (!kindlelab) return [8, 'kindlelab'];
    return [9, 'all-done'];
  };
  if (modern) {
    method = 'modern';
    if (filler || updateFiles.length) {
      step = 6;
      next = 'modern-cleanup';
    } else {
      [step, next] = afterJailbreak();
    }
  } else if (legacy) {
    method = 'legacy';
    if (!kual || !mrpi) {
      step = 6;
      if (mrpiNoSpace && !kual) {
        next = 'free-space-kual';
        warn = true;
        notes.push('mrpi-no-space');
      } else {
        next = 'install-kual';
      }
    } else if (!renameota) {
      step = 6;
      next = 'block-updates';
    } else {
      notes.push('check-ota');
      if (filler) notes.push('legacy-filler');
      [step, next] = afterJailbreak();
    }
  } else if (jbFailed) {
    step = 5;
    next = 'jb-failed';
    warn = true;
    notes.push('jb-failed');
  } else if (wbCopied) {
    step = 5;
    next = 'run-jailbreak';
    if (firmware && compareVersions(firmware, '5.18.1') >= 0) notes.push('wb-too-new');
  } else if (filler) {
    step = 4;
    next = 'wizard';
  }
  if (filler && !jailbroken) notes.push('check-free-space');

  const steps = {};
  for (const s of STEPS) {
    if (s < step) steps[s] = 'done';
    else if (s === 8) steps[s] = 'optional';
    else if (s === step) steps[s] = warn ? 'warn' : 'now';
    else steps[s] = 'todo';
  }
  return { kind, firmware, method, jbVersion, step, next, steps, notes, updateFiles };
}
