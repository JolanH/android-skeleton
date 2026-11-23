#!/usr/bin/env node
// floor-guard.mjs — diff-scoped enforcement of the CONSTRAINTS.md floor (Kotlin/Android adaptation
// of the agent-skills constraint-driven-development reference).
// Usage: node scripts/floor-guard.mjs [--base <ref>]   (default base: develop)
// Exit: 0 clean, 1 floor violation, 2 guard could not run. Run via ./scripts/check.sh, not directly.
import { execFileSync } from 'node:child_process';
import { existsSync } from 'node:fs';

const base = (() => {
  const i = process.argv.indexOf('--base');
  return i > -1 ? process.argv[i + 1] : 'develop';
})();

const git = (args, { diffExit = false } = {}) => {
  try { return execFileSync('git', args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }); }
  catch (e) { return diffExit && e.status === 1 && typeof e.stdout === 'string' ? e.stdout : null; }
};
const bail = (msg) => { console.error('floor-guard: ' + msg); process.exit(2); };

const top = git(['rev-parse', '--show-toplevel'])?.trim();
if (!top) bail('not inside a git work tree');
process.chdir(top);

const mergeBase = git(['merge-base', base, 'HEAD'])?.trim();
if (!mergeBase) bail('no merge base against ' + base);

const tracked = git(['diff', '--unified=0', mergeBase, '--']);
if (tracked === null) bail('could not diff against ' + mergeBase);
const untrackedFiles = git(['ls-files', '--others', '--exclude-standard']);
if (untrackedFiles === null) bail('could not list untracked files');
const untracked = untrackedFiles.split('\n').filter(Boolean).map((f) => {
  const d = git(['diff', '--no-index', '--unified=0', '/dev/null', f], { diffExit: true });
  if (d === null) bail('could not diff untracked file ' + f);
  return d;
}).join('\n');
const diff = tracked + '\n' + untracked;

