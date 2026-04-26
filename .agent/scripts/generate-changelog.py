#!/usr/bin/env python3
"""
Regenerates CHANGELOG.md from the full git history or .agent/memory.jsonl.

Format: each commit gets its own ## [hash] - date section.
Within each section, files are grouped by what happened to them:
  ### Added    — new files in this commit
  ### Changed  — modified files
  ### Removed  — deleted files

Usage:
  python3 .agent/scripts/generate-changelog.py                 # from git + jsonl enrichment
  python3 .agent/scripts/generate-changelog.py --from-jsonl    # jsonl as commit source
  python3 .agent/scripts/generate-changelog.py --from-jsonl path.jsonl
  python3 .agent/scripts/generate-changelog.py --no-enrich     # skip file detail
  python3 .agent/scripts/generate-changelog.py --dry-run
  python3 .agent/scripts/generate-changelog.py --output path/CHANGELOG.md
"""
import re, json, os, subprocess, argparse, sys
from collections import defaultdict, OrderedDict

ROOT      = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
CHANGELOG = os.path.join(ROOT, 'CHANGELOG.md')
JSONL     = os.path.join(ROOT, '.agent', 'memory.jsonl')

CHANGE_TYPE_SECTION = {
    'addition':    'Added',
    'modification': 'Changed',
    'deletion':    'Removed',
}

SECTION_ORDER = ['Added', 'Changed', 'Removed']

SKIP_TYPES = {'chore', 'ci', 'test', 'docs', 'style', 'build', 'wip', 'merge', 'bump'}

MAX_FILES = 20  # max files listed per section per commit


# ── git helpers ───────────────────────────────────────────────────────────────

def git(*args):
    return subprocess.run(list(args), capture_output=True, text=True, cwd=ROOT).stdout


def parse_subject(subject):
    """Parse conventional commit → (type, scope, description, is_breaking)."""
    m = re.match(r'^(\w+)(?:\(([^)]+)\))?(!)?:\s*(.+)$', subject.strip())
    if m:
        ctype, scope, bang, desc = m.groups()
        return ctype.lower(), (scope or ''), desc.strip(), bool(bang)
    return None, '', subject.strip(), False


# ── commit sources ────────────────────────────────────────────────────────────

def commits_from_git():
    """
    Yield (full_hash, short_hash, subject, date, body) oldest → newest.
    Uses <COMMIT> as record delimiter and \x1f as field separator.
    """
    raw = git('git', 'log', '--reverse',
              '--format=<COMMIT>%H%x1f%h%x1f%s%x1f%ad%x1f%b',
              '--date=format:%Y-%m-%d')

    for block in raw.split('<COMMIT>'):
        block = block.strip()
        if not block:
            continue
        parts = block.split('\x1f', 4)
        if len(parts) < 4:
            continue
        full_hash  = parts[0].strip()
        short_hash = parts[1].strip()
        subject    = parts[2].strip()
        date       = parts[3].strip()
        body       = parts[4].strip() if len(parts) == 5 else ''
        body       = re.sub(r'<COMMIT>.*', '', body, flags=re.DOTALL).strip()
        # Strip co-author / sign-off lines
        body_lines = [
            ln for ln in body.splitlines()
            if ln.strip() and not re.match(r'^(Co-Authored-By|Signed-off-by|Co-authored):', ln, re.I)
        ]
        body = '\n'.join(body_lines)
        if full_hash and short_hash and subject:
            yield (full_hash, short_hash, subject, date, body)


def commits_from_jsonl(path):
    """
    Yield (full_hash, short_hash, subject, date, body) from memory.jsonl.
    Deduped by short_hash, sorted by date ascending.
    """
    seen = {}
    with open(path) as f:
        for raw in f:
            raw = raw.strip()
            if not raw:
                continue
            try:
                e = json.loads(raw)
            except json.JSONDecodeError:
                continue
            if e.get('type') != 'change':
                continue
            h = (e.get('commit') or '').strip()
            if h and h not in seen:
                seen[h] = (h, h, (e.get('intent') or '').strip(), (e.get('ts') or ''), '')

    return sorted(seen.values(), key=lambda x: x[3])


