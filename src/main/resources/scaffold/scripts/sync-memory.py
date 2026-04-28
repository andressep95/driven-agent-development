#!/usr/bin/env python3
"""
Syncs memory.jsonl after a git commit using line-level diff precision.

For each modified file:
  - Parses git diff --unified=0 to get changed hunks (new_start, new_end, delta)
  - For each symbol in memory.jsonl:
      overlap with hunk  -> code changed: find new location, update commit/ts
      below a hunk       -> line numbers shifted: apply cumulative delta silently
      above all hunks    -> untouched: no change
"""
import json, sys, os, re, subprocess, argparse
from datetime import date


# -- git helpers ---------------------------------------------------------------

def git_file_hash(path):
    r = subprocess.run(
        ["git", "log", "--follow", "-1", "--format=%h", "--", path],
        capture_output=True, text=True
    )
    return r.stdout.strip() or "unknown"


def git_file_date(path):
    r = subprocess.run(
        ["git", "log", "--follow", "-1", "--format=%ad", "--date=format:%Y-%m-%d", "--", path],
        capture_output=True, text=True
    )
    return r.stdout.strip() or str(date.today())


def parse_hunks(filepath):
    r = subprocess.run(
        ["git", "diff", "--unified=0", "HEAD~1", "HEAD", "--", filepath],
        capture_output=True, text=True
    )
    hunks = []
    for line in r.stdout.splitlines():
        m = re.match(r'^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@', line)
        if not m:
            continue
        old_count = int(m.group(2)) if m.group(2) is not None else 1
        new_start = int(m.group(3))
        new_count = int(m.group(4)) if m.group(4) is not None else 1
        delta     = new_count - old_count
        new_end   = new_start + max(new_count - 1, 0)
        hunks.append({"start": new_start, "end": new_end, "delta": delta})
    return hunks


# -- line arithmetic -----------------------------------------------------------

def classify_symbol(sym_start, sym_end, hunks):
    for hunk in hunks:
        if sym_start <= hunk["end"] and sym_end >= hunk["start"]:
            return sym_start, sym_end, True
    delta = sum(h["delta"] for h in hunks if h["start"] < sym_start)
    return sym_start + delta, sym_end + delta, False


def find_symbol_line(filepath, symbol_name):
    if not os.path.exists(filepath):
        return None
    pattern = re.compile(
        r'(?:public\s+)?(?:class|interface|enum|record)\s+' + re.escape(symbol_name) + r'\b'
        r'|(?:public\s+[\w<>\[\]]+\s+)' + re.escape(symbol_name) + r'\s*\('
    )
    with open(filepath) as f:
        for i, line in enumerate(f, 1):
            if pattern.search(line):
                return i
    return None


# -- new-file scanner ----------------------------------------------------------

def scan_classes(path):
    if not os.path.exists(path):
        return []
    with open(path) as f:
        lines = f.readlines()
    total = len(lines)
    results = []
    for i, line in enumerate(lines):
        m = re.match(r'\s*public (?:class|interface|enum|record) (\w+)', line)
        if not m:
            continue
        name = m.group(1)
        anns = [lines[j].strip() for j in range(max(0, i - 3), i) if lines[j].strip().startswith("@")]
        ann  = " ".join(anns)
        if   "@RestController" in ann:                   kind = "controller"
        elif "@Service" in ann:                          kind = "service"
        elif "@Repository" in ann:                       kind = "repository"
        elif "@Configuration" in ann or "@ConfigurationProperties" in ann: kind = "config"
        elif "/dto/" in path:                            kind = "dto"
        elif "/domain/" in path:                         kind = "domain"
        else:                                            kind = "class"
        results.append({"name": name, "kind": kind, "line_start": i + 1, "line_end": total})
    return results


# -- helpers -------------------------------------------------------------------

def split_files(raw):
    return [f.strip() for f in (raw or "").split("\n") if f.strip()]


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


# -- main ----------------------------------------------------------------------

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--jsonl",     required=True)
    p.add_argument("--added",     default="")
    p.add_argument("--deleted",   default="")
    p.add_argument("--modified",  default="")
    args = p.parse_args()

    added    = split_files(args.added)
    deleted  = split_files(args.deleted)
    modified = split_files(args.modified)
    dirty    = set(deleted + modified)

    entries = load_jsonl(args.jsonl)
    kept      = [e for e in entries if e.get("file") not in dirty]
    to_update = [e for e in entries if e.get("file") in dirty]

    stats = {"deleted": 0, "shifted": 0, "touched": 0, "added": 0, "pending": 0}

    stats["deleted"] = sum(1 for e in to_update if e.get("file") in set(deleted))

    for filepath in modified:
        file_entries = [e for e in to_update if e.get("file") == filepath and e.get("type") == "symbol"]
        if not file_entries:
            continue

        commit = git_file_hash(filepath)
        ts     = git_file_date(filepath)
        hunks  = parse_hunks(filepath)

        if not hunks:
            for e in file_entries:
                e["commit"] = commit
                e["ts"]     = ts
                kept.append(e)
            continue

        for entry in file_entries:
            s, e_end = entry["lines"][0], entry["lines"][1]
            new_s, new_e, touched = classify_symbol(s, e_end, hunks)

            if not touched:
                entry["lines"]  = [new_s, new_e]
                entry["commit"] = commit
                entry["ts"]     = ts
                kept.append(entry)
                stats["shifted"] += 1
            else:
                new_line = find_symbol_line(filepath, entry["symbol"])
                if new_line:
                    total = sum(1 for _ in open(filepath))
                    entry["lines"]  = [new_line, min(new_line + (e_end - s), total)]
                    entry["commit"] = commit
                    entry["ts"]     = ts
                else:
                    entry["intent"] = "PENDING_INTENT -- symbol may have been renamed or deleted"
                    entry["commit"] = commit
                    entry["ts"]     = ts
                    stats["pending"] += 1
                kept.append(entry)
                stats["touched"] += 1

    for filepath in added:
        if not os.path.exists(filepath):
            continue
        commit = git_file_hash(filepath)
        ts     = git_file_date(filepath)
        for sym in scan_classes(filepath):
            kept.append({
                "type": "symbol", "file": filepath,
                "symbol": sym["name"], "kind": sym["kind"],
                "lines": [sym["line_start"], sym["line_end"]],
                "intent": "PENDING_INTENT -- run /scan-memory to generate",
                "tags": [], "commit": commit, "ts": ts
            })
            stats["added"]   += 1
            stats["pending"] += 1

    with open(args.jsonl, "w") as f:
        for entry in kept:
            f.write(json.dumps(entry, ensure_ascii=False) + "\n")

    print(f"  deleted={stats['deleted']} shifted={stats['shifted']} "
          f"touched={stats['touched']} added={stats['added']} pending={stats['pending']}")
    if stats["pending"]:
        print("  hint: run /scan-memory to fill PENDING_INTENT entries")


if __name__ == "__main__":
    main()
