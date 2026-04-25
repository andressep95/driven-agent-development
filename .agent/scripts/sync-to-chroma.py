#!/usr/bin/env python3
import json, sys, os, argparse
try:
    import chromadb
except ImportError:
    print("ERROR: chromadb not installed. Run: pip install chromadb")
    sys.exit(1)

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

def get_author_from_git():
    import subprocess
    try:
        r = subprocess.run(["git", "config", "user.name"], capture_output=True, text=True)
        author = r.stdout.strip() or "unknown"
        r = subprocess.run(["git", "config", "user.email"], capture_output=True, text=True)
        email = r.stdout.strip() or "unknown"
        return author, email
    except Exception:
        return "unknown", "unknown"

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--jsonl", default=".agent/memory.jsonl")
    p.add_argument("--url", default="http://localhost:8000")
    p.add_argument("--collection", default="codebase")
    args = p.parse_args()

    author, email = get_author_from_git()
    entries = load_jsonl(args.jsonl)

    if not entries:
        print("No entries in memory.jsonl")
        sys.exit(1)

    client = chromadb.HttpClient(host=args.url.replace("http://", "").split(":")[0],
                             port=args.url.split(":")[-1] if ":" in args.url else "8000")
    collection = client.get_or_create_collection(args.collection)

    ids, documents, metadatas = [], [], []
    for e in entries:
        entry_id = f"{e.get('file', '')}:{e.get('symbol', '')}"
        intent = e.get('intent', '')
        tags = e.get('tags', [])
        kind = e.get('kind', '')
        lines = e.get('lines', [0, 0])

        combined_doc = f"{e.get('symbol', '')} ({kind}): {intent}"
        if tags:
            combined_doc += f" Tags: {', '.join(tags)}"

        ids.append(entry_id)
        documents.append(combined_doc)
        metadatas.append({
            "symbol": e.get('symbol', ''),
            "kind": kind,
            "file": e.get('file', ''),
            "lines_start": lines[0],
            "lines_end": lines[1],
            "intent": intent,
            "tags": json.dumps(tags),
            "author": author,
            "email": email,
            "commit": e.get('commit', ''),
            "ts": e.get('ts', '')
        })

    if ids:
        collection.upsert(ids=ids, documents=documents, metadatas=metadatas)

    print(f"Synced {len(ids)} entries to Chroma")
    print(f"  Author: {author}")
    print(f"  Email: {email}")

if __name__ == "__main__":
    main()
