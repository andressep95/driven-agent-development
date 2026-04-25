#!/usr/bin/env bash
# Rebuilds memory.db from memory.jsonl. Run after any write to memory.jsonl.
# Usage: bash .agent/scripts/rebuild.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DB="$ROOT/.agent/memory.db"
JSONL="$ROOT/.agent/memory.jsonl"
SCHEMA="$ROOT/.agent/schema.sql"

echo "Rebuilding $DB..."
rm -f "$DB"
sqlite3 "$DB" < "$SCHEMA"

if [ ! -s "$JSONL" ]; then
    echo "memory.jsonl is empty — blank DB created."
    exit 0
fi

python3 - "$DB" "$JSONL" << 'PYEOF'
import json, sqlite3, sys

db = sqlite3.connect(sys.argv[1])
symbols = 0
decisions = 0

with open(sys.argv[2]) as f:
    for raw in f:
        raw = raw.strip()
        if not raw:
            continue
        try:
            r = json.loads(raw)
        except json.JSONDecodeError as e:
            print(f"  skipping malformed line: {e}", file=sys.stderr)
            continue

        if r.get("type") == "symbol":
            lines = r.get("lines", [None, None])
            db.execute(
                "INSERT INTO codebase_index "
                "(file_path,symbol_name,symbol_type,line_start,line_end,intent,tags,git_hash,updated_at) "
                "VALUES (?,?,?,?,?,?,?,?,?)",
                (r.get("file"), r.get("symbol"), r.get("kind"),
                 lines[0] if lines else None,
                 lines[1] if len(lines) > 1 else None,
                 r.get("intent"),
                 json.dumps(r.get("tags", [])),
                 r.get("commit"), r.get("ts"))
            )
            symbols += 1

        elif r.get("type") == "decision":
            db.execute(
                "INSERT INTO decisions (context,decision,reason,tags,git_hash,timestamp) "
                "VALUES (?,?,?,?,?,?)",
                (r.get("context"), r.get("decision"), r.get("reason"),
                 json.dumps(r.get("tags", [])),
                 r.get("commit"), r.get("ts"))
            )
            decisions += 1

db.execute("INSERT INTO code_search(code_search) VALUES('rebuild')")
db.commit()
db.close()
print(f"Done: {symbols} symbols, {decisions} decisions.")
PYEOF
