#!/usr/bin/env python3
"""
Syncs .agents/memory/memory.jsonl to a persistent Chroma collection.
Embeds semantic_description. Stores the rest as metadata.
Idempotent — skips already-indexed records by ID (commit:file:lines_start).

Usage:
  python3 .agents/scripts/sync-to-chroma.py
  python3 .agents/scripts/sync-to-chroma.py --rebuild
  python3 .agents/scripts/sync-to-chroma.py --openai
"""

import argparse
import json
import sys
from pathlib import Path


def load_jsonl(path: str) -> list[dict]:
    records = []
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                records.append(json.loads(line))
    return records


def get_embedding_function(use_openai: bool):
    from chromadb.utils import embedding_functions
    if use_openai:
        import os
        api_key = os.environ.get("OPENAI_API_KEY")
        if not api_key:
            print("ERROR: OPENAI_API_KEY not set.")
            sys.exit(1)
        return embedding_functions.OpenAIEmbeddingFunction(
            api_key=api_key,
            model_name="text-embedding-3-small",
        )
    return embedding_functions.SentenceTransformerEmbeddingFunction(model_name="intfloat/multilingual-e5-small")


def build_metadata(r: dict) -> dict:
    return {
        "file":          r["file"],
        "file_kind":     r["file_kind"],
        "language":      r.get("language", ""),
        "symbol":        r.get("symbol", ""),
        "what":          r.get("what", ""),
        "why":           r.get("why", ""),
        "intent":        r["intent"],
        "commit_type":   r.get("commit_type", ""),
        "scope":         r.get("scope", ""),
        "change_type":   r["change_type"],
        "commit":        r["commit"],
        "branch":        r.get("branch", ""),
        "project":       r.get("project", ""),
        "ts":            r["ts"],
        "author":        r["author"],
        "tags":          ",".join(r.get("tags", [])),
        "related_files": ",".join(r.get("related_files", [])),
        "lines_start":   r["lines_start"],
        "lines_end":     r["lines_end"],
        "breaking":      "true" if r.get("breaking") else "false",
    }


def sync(jsonl_path: str, chroma_path: str, collection_name: str,
         use_openai: bool, rebuild: bool) -> None:
    try:
        import chromadb
    except ImportError:
        print("ERROR: pip install chromadb")
        sys.exit(1)

    if not Path(jsonl_path).exists():
        print(f"ERROR: {jsonl_path} not found.")
        sys.exit(1)

    records = load_jsonl(jsonl_path)
    print(f"Loaded {len(records)} records from {jsonl_path}")

    client = chromadb.PersistentClient(path=chroma_path)
    ef     = get_embedding_function(use_openai)

    if rebuild:
        try:
            client.delete_collection(collection_name)
            print(f"Dropped collection '{collection_name}'")
        except Exception:
            pass

    collection = client.get_or_create_collection(
        name=collection_name,
        embedding_function=ef,
        metadata={"hnsw:space": "cosine"},
    )

    existing = set(collection.get(include=[])["ids"])
    new = [
        r for r in records
        if f"{r['commit']}:{r['file']}:{r['lines_start']}" not in existing
    ]

    if not new:
        print("Nothing new to index.")
        return

    print(f"Indexing {len(new)} new records...")
    BATCH = 100
    for i in range(0, len(new), BATCH):
        batch     = new[i : i + BATCH]
        ids       = [f"{r['commit']}:{r['file']}:{r['lines_start']}" for r in batch]
        documents = [r.get("semantic_description") or r["intent"] for r in batch]
        metas     = [build_metadata(r) for r in batch]
        collection.upsert(ids=ids, documents=documents, metadatas=metas)
        print(f"  {min(i + BATCH, len(new))}/{len(new)} indexed...")

    print(f"Done. Collection '{collection_name}' at {chroma_path}")


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--jsonl",      default=".agents/memory/memory.jsonl")
    p.add_argument("--chroma",     default=".agents/memory/chroma")
    p.add_argument("--collection", default="changes")
    p.add_argument("--openai",     action="store_true")
    p.add_argument("--rebuild",    action="store_true",
                   help="Drop and recreate the collection before syncing")
    args = p.parse_args()

    sync(args.jsonl, args.chroma, args.collection, args.openai, args.rebuild)
