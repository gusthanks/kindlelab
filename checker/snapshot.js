// Reading a Kindle drive (or a copy of it) into the small snapshot that analyze() needs.
// Only file NAMES of a few folders and the text of three small files are read. Nothing is sent anywhere.

export const WANTED_DIRS = ['documents', 'extensions', 'apps', 'koreader', 'koreader/patches', 'koreader/plugins'];
export const WANTED_TEXTS = [
  'system/version.txt', 'extensions/MRInstaller/log/mrinstaller.log', 'documents/JAILBROKEN.txt',
];
const MAX_TEXT = 64 * 1024; // logs can grow; the end is what matters

async function readTail(file) {
  const part = file.size > MAX_TEXT ? file.slice(file.size - MAX_TEXT) : file;
  return part.text();
}

async function names(dirHandle) {
  const out = [];
  for await (const [name] of dirHandle.entries()) out.push(name);
  return out;
}

async function subdir(dirHandle, path) {
  let handle = dirHandle;
  for (const part of path.split('/').filter(Boolean)) {
    try {
      handle = await handle.getDirectoryHandle(part);
    } catch {
      return null;
    }
  }
  return handle;
}

// For showDirectoryPicker() in the browser, and for the command line (same interface over the file system).
export async function snapshotFromHandle(rootHandle) {
  const snapshot = { root: await names(rootHandle), dirs: {}, texts: {} };
  for (const d of WANTED_DIRS) {
    const handle = await subdir(rootHandle, d);
    if (handle) snapshot.dirs[d] = await names(handle);
  }
  for (const path of WANTED_TEXTS) {
    const parts = path.split('/');
    const dir = await subdir(rootHandle, parts.slice(0, -1).join('/'));
    if (!dir) continue;
    try {
      const fileHandle = await dir.getFileHandle(parts[parts.length - 1]);
      snapshot.texts[path] = await readTail(await fileHandle.getFile());
    } catch {
      // not there: nothing to read
    }
  }
  return snapshot;
}

// For <input type="file" webkitdirectory>: a flat list of files whose paths start with the picked folder's name.
export async function snapshotFromFileList(files) {
  const root = new Set();
  const dirs = {};
  const textFiles = {};
  for (const file of files) {
    const parts = file.webkitRelativePath.split('/').slice(1);
    if (!parts.length || !parts[0]) continue;
    root.add(parts[0]);
    for (const d of WANTED_DIRS) {
      const dp = d.split('/');
      if (parts.length > dp.length && dp.every((x, i) => x === parts[i])) {
        (dirs[d] ||= new Set()).add(parts[dp.length]);
      }
    }
    const rel = parts.join('/');
    if (WANTED_TEXTS.includes(rel)) textFiles[rel] = file;
  }
  const snapshot = { root: [...root], dirs: {}, texts: {} };
  for (const [d, set] of Object.entries(dirs)) snapshot.dirs[d] = [...set];
  for (const [path, file] of Object.entries(textFiles)) snapshot.texts[path] = await readTail(file);
  return snapshot;
}
