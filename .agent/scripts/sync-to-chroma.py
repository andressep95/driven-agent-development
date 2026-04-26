#!/usr/bin/env python3
"""
Pushes all memory.jsonl entries to ChromaDB.
Handles two record types:
  symbol — Java code symbols from scan-memory
  change — git hunk records from sync-hunks.py
"""
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


def entry_to_chroma(e):
    """Return (id, document, metadata) for any record type."""
    record_type = e.get('type', 'symbol')

    if record_type == 'change':
        entry_id = f"change:{e.get('commit','')}:{e.get('file','')}:{e.get('lines_start', 0)}"
        doc = f"{e.get('change_type','')} in {e.get('file','')} [{e.get('symbol','')}]: {e.get('intent','')}"
        hunk = e.get('hunk_content', '')
        if hunk:
            doc += f"\n{hunk[:500]}"
        tags = e.get('tags', [])
        if tags:
            doc += f"\nTags: {', '.join(tags)}"
        metadata = {
            'type':        'change',
            'change_type': e.get('change_type', ''),
            'file':        e.get('file', ''),
            'file_kind':   e.get('file_kind', ''),
            'symbol':      e.get('symbol', ''),
            'lines_start': e.get('lines_start', 0),
            'lines_end':   e.get('lines_end', 0),
            'lines_delta': e.get('lines_delta', 0),
            'intent':      e.get('intent', ''),
            'tags':        json.dumps(tags),
            'commit':      e.get('commit', ''),
            'author':      e.get('author', ''),
            'email':       e.get('email', ''),
            'ts':          e.get('ts', ''),
        }
    else:
        entry_id = f"symbol:{e.get('file', '')}:{e.get('symbol', '')}"
        lines = e.get('lines', [0, 0])
        tags  = e.get('tags', [])
        kind  = e.get('kind', '')
        doc = f"{e.get('symbol', '')} ({kind}): {e.get('intent', '')}"
        if tags:
            doc += f" Tags: {', '.join(tags)}"
        metadata = {
            'type':        'symbol',
            'symbol':      e.get('symbol', ''),
            'kind':        kind,
            'file':        e.get('file', ''),
            'lines_start': lines[0] if lines else 0,
            'lines_end':   lines[1] if len(lines) > 1 else 0,
            'intent':      e.get('intent', ''),
            'tags':        json.dumps(tags),
            'author':      e.get('author', e.get('email', '')),
            'email':       e.get('email', ''),
            'commit':      e.get('commit', ''),
            'ts':          e.get('ts', ''),
        }

    return entry_id, doc, metadata


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--jsonl',      default='.agent/memory.jsonl')
    p.add_argument('--url',        default='http://localhost:8000')
    p.add_argument('--collection', default='codebase')
    p.add_argument('--rebuild',    action='store_true',
                   help='Drop and recreate the collection before syncing (full rebuild)')
    args = p.parse_args()

    entries = load_jsonl(args.jsonl)
    if not entries:
        print("No entries in memory.jsonl")
        sys.exit(1)

    host = args.url.replace('http://', '').replace('https://', '').split(':')[0]
    port = int(args.url.split(':')[-1]) if ':' in args.url else 8000
    client = chromadb.HttpClient(host=host, port=port)

    if args.rebuild:
        try:
            client.delete_collection(args.collection)
            print(f"Dropped collection '{args.collection}'")
        except Exception:
            pass

    collection = client.get_or_create_collection(args.collection)

    ids, documents, metadatas = [], [], []
    for e in entries:
        try:
            eid, doc, meta = entry_to_chroma(e)
            ids.append(eid)
            documents.append(doc)
            metadatas.append(meta)
        except Exception as ex:
            print(f"  skipping malformed entry: {ex}", file=sys.stderr)

    if ids:
        collection.upsert(ids=ids, documents=documents, metadatas=metadatas)

    symbols = sum(1 for e in entries if e.get('type') == 'symbol')
    changes = sum(1 for e in entries if e.get('type') == 'change')
    print(f"Synced {len(ids)} entries to Chroma (symbols={symbols} changes={changes})")


if __name__ == '__main__':
    main()
