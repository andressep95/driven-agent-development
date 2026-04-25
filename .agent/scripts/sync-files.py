#!/usr/bin/env python3
"""
Tracks non-Java file changes in memory.jsonl.
Called by post-commit hook for .md, .sh, .py, .yaml, .yml, .sql, .json files.
For SKILL.md files: extracts name/description from frontmatter.
For other files: records file-level change with path and kind.
"""
import json, sys, os, re, subprocess, argparse
from datetime import date

TRACKED_EXTENSIONS = {'.md', '.sh', '.py', '.yaml', '.yml', '.sql', '.json'}
FILE_TYPES_TO_KIND = {
    '.sh':   'script',
    '.py':   'script',
    '.yaml': 'config',
    '.yml':  'config',
    '.sql':  'config',
    '.json': 'config',
    '.md':   'doc',
}


def git_hash(path):
    r = subprocess.run(
        ['git', 'log', '--follow', '-1', '--format=%h', '--', path],
        capture_output=True, text=True
    )
    return r.stdout.strip() or 'unknown'


def git_date(path):
    r = subprocess.run(
        ['git', 'log', '--follow', '-1', '--format=%ad', '--date=format:%Y-%m-%d', '--', path],
        capture_output=True, text=True
    )
    return r.stdout.strip() or str(date.today())


def extract_skill_meta(path):
    try:
        with open(path) as f:
            content = f.read()
        name_m = re.search(r'^name:\s*(.+)$', content, re.MULTILINE)
        name = name_m.group(1).strip() if name_m else None

        # description can be multiline (>) or single line
        desc_block = re.search(r'^description:\s*>\s*\n((?:[ \t]+.+\n)+)', content, re.MULTILINE)
        if desc_block:
            desc = ' '.join(line.strip() for line in desc_block.group(1).strip().splitlines())
        else:
            desc_line = re.search(r'^description:\s*(.+)$', content, re.MULTILINE)
            desc = desc_line.group(1).strip() if desc_line else None

        return name, desc
    except Exception:
        return None, None


def extract_intent(path):
    """Extract a meaningful one-line intent from any file type."""
    ext = os.path.splitext(path)[1].lower()
    basename = os.path.basename(path)
    try:
        with open(path) as f:
            lines = [l.rstrip() for l in f.readlines()]

        if ext == '.sh':
            # First non-shebang comment line
            for line in lines:
                if line.startswith('#') and not line.startswith('#!'):
                    intent = line.lstrip('#').strip()
                    if intent:
                        return intent
            # Fallback: list function names
            fns = [re.match(r'^(\w+)\s*\(\)', l) for l in lines]
            names = [m.group(1) for m in fns if m]
            if names:
                return f"Shell script — functions: {', '.join(names[:5])}"

        elif ext == '.py':
            # Module docstring
            joined = '\n'.join(lines)
            doc = re.search(r'"""(.+?)"""', joined, re.DOTALL)
            if doc:
                first_line = doc.group(1).strip().splitlines()[0]
                return first_line
            # First comment
            for line in lines:
                if line.startswith('#') and not line.startswith('#!'):
                    intent = line.lstrip('#').strip()
                    if intent:
                        return intent

        elif ext == '.md':
            # First H1 or H2 heading
            for line in lines:
                if line.startswith('#'):
                    return line.lstrip('#').strip()

        elif ext in ('.yaml', '.yml'):
            # First comment or top-level key
            for line in lines:
                if line.startswith('#'):
                    intent = line.lstrip('#').strip()
                    if intent:
                        return intent
            for line in lines:
                if line and not line.startswith(' '):
                    return f"Config key: {line.split(':')[0].strip()}"

        elif ext == '.sql':
            for line in lines:
                if line.startswith('--'):
                    intent = line.lstrip('-').strip()
                    if intent:
                        return intent

    except Exception:
        pass

    return basename


def classify_file(path):
    basename = os.path.basename(path)
    ext = os.path.splitext(basename)[1].lower()

    if basename == 'SKILL.md':
        name, desc = extract_skill_meta(path)
        return 'skill', name or basename, desc or 'Agent skill definition'

    if basename == 'CLAUDE.md':
        return 'config', 'CLAUDE.md', 'Agent context and skill-driven protocol'

    kind = FILE_TYPES_TO_KIND.get(ext, 'file')
    intent = extract_intent(path)
    return kind, basename, intent


def should_track(path):
    ext = os.path.splitext(path)[1].lower()
    if ext not in TRACKED_EXTENSIONS:
        return False
    # skip memory files to avoid recursion
    if os.path.basename(path) in ('memory.jsonl', 'memory.db'):
        return False
    return True




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


NON_JAVA_TYPES = {'skill', 'file', 'doc', 'script', 'config'}


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--jsonl', required=True)
    p.add_argument('--added',    default='')
    p.add_argument('--deleted',  default='')
    p.add_argument('--modified', default='')
    args = p.parse_args()

    added    = [f for f in split_files(args.added)    if should_track(f)]
    deleted  = [f for f in split_files(args.deleted)  if should_track(f)]
    modified = [f for f in split_files(args.modified) if should_track(f)]

    if not (added or deleted or modified):
        return

    entries = load_jsonl(args.jsonl)
    dirty   = set(deleted + modified)

    # Keep Java symbols and decisions untouched; replace only non-Java file entries
    kept = [e for e in entries if not (e.get('type') in NON_JAVA_TYPES and e.get('file') in dirty)]

    stats = {'deleted': len(deleted), 'added': 0, 'updated': 0}

    for filepath in added + modified:
        if not os.path.exists(filepath):
            continue
        kind, symbol, intent = classify_file(filepath)
        commit = git_hash(filepath)
        ts     = git_date(filepath)

        kept.append({
            'type':   kind,
            'file':   filepath,
            'symbol': symbol,
            'kind':   kind,
            'intent': intent,
            'tags':   [],
            'commit': commit,
            'ts':     ts,
        })

        if filepath in added:
            stats['added'] += 1
        else:
            stats['updated'] += 1

    with open(args.jsonl, 'w') as f:
        for entry in kept:
            f.write(json.dumps(entry, ensure_ascii=False) + '\n')

    print(f"  [files] deleted={stats['deleted']} added={stats['added']} updated={stats['updated']}")


if __name__ == '__main__':
    main()
