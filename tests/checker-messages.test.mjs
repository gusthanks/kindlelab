// Every result the analysis can produce must have words in both languages, and every link into the
// jailbreak guide must point at a heading that really exists. Run: node --test tests/
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { NEXT_KEYS, NOTE_KEYS } from '../checker/analyze.js';
import { MESSAGES, guideUrl } from '../checker/messages.js';

const LANGS = ['en', 'pt'];
const GUIDE = { en: 'docs/jailbreak-guide.md', pt: 'docs/jailbreak-guide.pt-BR.md' };

// GitHub's heading anchors (github-slugger): lowercase, keep letters/numbers/marks, '-', '_' and spaces,
// then spaces become '-'.
function headingAnchors(file) {
  const md = readFileSync(new URL(`../${file}`, import.meta.url), 'utf8').replace(/```[\s\S]*?```/g, '');
  return new Set([...md.matchAll(/^#{1,6}\s+(.+?)\s*$/gm)].map(([, h]) => h
    .toLowerCase().replace(/[`*]/g, '').replace(/[^\p{L}\p{N}\p{M}\-_ ]/gu, '').replace(/ /g, '-')));
}

test('both languages describe every possible result', () => {
  for (const lang of LANGS) {
    const m = MESSAGES[lang];
    for (const key of NEXT_KEYS) assert.ok(m.next[key]?.title && m.next[key]?.anchor, `${lang} next ${key}`);
    for (const key of NOTE_KEYS) assert.ok(m.notes[key], `${lang} note ${key}`);
    for (const s of [1, 2, 3, 4, 5, 6, 7, 8]) assert.ok(m.steps[s], `${lang} step ${s}`);
    for (const k of ['not-kindle', 'subfolder']) assert.ok(m.kind[k], `${lang} kind ${k}`);
  }
});

test('every text slot of the page exists in both languages', () => {
  const page = readFileSync(new URL('../checker/index.html', import.meta.url), 'utf8');
  const keys = [...page.matchAll(/data-t="([^"]+)"/g)].map(([, k]) => k);
  assert.ok(keys.length >= 8);
  for (const lang of LANGS) {
    for (const key of keys) assert.equal(typeof MESSAGES[lang][key], 'string', `${lang} ${key}`);
  }
});

test('every guide link points at a real heading of the guide in the same language', () => {
  for (const lang of LANGS) {
    const anchors = headingAnchors(GUIDE[lang]);
    const used = new Set([1, 2, 3, 4, 5, 6, 7, 8, ...NEXT_KEYS.map((k) => MESSAGES[lang].next[k].anchor)]);
    for (const key of used) {
      const url = guideUrl(lang, key);
      assert.ok(url.startsWith('https://github.com/gusthanks/kindlelab/blob/main/' + GUIDE[lang] + '#'), url);
      assert.ok(anchors.has(decodeURIComponent(url.split('#')[1])), `${lang}: missing heading for ${key} -> ${url}`);
    }
  }
});
