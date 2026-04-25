#!/usr/bin/env python3
"""
Hunk-level change tracker. Each diff hunk becomes one record in memory.jsonl.
Handles all tracked file types: .java, .md, .sh, .py, .yaml, .yml, .sql, .json.
Records are append-only — history is never rewritten.
"""
import json, sys, os, re, subprocess, argparse
from datetime import date

TRACKED_EXTENSIONS = {'.java', '.md', '.sh', '.py', '.yaml', '.yml', '.sql', '.json'}
SKIP_FILES = {'memory.jsonl', 'memory.db'}


# ── git helpers ───────────────────────────────────────────────────────────────

def git_commit_info(commit_ref):
    """Return (short_hash, message, date, author, email) for a specific commit ref."""
    try:
        def log(fmt, *extra):
            return subprocess.run(
                ['git', 'log', '-1', fmt] + list(extra) + [commit_ref],
                capture_output=True, text=True
            ).stdout.strip()

        short_hash = subprocess.run(
            ['git', 'rev-parse', '--short', commit_ref],
            capture_output=True, text=True
        ).stdout.strip() or 'unknown'

        return (
            short_hash,
            log('--format=%s'),
            log('--format=%ad', '--date=format:%Y-%m-%d') or str(date.today()),
            log('--format=%an') or 'unknown',
            log('--format=%ae') or 'unknown',
        )
    except Exception:
        return 'unknown', '', str(date.today()), 'unknown', 'unknown'


# ── diff parsing ──────────────────────────────────────────────────────────────

def parse_diff_hunks(filepath, from_commit, to_commit):
    """Parse git diff --unified=0 between two commits into structured hunk objects."""
    r = subprocess.run(
        ['git', 'diff', '--unified=0', from_commit, to_commit, '--', filepath],
        capture_output=True, text=True
    )
    if not r.stdout:
        return []

    hunks, current = [], None
    for line in r.stdout.splitlines():
        m = re.match(r'^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@', line)
        if m:
            if current:
                hunks.append(current)
            old_count = int(m.group(2)) if m.group(2) is not None else 1
            new_start = int(m.group(3))
            new_count = int(m.group(4)) if m.group(4) is not None else 1
            delta     = new_count - old_count

            if old_count == 0:
                change_type = 'addition'
            elif new_count == 0:
                change_type = 'deletion'
            else:
                change_type = 'modification'

            current = {
                'hunk_header': line,
                'hunk_content': '',
                'lines_start': new_start,
                'lines_end':   new_start + max(new_count - 1, 0),
                'lines_delta': delta,
                'change_type': change_type,
                'added':   [],
                'removed': [],
            }
        elif current is not None:
            if line.startswith('+') and not line.startswith('+++'):
                current['added'].append(line[1:].strip())
                current['hunk_content'] += line + '\n'
            elif line.startswith('-') and not line.startswith('---'):
                current['removed'].append(line[1:].strip())
                current['hunk_content'] += line + '\n'

    if current:
        hunks.append(current)
    return hunks


# ── classification helpers ────────────────────────────────────────────────────

def file_kind(filepath):
    ext      = os.path.splitext(filepath)[1].lower()
    basename = os.path.basename(filepath)
    if ext == '.java':                                    return 'java'
    if basename == 'SKILL.md':                           return 'skill'
    if basename in ('CLAUDE.md',):                       return 'config'
    if ext in ('.yaml', '.yml', '.sql', '.json'):        return 'config'
    if ext in ('.sh', '.py'):                            return 'script'
    if ext == '.md':                                     return 'doc'
    return 'file'


def extract_symbol(filepath, hunk):
    """Pull a meaningful label from hunk context or file metadata."""
    basename = os.path.basename(filepath)
    ext      = os.path.splitext(filepath)[1].lower()

    if basename == 'SKILL.md':
        try:
            with open(filepath) as f:
                content = f.read()
            m = re.search(r'^name:\s*(.+)$', content, re.MULTILINE)
            return m.group(1).strip() if m else basename
        except Exception:
            return basename

    if ext == '.java':
        return os.path.splitext(basename)[0]

    candidates = hunk.get('added') or hunk.get('removed') or []
    for line in candidates:
        if line.startswith('#') and not line.startswith('#!'):
            text = line.lstrip('#').strip()
            if text:
                return text[:72]
        fn = re.match(r'^(\w[\w_]+)\s*\(\)|^def (\w+)|^class (\w+)|^function (\w+)', line)
        if fn:
            return next(g for g in fn.groups() if g)

    return basename


