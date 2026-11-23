#!/usr/bin/env node
// changed-coverage.mjs — line coverage of the Kotlin lines this change touched.
// Reads the Kover XML report the test run already wrote (no second test run) and intersects it
// with the diff against the merge base (plus untracked files).
// Also enforces package floors: --package-min com/example/skeleton/domain=90 (prefix match, all sub-packages).
// Usage: node scripts/changed-coverage.mjs [--base develop] [--min 80] [--package-min pkg=pct] [--report <xml>]
// Exit: 0 all rules met (or nothing executable), 1 a rule is below its minimum, 2 could not run.
import { execFileSync } from 'node:child_process';
import { readFileSync, existsSync } from 'node:fs';

const arg = (name, dflt) => {
  const i = process.argv.indexOf(name);
  return i > -1 ? process.argv[i + 1] : dflt;
};
const base = arg('--base', 'develop');
const min = Number(arg('--min', '80'));
const report = arg('--report', 'app/build/reports/kover/reportDebug.xml');
const SRC = 'app/src/main/java/';

const git = (args, { diffExit = false } = {}) => {
  try { return execFileSync('git', args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }); }
  catch (e) { return diffExit && e.status === 1 && typeof e.stdout === 'string' ? e.stdout : null; }
};
const bail = (msg) => { console.error('changed-coverage: ' + msg); process.exit(2); };

const top = git(['rev-parse', '--show-toplevel'])?.trim();
if (!top) bail('not inside a git work tree');
process.chdir(top);
if (!existsSync(report)) bail(`no Kover report at ${report} (run koverXmlReportDebug first)`);
const mergeBase = git(['merge-base', base, 'HEAD'])?.trim();
if (!mergeBase) bail('no merge base against ' + base);

// Changed line numbers per file (new side of the diff).
const changedLines = new Map();
const addLines = (diffText) => {
  let file = null, inHeader = false;
  for (const line of diffText.split('\n')) {
    if (line.startsWith('diff ')) inHeader = true;
    else if (inHeader && line.startsWith('+++ ')) {
      const p = line.slice(4).replace(/^b\//, '');
      file = p.startsWith(SRC) && p.endsWith('.kt') ? p : null;
    } else if (line.startsWith('@@')) {
      inHeader = false;
      const m = /\+(\d+)(?:,(\d+))?/.exec(line);
      if (file && m) {
        const start = Number(m[1]), count = m[2] === undefined ? 1 : Number(m[2]);
        const set = changedLines.get(file) ?? new Set();
        for (let n = start; n < start + count; n++) set.add(n);
        changedLines.set(file, set);
      }
    }
  }
};
const tracked = git(['diff', '--unified=0', mergeBase, '--', SRC]);
if (tracked === null) bail('could not diff');
addLines(tracked);
const untracked = git(['ls-files', '--others', '--exclude-standard', '--', SRC]);
if (untracked === null) bail('could not list untracked files');
for (const f of untracked.split('\n').filter(Boolean)) {
  const d = git(['diff', '--no-index', '--unified=0', '/dev/null', f], { diffExit: true });
  if (d === null) bail('could not diff ' + f);
  addLines(d);
}

// Kover XML (JaCoCo format): <package name="com/example/skeleton"><sourcefile name="X.kt"><line nr= mi= ci= .../>
const xml = readFileSync(report, 'utf8');
const coverage = new Map();
for (const pkg of xml.matchAll(/<package name="([^"]*)">([\s\S]*?)<\/package>/g)) {
  for (const sf of pkg[2].matchAll(/<sourcefile name="([^"]*)">([\s\S]*?)<\/sourcefile>/g)) {
    const lines = new Map();
    for (const l of sf[2].matchAll(/<line nr="(\d+)" mi="(\d+)" ci="(\d+)"/g)) {
      lines.set(Number(l[1]), Number(l[3]) > 0);
    }
    coverage.set(`${SRC}${pkg[1]}/${sf[1]}`, lines);
  }
}

let total = 0, hit = 0;
const misses = [];
for (const [file, set] of changedLines) {
  const lines = coverage.get(file);
  for (const n of set) {
    if (!lines || !lines.has(n)) continue; // not executable, or file not instrumented
    total++;
    if (lines.get(n)) hit++; else misses.push(`${file}:${n}`);
  }
}

let failed = false;
if (total === 0) {
  console.log('changed-coverage: no executable changed lines');
} else {
  const pct = (100 * hit) / total;
  console.log(`changed-coverage: ${hit}/${total} changed executable lines covered (${pct.toFixed(1)}%, min ${min}%)`);
  if (pct + 1e-9 < min) {
    failed = true;
    console.error('Uncovered changed lines:\n  ' + misses.slice(0, 40).join('\n  '));
  }
}

// Package floors, from each package's own LINE counter (the last counter in the package element).
const pkgRule = arg('--package-min', null);
if (pkgRule) {
  const [prefix, pmin] = pkgRule.split('=');
  let pm = 0, pc = 0;
  for (const pkg of xml.matchAll(/<package name="([^"]*)">([\s\S]*?)<\/package>/g)) {
    if (pkg[1] !== prefix && !pkg[1].startsWith(prefix + '/')) continue;
    const counters = [...pkg[2].matchAll(/<counter type="LINE" missed="(\d+)" covered="(\d+)"\/>/g)];
    const last = counters.at(-1);
    if (last) { pm += Number(last[1]); pc += Number(last[2]); }
  }
  if (pm + pc === 0) {
    console.log(`package-coverage: ${prefix} has no instrumented lines yet`);
  } else {
    const ppct = (100 * pc) / (pm + pc);
    console.log(`package-coverage: ${prefix} ${pc}/${pm + pc} lines (${ppct.toFixed(1)}%, min ${pmin}%)`);
    if (ppct + 1e-9 < Number(pmin)) failed = true;
  }
}
process.exit(failed ? 1 : 0);
