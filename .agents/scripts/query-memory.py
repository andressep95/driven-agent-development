#!/usr/bin/env python3
"""
Searches memory.jsonl via ChromaDB (semantic) or JSONL keyword fallback.
Handles both record types: symbol (Java code) and change (git hunks).
"""
import json, sys, argparse, os


def search_jsonl(jsonl_path, query, kind_filter, type_filter, limit):
    if not os.path.exists(jsonl_path):
        print(f"ERROR: {jsonl_path} not found. Run scan-memory or make a commit first.")
        sys.exit(1)

    terms = [t.lower() for t in query.split()]
    results = []

    with open(jsonl_path) as f:
        for raw in f:
            raw = raw.strip()
            if not raw:
                continue
            try:
                e = json.loads(raw)
            except json.JSONDecodeError:
                continue

            if type_filter and e.get('type') != type_filter:
                continue
            if kind_filter:
                if e.get('kind') != kind_filter and e.get('file_kind') != kind_filter:
                    continue

            haystack = ' '.join([
                e.get('symbol', ''),
                e.get('file', ''),
                e.get('intent', ''),
                e.get('hunk_content', ''),
                e.get('change_type', ''),
                e.get('file_kind', e.get('kind', '')),
                ' '.join(e.get('tags', [])),
            ]).lower()

            score = sum(1 for t in terms if t in haystack)
            if score > 0:
                results.append((score, e))

    results.sort(key=lambda x: x[0], reverse=True)
    return results[:limit]


def print_symbol(m, score_label):
    lines = m.get('lines', m.get('lines_start'))
    if isinstance(lines, list):
        line_str = f"{lines[0]}-{lines[1]}"
    elif lines:
        line_str = f"{m.get('lines_start', 0)}-{m.get('lines_end', 0)}"
    else:
        line_str = '—'
    print(f"## {m.get('symbol')} ({m.get('kind', m.get('file_kind', ''))})")
    print(f"   File:   {m.get('file')}")
    print(f"   Lines:  {line_str}")
    print(f"   Intent: {m.get('intent')}")
    print(f"   Score:  {score_label}")
    print()


def print_change(m, score_label):
    print(f"## [{m.get('change_type','?').upper()}] {m.get('symbol')} — {m.get('file_kind','')}")
    print(f"   File:   {m.get('file')}")
    print(f"   Lines:  {m.get('lines_start', 0)}-{m.get('lines_end', 0)}  Δ{m.get('lines_delta', 0):+d}")
    print(f"   Intent: {m.get('intent')}")
    print(f"   Commit: {m.get('commit')}  {m.get('ts')}  {m.get('author')} <{m.get('email')}>")
    hunk = (m.get('hunk_content') or '').strip()
    if hunk:
        preview = '\n   '.join(hunk.splitlines()[:6])
        print(f"   Diff:\n   {preview}")
    print(f"   Score:  {score_label}")
    print()


def print_result(m, score_label):
    if m.get('type') == 'change':
        print_change(m, score_label)
    else:
        print_symbol(m, score_label)


def main():
    p = argparse.ArgumentParser()
    p.add_argument('query', nargs='?', default='')
    p.add_argument('--chroma',     default='.agents/memory/chroma')
    p.add_argument('--collection', default='changes')
    p.add_argument('--jsonl',      default='.agents/memory/memory.jsonl')
    p.add_argument('--kind',       default='', help='Filter by kind/file_kind')
    p.add_argument('--type',       default='', help='Filter by type: symbol | change')
    p.add_argument('--limit',      type=int, default=10)
    p.add_argument('--no-chroma',  action='store_true')
    args = p.parse_args()

    if not args.query:
        print("Usage: query-memory.py <query> [--type change|symbol] [--kind skill] [--limit 5]")
        sys.exit(1)

    if not args.no_chroma:
        try:
            import chromadb
            from chromadb.utils import embedding_functions
            client = chromadb.PersistentClient(path=args.chroma)
            ef = embedding_functions.DefaultEmbeddingFunction()
            collection = client.get_collection(args.collection, embedding_function=ef)

            where = {}
            if args.kind:
                where['$or'] = [{'kind': args.kind}, {'file_kind': args.kind}]
            if args.type:
                where['type'] = args.type

            results = collection.query(
                query_texts=[args.query],
                n_results=args.limit,
                where=where or None,
            )

            for i in range(len(results['ids'][0])):
                m = results['metadatas'][0][i]
                dist  = results['distances'][0][i] if results.get('distances') else 0
                score = max(0, 1 - dist)
                print_result(m, f"{score:.2%}")
            return

        except Exception as e:
            print(f"[query-memory] Chroma unavailable ({e}) — falling back to JSONL", file=sys.stderr)

    hits = search_jsonl(args.jsonl, args.query, args.kind, args.type, args.limit)
    if not hits:
        print("No results found.")
        return
    for score, e in hits:
        print_result(e, f"{score} keyword match(es)")


if __name__ == '__main__':
    main()