const added = [], removed = [], deleted = [], changed = new Set();
const pathOf = (s) => s.replace(/^[ab]\//, '');
let file = '', oldFile = '', inHeader = false;
for (const line of diff.split('\n')) {
  if (line.startsWith('diff ')) inHeader = true;
  else if (line.startsWith('@@')) inHeader = false;
  else if (inHeader) {
    if (line.startsWith('--- ')) oldFile = pathOf(line.slice(4));
    else if (line.startsWith('+++ ')) {
      const newFile = pathOf(line.slice(4));
      file = newFile === '/dev/null' ? oldFile : newFile;
      if (newFile === '/dev/null') deleted.push(file);
      changed.add(file);
    }
  }
  else if (line.startsWith('+')) added.push({ file, text: line.slice(1) });
  else if (line.startsWith('-')) removed.push({ file, text: line.slice(1) });
}

const findings = [];
const flag = (rule, f, text) => findings.push({ rule, file: f, text: text.trim().slice(0, 120) });
const isTest = (f) => /\/src\/(test|androidTest)\//.test(f);
const isMainKotlin = (f) => /^app\/src\/main\/java\/.*\.kt$/.test(f);
const isUi = (f) => /^app\/src\/main\/java\/com\/example\/skeleton\/(ui|widget)\/.*\.kt$/.test(f);
const isConstraints = (f) => /(^|\/)CONSTRAINTS\.md$/.test(f);
const isGuard = (f) => /^scripts\/floor-guard\.mjs$/.test(f); // its own pattern literals
const isDoc = (f) => /\.md$/.test(f); // docs name the patterns; rules live in code

// 1. Silenced checker (Kotlin / Android / Kover / gitleaks forms).
const SUPPRESSIONS = /@Suppress\(|@file:Suppress|@SuppressLint|ktlint-disable|tools:ignore=|noinspection|gitleaks:allow|@ExcludeFromCoverage|kover\s*\{[^}]*exclud|baseline\s*=\s*file/;
// 4. Unfinished work.
const STUBS = /\bTODO\(|NotImplementedError|catch\s*\([^)]*\)\s*\{\s*\}|\bTODO\b|\bFIXME\b/;
// 2. A test made easier.
const SKIPS = /@Ignore\b|Assume\.|assumeTrue\(|assumeFalse\(/;

for (const { file, text } of added) {
  if (isGuard(file) || isDoc(file)) continue;
  if (SUPPRESSIONS.test(text)) flag('silenced-checker', file, text);
  if (STUBS.test(text)) flag('unfinished-work', file, text);
  if (SKIPS.test(text)) flag('test-made-easier', file, text);
}

for (const f of deleted) if (isTest(f)) flag('test-deleted', f, 'file deleted');
// A test file may be rewritten when behaviour changes, but must not end up with fewer assertion lines than it
// started with: replaced assertions pass, assertions deleted without a replacement are flagged.
const ASSERTION = /\b(assert\w*|expect\w*|verify\w*|should\w*|assertIs\w*)\b/;
const assertionsPerFile = (lines) => {
  const counts = new Map();
  for (const { file, text } of lines) {
    if (isTest(file) && !deleted.includes(file) && ASSERTION.test(text)) counts.set(file, (counts.get(file) ?? 0) + 1);
  }
  return counts;
};
const assertionsAdded = assertionsPerFile(added);
for (const [file, gone] of assertionsPerFile(removed)) {
  const came = assertionsAdded.get(file) ?? 0;
  if (came < gone) flag('assertion-removed', file, `${gone} assertion line(s) removed, only ${came} added`);
}

// P1. Commit authorship: the user is the only author. No Claude/tool attribution in any commit
// of this branch, and no Anthropic identity as author or committer.
const ATTRIBUTION = /co-authored-by:|generated with \[?claude|noreply@anthropic\.com/i;
const log = git(['log', '--format=%H%x1f%an <%ae>%x1f%cn <%ce>%x1f%B%x1e', `${mergeBase}..HEAD`]);
if (log === null) bail('could not read commit log');
for (const rec of log.split('\x1e').map((r) => r.trim()).filter(Boolean)) {
  const [sha, author, committer, body] = rec.split('\x1f');
  if (ATTRIBUTION.test(body ?? '')) flag('commit-attribution', sha.slice(0, 10), 'commit message carries an attribution trailer');
  if (/anthropic|claude/i.test(author) || /anthropic|claude/i.test(committer)) {
    flag('commit-author', sha.slice(0, 10), 'author/committer is not the user: ' + author);
  }
}

// P2. Test-first: production Kotlin changed with no test change in the same diff.
const mainChanged = [...changed].filter((f) => isMainKotlin(f) && !deleted.includes(f));
const testChanged = [...changed].some((f) => isTest(f) && !deleted.includes(f));
if (mainChanged.length > 0 && !testChanged) {
  for (const f of mainChanged) flag('no-test-for-change', f, 'production code changed without a test change');
}

// P3. Simulated review: UI changes must come with Roborazzi screenshot tests. Active once the
// screenshot suite exists, so the rule switches itself on.
const SCREENSHOT_DIR = 'app/src/test/java/com/example/skeleton/screenshots';
if (existsSync(SCREENSHOT_DIR)) {
  const uiChanged = [...changed].filter((f) => isUi(f) && !deleted.includes(f));
  const shotsChanged = [...changed].some((f) => f.startsWith(SCREENSHOT_DIR + '/'));
  if (uiChanged.length > 0 && !shotsChanged) {
    for (const f of uiChanged) flag('ui-without-screenshot', f, 'UI changed without a screenshot test change');
  }
}

// CONSTRAINTS.md weakened. Skipped when the file is being created (nothing to weaken yet).
const constraintsAtBase = git(['cat-file', '-e', `${mergeBase}:CONSTRAINTS.md`]) !== null;
if (constraintsAtBase) {
  for (const { file, text } of added) {
    if (isConstraints(file) && /^\| *(W|E)\d+ *\|/.test(text)) flag('new-exception', file, text);
  }
  const ruleKey = (t) => {
    const s = t.trim();
    if (s.startsWith('|')) return s.split('|').map((c) => c.trim()).filter(Boolean)[0] ?? '';
    if (/^[-*] /.test(s)) return s.slice(2).split(':')[0].trim();
    return null;
  };
  const isException = (t) => /^\| *(W|E)\d+ *\|/.test(t.trim());
  const MIN_BEFORE = /(>=|>|≥|at least|minimum|\bmin\b|no less than|not fall|not drop)\s*$/;
  const MAX_BEFORE = /(<=|<|≤|at most|maximum|\bmax\b|no more than|under|below|not grow|not exceed)\s*$/;
  const MIN_AFTER = /^\s*\S*\s*(?:\|\s*)?(or more|or higher|must not fall|must not drop)/;
  const MAX_AFTER = /^\s*\S*\s*(?:\|\s*)?(or less|or lower|must not grow|must not exceed)/;
  const thresholds = (t) => {
    const out = [], re = /\d+(?:\.\d+)?/g;
    let m;
    while ((m = re.exec(t))) {
      const before = t.slice(Math.max(0, m.index - 24), m.index).toLowerCase();
      const after = t.slice(m.index + m[0].length, m.index + m[0].length + 40).toLowerCase();
      const dir = MIN_BEFORE.test(before) || MIN_AFTER.test(after) ? 'min'
        : MAX_BEFORE.test(before) || MAX_AFTER.test(after) ? 'max' : null;
      out.push({ n: Number(m[0]), dir });
    }
    return out;
  };
  const removedRules = removed.filter((l) => isConstraints(l.file) && ruleKey(l.text) !== null);
  const addedRules = added.filter((l) => isConstraints(l.file) && ruleKey(l.text) !== null);
  for (const r of removedRules) {
    const a = addedRules.find((x) => ruleKey(x.text) === ruleKey(r.text));
    if (!a) {
      if (!isException(r.text)) flag('rule-removed', r.file, r.text);
      continue;
    }
    const before = thresholds(r.text), after = thresholds(a.text);
    let verdict = null;
    for (const dir of ['min', 'max', null]) {
      const was = before.filter((x) => x.dir === dir), now = after.filter((x) => x.dir === dir);
      was.forEach((b, i) => {
        const n = now[i];
        if (verdict) return;
        if (!n) verdict = 'threshold-removed';
        else if (n.n === b.n) return;
        else if (dir === 'min' ? n.n < b.n : dir === 'max' ? n.n > b.n : true) {
          verdict = dir ? 'threshold-loosened' : 'threshold-changed';
        }
      });
    }
    if (verdict) flag(verdict, r.file, r.text + '  ->  ' + a.text);
  }
}

if (findings.length === 0) { console.log('floor-guard: clean'); process.exit(0); }
console.error('floor-guard: ' + findings.length + ' floor violation(s):');
for (const f of findings) console.error(`  [${f.rule}] ${f.file}: ${f.text}`);
console.error('\nEach is a move that lowers the bar. Fix the code, or route it through a tracked exception.');
process.exit(1);
