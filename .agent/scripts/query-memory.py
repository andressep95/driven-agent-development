#!/usr/bin/env python3
import json, sys, argparse, os

def search_jsonl(jsonl_path, query, kind_filter, limit):
    if not os.path.exists(jsonl_path):
        print(f"ERROR: {jsonl_path} not found. Run scan-memory first.")
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

            if e.get("type") != "symbol":
                continue
            if kind_filter and e.get("kind") != kind_filter:
                continue

            haystack = " ".join([
                e.get("symbol", ""),
                e.get("kind", ""),
                e.get("intent", ""),
                e.get("file", ""),
                " ".join(e.get("tags", [])),
            ]).lower()

            score = sum(1 for t in terms if t in haystack)
            if score > 0:
                results.append((score, e))

    results.sort(key=lambda x: x[0], reverse=True)
    return results[:limit]

def print_result(m, score_label):
    lines = m.get("lines", [0, 0])
    print(f"## {m.get('symbol')} ({m.get('kind')})")
    print(f"   File: {m.get('file')}")
    print(f"   Lines: {lines[0]}-{lines[1]}")
    print(f"   Intent: {m.get('intent')}")
    print(f"   Score: {score_label}")
    print()

def main():
    p = argparse.ArgumentParser()
    p.add_argument("query", nargs="?", default="")
    p.add_argument("--url", default="http://localhost:8000")
    p.add_argument("--collection", default="codebase")
    p.add_argument("--jsonl", default=".agent/memory.jsonl")
    p.add_argument("--kind", default="")
    p.add_argument("--limit", type=int, default=10)
    p.add_argument("--json", action="store_true")
    p.add_argument("--no-chroma", action="store_true", help="Skip Chroma, query JSONL directly")
    args = p.parse_args()

    if not args.query:
        print("Usage: query-memory.py <query> [--kind controller] [--limit 5] [--no-chroma]")
        sys.exit(1)

    # Try Chroma first unless --no-chroma
    if not args.no_chroma:
        try:
            import chromadb
            host = args.url.replace("http://", "").replace("https://", "").split(":")[0]
            port = int(args.url.split(":")[-1]) if ":" in args.url else 8000
            client = chromadb.HttpClient(host=host, port=port)
            client.heartbeat()  # raises if Chroma is down
            collection = client.get_collection(args.collection)

            where_clause = {"kind": args.kind} if args.kind else None
            results = collection.query(
                query_texts=[args.query],
                n_results=args.limit,
                where=where_clause,
            )

            for i in range(len(results["ids"][0])):
                m = results["metadatas"][0][i]
                dist = results["distances"][0][i] if results.get("distances") else 0
                score = max(0, 1 - dist)
                print_result(m, f"{score:.2%}")
            return

        except Exception as e:
            print(f"[query-memory] Chroma unavailable ({e}) — falling back to JSONL", file=sys.stderr)

    # Fallback: text search over memory.jsonl
    hits = search_jsonl(args.jsonl, args.query, args.kind, args.limit)
    if not hits:
        print("No results found.")
        return

    for score, e in hits:
        print_result(e, f"{score} keyword match(es)")

if __name__ == "__main__":
    main()
