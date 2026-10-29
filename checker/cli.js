#!/usr/bin/env node
// The same check from a terminal (read-only):
//   node checker/cli.js /path/to/the/Kindle/drive [--lang pt] [--json]
//   node checker/cli.js --snapshot snapshot.json [--lang pt] [--json]
import { opendir, readFile, stat } from 'node:fs/promises';
import path from 'node:path';
import { analyze } from './analyze.js';
import { snapshotFromHandle } from './snapshot.js';
import { MESSAGES, guideUrl } from './messages.js';

const ICON = { done: '✅', now: '👉', warn: '⚠️ ', todo: '⬜', optional: '➕' };
const fill = (text, vars) => text.replace(/\{(\w+)\}/g, (_, key) => vars[key] ?? '');

// The browser's folder-handle interface, over the local file system.
function fileHandle(file, size, start = 0) {
  return {
    size: size - start,
    slice: (from) => fileHandle(file, size, start + from),
    text: async () => (await readFile(file)).subarray(start).toString('utf8'),
  };
}
function dirHandle(dir) {
  return {
    kind: 'directory',
    async *entries() {
      for await (const entry of await opendir(dir)) {
        yield [entry.name, { kind: entry.isDirectory() ? 'directory' : 'file' }];
      }
    },
    async getDirectoryHandle(name) {
      const target = path.join(dir, name);
      if (!(await stat(target)).isDirectory()) throw new Error(`${target} is not a folder`);
      return dirHandle(target);
    },
    async getFileHandle(name) {
      const target = path.join(dir, name);
      const info = await stat(target);
      if (!info.isFile()) throw new Error(`${target} is not a file`);
      return { kind: 'file', getFile: async () => fileHandle(target, info.size) };
    },
  };
}

function report(r, lang) {
  const m = MESSAGES[lang];
  if (r.kind !== 'kindle') return m.kind[r.kind];
  const next = m.next[r.next];
  const vars = { files: (r.updateFiles || []).join(', '), version: r.firmware || '?' };
  const lines = [`KindleLab · ${m.title}`, ''];
  lines.push(r.firmware ? fill(m.firmware, { version: r.firmware }) : m.noFirmware);
  if (r.method) lines.push(fill(m.method[r.method], { version: r.jbVersion ? ` (jb.sh ${r.jbVersion})` : '' }));
  lines.push('', `${ICON[r.steps[r.step]] || '🎉'} ${next.title}`, `   ${next.text}`, `   ${guideUrl(lang, next.anchor)}`);
  for (const key of r.notes) lines.push('', `• ${fill(m.notes[key], vars)}`);
  lines.push('');
  for (let s = 1; s <= 8; s++) lines.push(`${ICON[r.steps[s]]} ${s}. ${m.steps[s]} (${m.status[r.steps[s]]})`);
  return lines.join('\n');
}

const args = process.argv.slice(2);
const option = (name) => (args.includes(name) ? args[args.indexOf(name) + 1] : undefined);
const lang = option('--lang') || ((process.env.LANG || '').startsWith('pt') ? 'pt' : 'en');
const snapshotFile = option('--snapshot');
const folder = args.find((a, i) => !a.startsWith('--') && !['--lang', '--snapshot'].includes(args[i - 1]));
if (!snapshotFile && !folder) {
  console.error('usage: node checker/cli.js <Kindle folder> [--lang en|pt] [--json]\n   or: node checker/cli.js --snapshot file.json');
  process.exit(2);
}
const snapshot = snapshotFile
  ? JSON.parse(await readFile(snapshotFile, 'utf8'))
  : await snapshotFromHandle(dirHandle(folder));
const result = analyze(snapshot);
console.log(args.includes('--json') ? JSON.stringify(result, null, 2) : report(result, MESSAGES[lang] ? lang : 'en'));