def derive_tags(filepath, change_type, commit_msg):
    tags = set()
    tags.add(file_kind(filepath))
    tags.add(change_type)

    m = re.match(r'^(feat|fix|refactor|sec|perf|chore|docs|test|ci)\b', commit_msg)
    if m:
        tags.add(m.group(1))

    for part in filepath.replace('\\', '/').split('/')[:-1]:
        if part and part not in {'.', '..', 'src', 'main', 'java', 'assets', 'scripts'}:
            tags.add(part)

    return sorted(tags)


# ── helpers ───────────────────────────────────────────────────────────────────

def should_track(filepath, all_files=False):
    if os.path.basename(filepath) in SKIP_FILES:
        return False
    if all_files:
        return True
    ext = os.path.splitext(filepath)[1].lower()
    return ext in TRACKED_EXTENSIONS


def split_files(raw):
    return [f.strip() for f in (raw or '').split('\n') if f.strip()]


def load_jsonl(path):
    entries = []
    if not os.path.exists(path):
        return entries
    with open(path) as f:
        for raw in f:
            raw = raw.strip()
            if raw:
                try:
                    entries.append(json.loads(raw))
                except json.JSONDecodeError:
                    pass
    return entries


# ── main ──────────────────────────────────────────────────────────────────────

def main():
    p = argparse.ArgumentParser()
    p.add_argument('--jsonl',        required=True)
    p.add_argument('--added',        default='')
    p.add_argument('--deleted',      default='')
    p.add_argument('--modified',     default='')
    p.add_argument('--from-commit',  default='HEAD~1',
                   help='Base commit for diff (default: HEAD~1)')
    p.add_argument('--to-commit',    default='HEAD',
                   help='Target commit for diff (default: HEAD)')
    p.add_argument('--all-files',    action='store_true',
                   help='Track every file type, not just TRACKED_EXTENSIONS')
    args = p.parse_args()

    added    = [f for f in split_files(args.added)    if should_track(f, args.all_files)]
    deleted  = [f for f in split_files(args.deleted)  if should_track(f, args.all_files)]
    modified = [f for f in split_files(args.modified) if should_track(f, args.all_files)]

    if not (added or deleted or modified):
        return

    commit, commit_msg, ts, author, email = git_commit_info(args.to_commit)

    existing = load_jsonl(args.jsonl)

    # Dedup: skip records already tracked for this (commit, file, hunk_header)
    existing_keys = {
        (e.get('commit'), e.get('file'), e.get('hunk_header'))
        for e in existing
        if e.get('type') == 'change'
    }

    new_records = []
    stats = {'files': 0, 'hunks': 0}

    for filepath in added + modified:
        hunks = parse_diff_hunks(filepath, args.from_commit, args.to_commit)
        if not hunks:
            continue
        stats['files'] += 1
        kind = file_kind(filepath)
        for hunk in hunks:
            key = (commit, filepath, hunk['hunk_header'])
            if key in existing_keys:
                continue
            new_records.append({
                'type':         'change',
                'change_type':  hunk['change_type'],
                'file':         filepath,
                'file_kind':    kind,
                'symbol':       extract_symbol(filepath, hunk),
                'hunk_header':  hunk['hunk_header'],
                'hunk_content': hunk['hunk_content'].strip(),
                'lines_start':  hunk['lines_start'],
                'lines_end':    hunk['lines_end'],
                'lines_delta':  hunk['lines_delta'],
                'intent':       commit_msg,
                'tags':         derive_tags(filepath, hunk['change_type'], commit_msg),
                'commit':       commit,
                'author':       author,
                'email':        email,
                'ts':           ts,
            })
            stats['hunks'] += 1

    for filepath in deleted:
        key = (commit, filepath, '')
        if key in existing_keys:
            continue
        new_records.append({
            'type':         'change',
            'change_type':  'deletion',
            'file':         filepath,
            'file_kind':    file_kind(filepath),
            'symbol':       os.path.basename(filepath),
            'hunk_header':  '',
            'hunk_content': '',
            'lines_start':  0,
            'lines_end':    0,
            'lines_delta':  0,
            'intent':       commit_msg,
            'tags':         derive_tags(filepath, 'deletion', commit_msg),
            'commit':       commit,
            'author':       author,
            'email':        email,
            'ts':           ts,
        })
        stats['hunks'] += 1

    if not new_records:
        return

    # Append only — history is never rewritten
    with open(args.jsonl, 'w') as f:
        for entry in existing + new_records:
            f.write(json.dumps(entry, ensure_ascii=False) + '\n')

    print(f"  [hunks] files={stats['files']} hunks={stats['hunks']}")


if __name__ == '__main__':
    main()
