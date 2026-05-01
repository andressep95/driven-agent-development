#!/usr/bin/env bash
# Full memory bootstrap: replay git history → push to Chroma.
# Run from anywhere — script resolves the project root automatically.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$ROOT"

REQUIREMENTS="$SCRIPT_DIR/requirements.txt"

# ── Check python3 ──────────────────────────────────────────────────────────
if ! command -v python3 &>/dev/null; then
    echo "[init] ERROR: python3 not found. Install Python 3.9+ and try again."
    exit 1
fi

# ── Check & install Python dependencies ────────────────────────────────────
missing=false
if ! python3 -c "import chromadb" &>/dev/null; then
    missing=true
fi

if [ "$missing" = true ]; then
    echo "[init] Missing Python dependencies (chromadb)."
    if [ -t 0 ]; then
        printf "[init] Install them now? (pip install -r requirements.txt) [Y/n]: "
        read -r answer
        answer="${answer:-Y}"
        if [[ ! "$answer" =~ ^[Yy]$ ]]; then
            echo "[init] Skipped. Install manually:"
            echo "    pip install -r $REQUIREMENTS"
            echo "[init] Continuing without Chroma support..."
            SKIP_CHROMA=true
        fi
    else
        echo "[init] Non-interactive mode — installing automatically."
    fi

    if [ "${SKIP_CHROMA:-}" != "true" ]; then
        echo "[init] Installing Python dependencies..."
        if pip install -r "$REQUIREMENTS"; then
            echo "[init] Dependencies installed."
        else
            echo "[init] WARNING: pip install failed. Continuing without Chroma."
            echo "    Try manually: pip install -r $REQUIREMENTS"
            SKIP_CHROMA=true
        fi
    fi
fi

# ── Memory bootstrap ──────────────────────────────────────────────────────
echo "=== Memory Bootstrap ==="

echo "[1/3] Replaying git history..."
bash "$SCRIPT_DIR/scan-history.sh"

echo "[2/3] Syncing changes to Chroma..."
if [ "${SKIP_CHROMA:-}" = "true" ]; then
    echo "  [skip] Chroma sync skipped — missing dependencies."
    echo "  memory.jsonl is populated. Install deps and re-run to enable semantic search."
elif python3 -c "import chromadb" &>/dev/null; then
    python3 "$SCRIPT_DIR/sync-to-chroma.py"
else
    echo "  [skip] chromadb not available — memory.jsonl is populated."
    echo "  Run: pip install -r $REQUIREMENTS"
fi

echo "[3/3] Indexing skills to Chroma..."
if [ "${SKIP_CHROMA:-}" != "true" ] && python3 -c "import chromadb" &>/dev/null; then
    python3 "$SCRIPT_DIR/sync-skills-to-chroma.py"
else
    echo "  [skip] Skills indexing skipped — Chroma not available."
fi

echo "=== Done ==="