# ── jsonl enrichment ──────────────────────────────────────────────────────────

def load_hunk_index(jsonl_path):
    """
    Build {short_hash: {change_type: [(file, symbol)]}} from memory.jsonl.
    Deduped per (file, change_type) pair per commit.
    """
    index = defaultdict(lambda: defaultdict(list))
    seen_keys = defaultdict(set)

    if not os.path.exists(jsonl_path):
        return index

    with open(jsonl_path) as f:
        for raw in f:
            raw = raw.strip()
            if not raw:
                continue
            try:
                e = json.loads(raw)
            except json.JSONDecodeError:
                continue
            if e.get('type') != 'change':
                continue
            h      = (e.get('commit') or '').strip()
            fpath  = (e.get('file') or '').strip()
            symbol = (e.get('symbol') or '').strip()
            ctype  = (e.get('change_type') or 'modification').strip()
            if not h or not fpath:
                continue
            key = (fpath, ctype)
            if key not in seen_keys[h]:
                seen_keys[h].add(key)
                index[h][ctype].append((fpath, symbol))

    return index


# ── version tagging ───────────────────────────────────────────────────────────

def tags_by_hash():
    """Return {full_commit_hash: tag_name}."""
    raw = git('git', 'tag', '-l', '--sort=version:refname').strip()
    result = {}
    for tag in raw.splitlines():
        tag = tag.strip()
        if not tag:
            continue
        h = git('git', 'rev-list', '-n', '1', tag).strip()
        if h:
            result[h] = tag
    return result


# ── bucketing ─────────────────────────────────────────────────────────────────

def bucket_commits(commits_iterable, tag_map):
    """
    Assign commits to version buckets (git tags or Unreleased).
    Returns OrderedDict {version_label: {'date': str, 'commits': [commit_dict]}}
    where commit_dict = {short_hash, date, subject, body, full_hash}
    Order: Unreleased first, then released versions newest → oldest.
    """
    commits = list(commits_iterable)

    tag_at = {}
    for i, c in enumerate(commits):
        if c[0] in tag_map:
            tag_at[i] = (tag_map[c[0]], c[3])

    tag_indices = sorted(tag_at.keys())

    def version_for(i):
        for ti in tag_indices:
            if i <= ti:
                return tag_at[ti]
        return ('Unreleased', '')

    raw_buckets = {}

    for i, (full, short, subj, date, body) in enumerate(commits):
        version, vdate = version_for(i)
        if version not in raw_buckets:
            raw_buckets[version] = {'date': vdate, 'commits': []}
        raw_buckets[version]['commits'].append({
            'full_hash':  full,
            'short_hash': short,
            'subject':    subj,
            'date':       date,
            'body':       body,
        })

    ordered = OrderedDict()
    if 'Unreleased' in raw_buckets:
        ordered['Unreleased'] = raw_buckets.pop('Unreleased')
    else:
        ordered['Unreleased'] = {'date': '', 'commits': []}

    for v in reversed(list(raw_buckets.keys())):
        ordered[v] = raw_buckets[v]

    return ordered


# ── render ────────────────────────────────────────────────────────────────────

def render_file_line(fpath, symbol):
    """Format one file entry with optional symbol description."""
    sym_text = ''
    if symbol and symbol != os.path.basename(fpath):
        sym = symbol if len(symbol) <= 72 else symbol[:69] + '...'
        sym_text = f' — {sym}'
    return f'- `{fpath}`{sym_text}'


