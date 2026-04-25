#!/usr/bin/env python3
import json, sys, argparse
try:
    import chromadb
except ImportError:
    print("ERROR: chromadb not installed")
    sys.exit(1)

def main():
    p = argparse.ArgumentParser()
    p.add_argument("query", nargs="?", default="")
    p.add_argument("--url", default="http://localhost:8000")
    p.add_argument("--collection", default="codebase")
    p.add_argument("--kind", default="")
    p.add_argument("--limit", type=int, default=10)
    p.add_argument("--json", action="store_true")
    args = p.parse_args()

    if not args.query:
        print("Usage: query-memory.py <query> [--kind controller] [--limit 5] [--json]")
        sys.exit(1)

    client = chromadb.HttpClient(host=args.url.replace("http://", "").split(":")[0],
                             port=args.url.split(":")[-1] if ":" in args.url else "8000")
    collection = client.get_collection(args.collection)

    where_clause = {"kind": args.kind} if args.kind else None
    results = collection.query(query_texts=[args.query], n_results=args.limit, where=where_clause)

    for i in range(len(results["ids"][0])):
        m = results["metadatas"][0][i]
        dist = results["distances"][0][i] if results.get("distances") else 0
        score = max(0, 1 - dist)
        print(f"## {m.get('symbol')} ({m.get('kind')})")
        print(f"   File: {m.get('file')}")
        print(f"   Lines: {m.get('lines_start')}-{m.get('lines_end')}")
        print(f"   Intent: {m.get('intent')}")
        print(f"   Author: {m.get('author')} <{m.get('email')}>")
        print(f"   Score: {score:.2%}")
        print()

if __name__ == "__main__":
    main()
