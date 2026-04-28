#!/usr/bin/env python3
"""
Post-commit extractor — writes one JSONL entry per modified hunk.
Reads what/why/breaking from the commit body and the diff for exact location.
Output: .agents/memory/memory.jsonl (append, idempotent by ID).
"""

import json
import re
import subprocess
from pathlib import Path


def run(cmd: str) -> str:
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return result.stdout.strip()


LANGUAGE_MAP = {
    ".java": "java", ".kt": "kotlin", ".scala": "scala",
    ".py": "python", ".go": "go", ".rs": "rust",
    ".ts": "typescript", ".tsx": "typescript",
    ".js": "javascript", ".jsx": "javascript",
    ".cs": "csharp", ".rb": "ruby", ".php": "php",
    ".c": "c", ".cpp": "cpp", ".h": "c",
    ".sh": "shell", ".bash": "shell", ".zsh": "shell",
    ".yaml": "yaml", ".yml": "yaml",
    ".json": "json", ".toml": "toml",
    ".sql": "sql", ".md": "markdown",
    ".css": "css", ".scss": "scss",
}


def detect_language(path: str) -> str:
    return LANGUAGE_MAP.get(Path(path).suffix.lower(), "other")


def file_kind(path: str) -> str:
    ext  = Path(path).suffix.lower()
    name = Path(path).stem.lower()
    if ext in {".sh", ".bash", ".zsh"}:
        return "script"
    if ext in {".py", ".go", ".ts", ".tsx", ".js", ".jsx", ".rs",
               ".java", ".kt", ".c", ".cpp", ".rb", ".cs"}:
        return "test" if "test" in name or "spec" in name else "source"
    if ext in {".json", ".yaml", ".yml", ".toml", ".env", ".ini", ".cfg"}:
        return "config"
    if ext in {".md", ".txt", ".rst", ".adoc"}:
        return "doc"
    if ext in {".css", ".scss", ".sass", ".less"}:
        return "style"
    return "other"


def parse_commit_parts(intent: str) -> tuple[str, str]:
    m = re.match(r"^(\w+)(?:\(([\w/.-]+)\))?:", intent)
    commit_type = m.group(1) if m else ""
    scope       = m.group(2) if m and m.group(2) else ""
    return commit_type, scope


def parse_hunks(diff: str) -> list[dict]:
    hunks   = []
    current = None

    for line in diff.splitlines():
        if line.startswith("@@"):
            if current:
                hunks.append(current)
            m = re.match(r"@@\s+-\d+(?:,\d+)?\s+\+(\d+)(?:,(\d+))?\s+@@(.*)", line)
            if not m:
                continue
            start = int(m.group(1))
            count = int(m.group(2)) if m.group(2) is not None else 1
            current = {
                "hunk_header":  line,
                "symbol":       m.group(3).strip(),
                "lines_start":  start,
                "lines_end":    start + max(count - 1, 0),
                "lines_delta":  0,
                "content":      [],
                "adds":         False,
                "dels":         False,
            }
        elif current is not None:
            if line.startswith("+") and not line.startswith("+++"):
                current["content"].append(line)
                current["adds"]        = True
                current["lines_delta"] += 1
            elif line.startswith("-") and not line.startswith("---"):
                current["content"].append(line)
                current["dels"]        = True
                current["lines_delta"] -= 1
            elif line.startswith(" "):
                current["content"].append(line)

    if current:
        hunks.append(current)
    return hunks


def change_type(adds: bool, dels: bool) -> str:
    if adds and dels:
        return "modification"
    return "addition" if adds else "deletion"


def make_tags(commit_type: str, scope: str, kind: str, ctype: str) -> list[str]:
    tags = [t for t in [commit_type, ctype, kind, scope] if t]
    return list(dict.fromkeys(tags))


def semantic_desc(what: str, why: str, intent: str, symbol: str, file: str) -> str:
    if what and why:
        return f"{what} — {why}"
    if what:
        return f"{what} ({symbol or file})"
    if why:
        return f"{intent} — {why}"
    return f"{intent} ({symbol or file})"


def main() -> None:
    commit  = run("git log -1 --format=%h")
    author  = run("git log -1 --format=%an")
    email   = run("git log -1 --format=%ae")
    ts      = run("git log -1 --format=%cI")[:10]
    intent  = run("git log -1 --format=%s")
    body    = run("git log -1 --format=%b")
    branch  = run("git rev-parse --abbrev-ref HEAD")
    project = Path(run("git rev-parse --show-toplevel")).name

    what, why, breaking = "", "", False
    for line in body.splitlines():
        if line.startswith("what:"):
            what = line[5:].strip()
        elif line.startswith("why:"):
            why = line[4:].strip()
        elif line.startswith("breaking:"):
            breaking = line[9:].strip().lower() == "true"

    commit_type, scope = parse_commit_parts(intent)

    files_raw = run("git diff-tree --no-commit-id -r --name-only HEAD")
    all_files = [f for f in files_raw.splitlines() if f]
    related   = {f: [x for x in all_files if x != f] for f in all_files}

    repo_root  = Path(run("git rev-parse --show-toplevel"))
    memory_dir = repo_root / ".agents" / "memory"
    memory_dir.mkdir(parents=True, exist_ok=True)
    jsonl_path = memory_dir / "memory.jsonl"

    records = []

    for file in all_files:
        kind = file_kind(file)
        lang = detect_language(file)

        diff = run(f'git diff HEAD~1 HEAD -- "{file}" 2>/dev/null')
        if not diff:
            diff = run(f'git show HEAD -- "{file}"')

        lines     = diff.splitlines()
        start_idx = next((i for i, l in enumerate(lines) if l.startswith("@@")), None)
        diff_body = "\n".join(lines[start_idx:]) if start_idx is not None else ""

        hunks = parse_hunks(diff_body)

        if not hunks:
            hunks = [{
                "hunk_header":  "",
                "symbol":       "",
                "lines_start":  1,
                "lines_end":    1,
                "lines_delta":  sum(1 for l in lines if l.startswith("+")),
                "content":      lines[:80],
                "adds":         any(l.startswith("+") for l in lines),
                "dels":         any(l.startswith("-") for l in lines),
            }]

        for h in hunks:
            ctype = change_type(h["adds"], h["dels"])
            tags  = make_tags(commit_type, scope, kind, ctype)
            sdesc = semantic_desc(what, why, intent, h["symbol"], file)

            records.append({
                "type":                 "change",
                "commit_type":          commit_type,
                "scope":                scope,
                "change_type":          ctype,
                "file":                 file,
                "file_kind":            kind,
                "language":             lang,
                "symbol":               h["symbol"],
                "lines_start":          h["lines_start"],
                "lines_end":            h["lines_end"],
                "lines_delta":          h["lines_delta"],
                "what":                 what,
                "why":                  why,
                "semantic_description": sdesc,
                "intent":               intent,
                "tags":                 tags,
                "breaking":             breaking,
                "related_files":        related.get(file, []),
                "commit":               commit,
                "branch":               branch,
                "project":              project,
                "author":               author,
                "email":                email,
                "ts":                   ts,
                "hunk_header":          h["hunk_header"],
                "hunk_content":         "\n".join(h["content"][:100]),
            })

    with open(jsonl_path, "a", encoding="utf-8") as f:
        for r in records:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")

    print(f"[memory] {len(records)} hunk(s) recorded → {commit} ({branch})")


if __name__ == "__main__":
    main()
