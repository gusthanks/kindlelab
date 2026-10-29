// The page: choose a folder, read a small snapshot, show where you are. No network is used or allowed.
import { analyze } from './analyze.js';
import { snapshotFromHandle, snapshotFromFileList } from './snapshot.js';
import { MESSAGES, guideUrl } from './messages.js';

const WARN_NOTES = new Set(['update-file', 'wb-too-new', 'mrpi-no-space', 'jb-failed']);
const ICON = { done: '✅', now: '👉', warn: '⚠️', todo: '⬜', optional: '➕' };
const $ = (selector) => document.querySelector(selector);
const fill = (text, vars) => text.replace(/\{(\w+)\}/g, (_, key) => vars[key] ?? '');

function pickLang() {
  const asked = new URLSearchParams(location.search).get('lang');
  if (asked === 'en' || asked === 'pt') return asked;
  return (navigator.languages || [navigator.language]).some((l) => /^pt\b/i.test(l || '')) ? 'pt' : 'en';
}

let lang = pickLang();
let result = null;

function el(tag, attrs, ...children) {
  const node = document.createElement(tag);
  for (const [key, value] of Object.entries(attrs || {})) node.setAttribute(key, value);
  node.append(...children);
  return node;
}
const link = (href, text) => el('a', { href, target: '_blank', rel: 'noopener noreferrer' }, text);

function renderPage() {
  const m = MESSAGES[lang];
  document.documentElement.lang = lang === 'pt' ? 'pt-BR' : 'en';
  document.title = `KindleLab · ${m.title}`;
  for (const node of document.querySelectorAll('[data-t]')) node.textContent = m[node.dataset.t];
  $('#guide-link').href = guideUrl(lang, 1).split('#')[0];
  for (const button of document.querySelectorAll('[data-lang]')) {
    button.setAttribute('aria-pressed', String(button.dataset.lang === lang));
  }
  if (result) renderResult();
}

function renderResult() {
  const m = MESSAGES[lang];
  const box = $('#result');
  box.hidden = false;
  box.replaceChildren();
  $('#pick').textContent = m.pickAgain;
  if (result.kind !== 'kindle') {
    box.append(el('div', { class: 'card warn' }, el('p', {}, m.kind[result.kind])));
    return;
  }
  const next = m.next[result.next];
  const warn = result.steps[result.step] === 'warn';
  box.append(el('div', { class: warn ? 'card warn' : 'card' },
    el('h2', {}, next.title), el('p', {}, next.text), link(guideUrl(lang, next.anchor), `${m.openGuide} →`)));

  const vars = { files: result.updateFiles.join(', '), version: result.firmware || '?' };
  for (const key of result.notes) {
    box.append(el('p', { class: WARN_NOTES.has(key) ? 'note warn' : 'note' }, fill(m.notes[key], vars)));
  }

  const facts = el('ul', { class: 'facts' },
    el('li', {}, result.firmware ? fill(m.firmware, { version: result.firmware }) : m.noFirmware));
  if (result.method) {
    const version = result.jbVersion ? ` (jb.sh ${result.jbVersion})` : '';
    facts.append(el('li', {}, fill(m.method[result.method], { version })));
  }
  box.append(facts);

  const steps = el('ol', { class: 'steps' });
  for (let s = 1; s <= 8; s++) {
    const status = result.steps[s];
    steps.append(el('li', { class: status },
      el('span', { class: 'icon', 'aria-hidden': 'true' }, ICON[status]),
      link(guideUrl(lang, s), `${s}. ${m.steps[s]}`),
      el('span', { class: 'status' }, m.status[status])));
  }
  box.append(steps);
}

function show(snapshot) {
  result = analyze(snapshot);
  $('#status').textContent = '';
  renderResult();
  return result;
}

function fail(error) {
  $('#status').textContent = fill(MESSAGES[lang].error, { error: error?.message || String(error) });
  $('#pick-other').hidden = false; // e.g. the browser refused this folder: offer the file-list way
}

async function pickWithDialog() {
  if (!window.showDirectoryPicker) {
    $('#fallback').click(); // Firefox and Safari: the classic folder upload dialog (nothing is uploaded)
    return;
  }
  let handle;
  try {
    handle = await window.showDirectoryPicker({ id: 'kindle', mode: 'read' });
  } catch (error) {
    if (error?.name === 'AbortError') $('#status').textContent = MESSAGES[lang].cancelled;
    else fail(error);
    return;
  }
  $('#status').textContent = MESSAGES[lang].reading;
  try {
    show(await snapshotFromHandle(handle));
  } catch (error) {
    fail(error);
  }
}

async function pickWithList(event) {
  const files = [...event.target.files];
  event.target.value = '';
  if (!files.length) return;
  $('#status').textContent = MESSAGES[lang].reading;
  try {
    show(await snapshotFromFileList(files));
  } catch (error) {
    fail(error);
  }
}

$('#pick').addEventListener('click', pickWithDialog);
$('#pick-other').addEventListener('click', () => $('#fallback').click());
$('#fallback').addEventListener('change', pickWithList);
for (const button of document.querySelectorAll('[data-lang]')) {
  button.addEventListener('click', () => {
    lang = button.dataset.lang;
    const url = new URL(location.href);
    url.searchParams.set('lang', lang);
    history.replaceState(null, '', url);
    renderPage();
  });
}

// For automated checks only: analyze a snapshot without opening a folder dialog.
window.kindlelabCheck = show;
renderPage();