def render_commit(commit, hunk_index, enrich):
    """Render a single commit block as a list of markdown lines."""
    short  = commit['short_hash']
    date   = commit['date']
    subj   = commit['subject']
    body   = commit['body']

    lines = []
    lines.append(f'### [{short}] — {date}')
    lines.append('')
    lines.append(f'**{subj}**')
    lines.append('')

    # Body paragraphs
    if body:
        for ln in body.splitlines()[:4]:
            if ln.strip():
                lines.append(f'> {ln.strip()}')
        lines.append('')

    # File sections from jsonl enrichment
    if enrich and short in hunk_index:
        hunks_by_type = hunk_index[short]
        has_files = False

        for ctype, section_name in [
            ('addition',     'Added'),
            ('modification', 'Changed'),
            ('deletion',     'Removed'),
        ]:
            file_list = hunks_by_type.get(ctype, [])
            if not file_list:
                continue
            has_files = True
            lines.append(f'#### {section_name}')
            lines.append('')
            for fpath, symbol in file_list[:MAX_FILES]:
                lines.append(render_file_line(fpath, symbol))
            if len(file_list) > MAX_FILES:
                lines.append(f'- _…and {len(file_list) - MAX_FILES} more_')
            lines.append('')

        if not has_files:
            lines.append('_No file detail available in memory.jsonl._')
            lines.append('')
    else:
        lines.append('_Run with jsonl enrichment for file-level detail._')
        lines.append('')

    return lines


def render(buckets, hunk_index, enrich):
    out = [
        '# Changelog',
        '',
        'All notable changes to this project will be documented in this file.',
        '',
        'The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).',
        '',
    ]

    for version, data in buckets.items():
        commits = data['commits']

        # Version header
        if version == 'Unreleased':
            out.append('## [Unreleased]')
        else:
            out.append(f'## [{version}] - {data["date"]}')
        out.append('')

        if not commits:
            out.append('_No commits yet._')
            out.append('')
            out.append('---')
            out.append('')
            continue

        # Commits newest → oldest within the version bucket
        for commit in reversed(commits):
            ctype, scope, desc, breaking = parse_subject(commit['subject'])
            if ctype in SKIP_TYPES:
                continue
            out.extend(render_commit(commit, hunk_index, enrich))
            out.append('---')
            out.append('')

    return '\n'.join(out).rstrip() + '\n'


# ── main ──────────────────────────────────────────────────────────────────────

def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--from-jsonl', metavar='PATH', nargs='?', const=JSONL,
                   help='Use memory.jsonl as commit source instead of git history')
    p.add_argument('--no-enrich', action='store_true',
                   help='Skip file-level detail from memory.jsonl')
    p.add_argument('--output', default=CHANGELOG,
                   help='Output path (default: CHANGELOG.md at project root)')
    p.add_argument('--dry-run', action='store_true',
                   help='Print generated content without writing the file')
    args = p.parse_args()

    print('=== Changelog Generator ===')

    if args.from_jsonl:
        src = args.from_jsonl
        if not os.path.exists(src):
            print(f'ERROR: {src} not found. Run scan-memory first.', file=sys.stderr)
            sys.exit(1)
        print(f'Source  : memory.jsonl ({src})')
        commits = commits_from_jsonl(src)
        jsonl_for_enrich = src
        try:
            tag_map = tags_by_hash()
        except Exception:
            tag_map = {}
    else:
        print('Source  : git history')
        commits = commits_from_git()
        jsonl_for_enrich = JSONL
        try:
            tag_map = tags_by_hash()
        except Exception:
            tag_map = {}

    enrich = not args.no_enrich
    hunk_index = load_hunk_index(jsonl_for_enrich) if enrich else {}

    if enrich and hunk_index:
        print(f'Enrich  : memory.jsonl ({len(hunk_index)} commits indexed)')
    elif enrich:
        print('Enrich  : memory.jsonl not found — file detail skipped')

    buckets = bucket_commits(commits, tag_map)

    total_commits = sum(len(b['commits']) for b in buckets.values())
    versions = [v for v in buckets if v != 'Unreleased']
    print(f'Buckets : {len(buckets)} ({len(versions)} released + Unreleased)')
    print(f'Commits : {total_commits}')

    content = render(buckets, hunk_index, enrich)

    if args.dry_run:
        print('\n' + '─' * 60)
        print(content)
        return

    with open(args.output, 'w') as f:
        f.write(content)
    print(f'Written : {args.output}')
    print('=== Done ===')


if __name__ == '__main__':
    main()
