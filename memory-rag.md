# Memory RAG — Modelo, Skill, Hook y Migración

Sistema de memoria persistente para agentes LLM basado en commits git.
Granularidad por hunk. Retrieval semántico con Chroma + FTS5 opcional.

---

## 1. Modelo de datos (JSONL)

Una entrada por hunk modificado, no por commit.
Archivo de salida: `.memory/changes.jsonl`

### Ejemplo de registro

```jsonl
{
  "type":                 "change",
  "change_type":          "addition",
  "file":                 "internal/auth/jwt.go",
  "file_kind":            "source",
  "symbol":               "func GenerateToken(userID string)",
  "lines_start":          42,
  "lines_end":            67,
  "lines_delta":          25,
  "what":                 "Genera tokens JWT usando RS256 con clave privada rotable",
  "why":                  "RS256 permite verificar tokens sin exponer la clave privada a los servicios cliente",
  "semantic_description": "Genera tokens JWT con RS256 para que los servicios cliente puedan verificar sin conocer la clave privada",
  "intent":               "feat(auth): implement JWT RS256 token generation",
  "tags":                 ["addition", "feat", "auth", "source"],
  "breaking":             false,
  "related_files":        ["internal/auth/keys.go", "config/auth.yaml"],
  "commit":               "a3f9c12",
  "author":               "Andres Sepulveda",
  "email":                "dev@example.com",
  "ts":                   "2026-04-27",
  "hunk_header":          "@@ -0,0 +42,25 @@ func GenerateToken(userID string)",
  "hunk_content":         "+func GenerateToken(userID string) (string, error) {\n+..."
}
```

### Referencia de campos

| Campo | Tipo | Descripción |
|---|---|---|
| `type` | `"change"` | Constante. Reservado para extensiones futuras (`"decision"`, `"note"`) |
| `change_type` | string | `addition` · `modification` · `deletion` — derivado del diff |
| `file` | string | Path relativo desde raíz del repo |
| `file_kind` | string | `source` · `script` · `config` · `doc` · `test` · `style` · `data` · `other` |
| `symbol` | string | Función/clase/sección del hunk header — contexto de localización |
| `lines_start` | int | Primera línea afectada en el archivo resultante |
| `lines_end` | int | Última línea afectada |
| `lines_delta` | int | Líneas netas añadidas (negativo = eliminadas) |
| `what` | string | Qué hace el código ahora que no hacía antes — extraído del commit body `what:` — **requerido** |
| `why` | string | Motivación del cambio — extraído del commit body `why:` — **campo más valioso para RAG** |
| `semantic_description` | string | `what` + `why` en prosa limpia — **único campo que se embeddea en Chroma** |
| `intent` | string | Subject line del commit (conventional commits) |
| `breaking` | bool | Rompe API o comportamiento existente |
| `tags` | string[] | `[change_type, commit_type, file_kind, scope]` — para filtrar en Chroma sin re-embeddear |
| `related_files` | string[] | Otros archivos del mismo commit — acoplamiento estructural |
| `commit` | string | Short SHA |
| `ts` | string | Fecha `YYYY-MM-DD` |
| `author` / `email` | string | Autoría |
| `hunk_header` | string | Raw `@@ -old +new @@` — solo referencia, no se embeddea |
| `hunk_content` | string | Diff raw con `+`/`-` — **solo en JSONL, nunca en Chroma** |

### Qué va a Chroma vs qué se queda en JSONL

```
Chroma — document (lo que se embeddea):
  semantic_description

Chroma — metadata (filtros sin re-embeddear):
  file, file_kind, symbol, what, why, intent, change_type,
  commit, ts, tags (string), related_files (string),
  lines_start, lines_end, breaking

Solo en JSONL (recuperar por ID cuando necesitás el diff):
  hunk_header, hunk_content
```

El ID de cada documento en Chroma es `commit:file:lines_start`.
Con ese ID buscás en el JSONL y recuperás el hunk completo cuando lo necesitás.

### Reglas de calidad

**`what` y `why` son obligatorios en todo commit que toca lógica.**

Un `what` vacío produce un embedding inútil.
Un `why` vacío hace imposible que una query semántica futura encuentre este cambio.

❌ MAL:
```
what: fix bug
why: estaba roto
```

✅ BIEN:
```
what: Reemplaza loop de queries individuales por batch query en getUserList
why: La versión anterior hacía N roundtrips a la DB, uno por usuario — O(n) en vez de O(1)
```

`semantic_description` es prosa, nunca código. No debe contener `+/-`, syntax de lenguaje ni rutas crudas.

---

## 2. Skill — cómo el LLM escribe el commit

Guardar como `skills/memory-commit/SKILL.md` en tu proyecto.

```markdown
---
name: memory-commit
description: "SIEMPRE ACTIVO — Antes de cada commit, analiza el diff y escribe un mensaje estructurado con what/why para alimentar el sistema de memoria RAG."
---

# Memory Commit — Protocolo

Antes de hacer cualquier commit seguí este protocolo completo.
No lo saltees aunque el cambio parezca pequeño.

## PASO 1 — Analizá el diff staged

Corré `git diff --staged` y por cada archivo identificá:
- Qué función o sección fue modificada (`symbol`)
- Qué hace el código ahora que no hacía antes (`what`)
- Por qué fue necesario ese cambio (`why`)

## PASO 2 — Escribí el commit con cuerpo estructurado

Formato obligatorio:

\```
<type>(<scope>): <subject>

what: <una oración — qué hace el código ahora>
why: <una oración — por qué fue necesario>
breaking: <true|false>
\```

### Tipos válidos
`feat` · `fix` · `refactor` · `perf` · `style` · `test` · `docs` · `chore` · `sec`

### Reglas del subject
- Imperativo, minúsculas, sin punto final
- Máximo 72 caracteres
- Específico: describe el cambio real, no el archivo que lo contiene

### Reglas de `what`
- Una oración en español o inglés
- Describe el comportamiento nuevo del código
- No menciones archivos ni líneas — el hook los captura automáticamente
- ❌ MAL: `"fix bug en auth"`
- ✅ BIEN: `"Reemplaza queries individuales por batch query en getUserList"`

### Reglas de `why`
- Una oración explicando la motivación
- Es el campo más importante para búsqueda semántica futura
- Debe responder: ¿qué problema resuelve? ¿qué restricción cumple? ¿qué decisión refleja?
- ❌ MAL: `"porque estaba roto"`
- ✅ BIEN: `"La versión anterior hacía N roundtrips a la DB, uno por usuario en la lista"`

### `breaking: true` solo cuando
- Cambia una firma de función pública
- Elimina un endpoint o campo de API
- Cambia el comportamiento observable de una feature existente

## PASO 3 — Ejecutá el commit

\```bash
git commit -m "$(cat <<'EOF'
feat(auth): implement JWT RS256 token generation

what: Genera tokens JWT firmados con RS256 usando clave privada rotable
why: RS256 permite a los servicios cliente verificar tokens sin conocer la clave privada
breaking: false
EOF
)"
\```

El post-commit hook se encarga del resto automáticamente.

## EJEMPLOS DE COMMITS BIEN FORMADOS

\```
fix(db): replace N+1 queries with batch fetch in getUserList

what: Reemplaza loop de queries individuales por una única query con IN clause
why: La versión anterior hacía un roundtrip por usuario, O(n) en vez de O(1)
breaking: false
\```

\```
feat(auth): add RS256 JWT generation with rotatable key pair

what: Genera y valida JWT usando par de claves RS256 cargadas desde disco
why: RS256 permite verificación sin distribuir el secreto, necesario para arquitectura multi-servicio
breaking: false
\```

\```
refactor(cache): extract Redis client into singleton with connection pooling

what: Centraliza la conexión Redis en un singleton con pool configurable
why: Cada handler creaba su propia conexión, agotando el pool bajo carga
breaking: false
\```
```

---

## 3. Hook — post-commit extractor

### `scripts/post-commit` (bash wrapper)

Copiar a `.git/hooks/post-commit` y darle permisos de ejecución.

```bash
#!/usr/bin/env bash
# Memory RAG — post-commit hook
# Invoca el extractor Python después de cada commit.
#
# Instalar:
#   cp scripts/post-commit .git/hooks/post-commit
#   chmod +x .git/hooks/post-commit

REPO_ROOT=$(git rev-parse --show-toplevel)
EXTRACTOR="$REPO_ROOT/scripts/extract_changes.py"

if [ -f "$EXTRACTOR" ]; then
    python3 "$EXTRACTOR" 2>/dev/null || true
fi
```

### `scripts/extract_changes.py`

```python
#!/usr/bin/env python3
"""
Post-commit extractor — genera una entrada JSONL por hunk modificado.
Lee what/why/breaking del cuerpo del commit y el diff para localización exacta.
Salida: .memory/changes.jsonl (append, idempotente por diseño del hook)
"""

import json
import re
import subprocess
from pathlib import Path


def run(cmd: str) -> str:
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return result.stdout.strip()


def file_kind(path: str) -> str:
    ext  = Path(path).suffix.lower()
    name = Path(path).stem.lower()
    if ext in {".sh", ".bash", ".zsh"}:
        return "script"
    if ext in {".py", ".go", ".ts", ".js", ".rs", ".java", ".c", ".cpp", ".rb"}:
        return "test" if "test" in name or "spec" in name else "source"
    if ext in {".json", ".yaml", ".yml", ".toml", ".env", ".ini", ".cfg"}:
        return "config"
    if ext in {".md", ".txt", ".rst", ".adoc"}:
        return "doc"
    if ext in {".css", ".scss", ".sass", ".less"}:
        return "style"
    return "other"


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
                "hunk_header": line,
                "symbol":      m.group(3).strip(),
                "lines_start": start,
                "lines_end":   start + max(count - 1, 0),
                "lines_delta": 0,
                "content":     [],
                "adds":        False,
                "dels":        False,
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


def make_tags(intent: str, kind: str, ctype: str) -> list[str]:
    tags = [ctype, kind]
    m = re.match(r"^(\w+)(?:\(([\w/-]+)\))?:", intent)
    if m:
        tags.insert(0, m.group(1))
        if m.group(2):
            tags.append(m.group(2))
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

    # Extraer campos estructurados del cuerpo del commit
    what     = ""
    why      = ""
    breaking = False
    for line in body.splitlines():
        if line.startswith("what:"):
            what = line[5:].strip()
        elif line.startswith("why:"):
            why = line[4:].strip()
        elif line.startswith("breaking:"):
            breaking = line[9:].strip().lower() == "true"

    # Archivos modificados en este commit
    files_raw = run("git diff-tree --no-commit-id -r --name-only HEAD")
    all_files = [f for f in files_raw.splitlines() if f]
    related   = {f: [x for x in all_files if x != f] for f in all_files}

    repo_root  = Path(run("git rev-parse --show-toplevel"))
    memory_dir = repo_root / ".memory"
    memory_dir.mkdir(exist_ok=True)
    jsonl_path = memory_dir / "changes.jsonl"

    records = []

    for file in all_files:
        kind = file_kind(file)

        # Diff del archivo — fallback a git show para el primer commit
        diff = run(f'git diff HEAD~1 HEAD -- "{file}" 2>/dev/null')
        if not diff:
            diff = run(f'git show HEAD -- "{file}"')

        # Encontrar primer @@ para ignorar headers del diff
        lines     = diff.splitlines()
        start_idx = next((i for i, l in enumerate(lines) if l.startswith("@@")), None)
        diff_body = "\n".join(lines[start_idx:]) if start_idx is not None else ""

        hunks = parse_hunks(diff_body)

        # Archivo añadido/eliminado completo sin hunks parseables
        if not hunks:
            hunks = [{
                "hunk_header": "",
                "symbol":      "",
                "lines_start": 1,
                "lines_end":   1,
                "lines_delta": sum(1 for l in lines if l.startswith("+")),
                "content":     lines[:80],
                "adds":        any(l.startswith("+") for l in lines),
                "dels":        any(l.startswith("-") for l in lines),
            }]

        for h in hunks:
            ctype = change_type(h["adds"], h["dels"])
            tags  = make_tags(intent, kind, ctype)
            sdesc = semantic_desc(what, why, intent, h["symbol"], file)

            records.append({
                "type":                 "change",
                "change_type":          ctype,
                "file":                 file,
                "file_kind":            kind,
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
                "author":               author,
                "email":                email,
                "ts":                   ts,
                "hunk_header":          h["hunk_header"],
                "hunk_content":         "\n".join(h["content"][:100]),
            })

    with open(jsonl_path, "a", encoding="utf-8") as f:
        for r in records:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")

    print(f"[memory] {len(records)} change(s) recorded → {commit}")


if __name__ == "__main__":
    main()
```

---

## 4. Migración JSONL → Chroma

### `scripts/migrate_to_chroma.py`

```python
#!/usr/bin/env python3
"""
Migra .memory/changes.jsonl a una colección Chroma persistente.
Embeddea solo semantic_description. Almacena el resto como metadata.
Idempotente — saltea registros ya indexados por ID.

Uso:
  pip install chromadb
  python3 scripts/migrate_to_chroma.py

Para usar OpenAI embeddings (mejor calidad semántica):
  pip install chromadb openai
  export OPENAI_API_KEY=sk-...
  python3 scripts/migrate_to_chroma.py --openai

Query de ejemplo después de migrar:
  python3 scripts/migrate_to_chroma.py --demo
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
            print("ERROR: OPENAI_API_KEY no está configurada.")
            sys.exit(1)
        return embedding_functions.OpenAIEmbeddingFunction(
            api_key=api_key,
            model_name="text-embedding-3-small",
        )

    # Default: sentence-transformers local (sin costo, funciona offline)
    return embedding_functions.DefaultEmbeddingFunction()


def build_metadata(r: dict) -> dict:
    # Chroma metadata solo acepta str, int, float — no listas ni bool
    return {
        "file":          r["file"],
        "file_kind":     r["file_kind"],
        "symbol":        r.get("symbol", ""),
        "what":          r.get("what", ""),
        "why":           r.get("why", ""),
        "intent":        r["intent"],
        "change_type":   r["change_type"],
        "commit":        r["commit"],
        "ts":            r["ts"],
        "author":        r["author"],
        "tags":          ",".join(r.get("tags", [])),
        "related_files": ",".join(r.get("related_files", [])),
        "lines_start":   r["lines_start"],
        "lines_end":     r["lines_end"],
        "breaking":      "true" if r.get("breaking") else "false",
    }


def migrate(
    jsonl_path: str,
    chroma_path: str,
    collection_name: str,
    use_openai: bool,
) -> None:
    try:
        import chromadb
    except ImportError:
        print("ERROR: pip install chromadb")
        sys.exit(1)

    if not Path(jsonl_path).exists():
        print(f"ERROR: {jsonl_path} no existe.")
        sys.exit(1)

    records = load_jsonl(jsonl_path)
    print(f"Cargados {len(records)} registros desde {jsonl_path}")

    client     = chromadb.PersistentClient(path=chroma_path)
    ef         = get_embedding_function(use_openai)
    collection = client.get_or_create_collection(
        name=collection_name,
        embedding_function=ef,
        metadata={"hnsw:space": "cosine"},
    )

    # IDs ya indexados — evita re-embeddear en migraciones incrementales
    existing = set(collection.get(include=[])["ids"])

    new = [
        r for r in records
        if f"{r['commit']}:{r['file']}:{r['lines_start']}" not in existing
    ]

    if not new:
        print("Nada nuevo para indexar.")
        return

    print(f"Indexando {len(new)} registros nuevos...")

    BATCH = 100
    for i in range(0, len(new), BATCH):
        batch = new[i : i + BATCH]

        ids       = [f"{r['commit']}:{r['file']}:{r['lines_start']}" for r in batch]
        documents = [r.get("semantic_description") or r["intent"] for r in batch]
        metas     = [build_metadata(r) for r in batch]

        collection.upsert(ids=ids, documents=documents, metadatas=metas)
        print(f"  {min(i + BATCH, len(new))}/{len(new)} indexados...")

    print(f"Listo. Colección '{collection_name}' en {chroma_path}")


def demo_query(chroma_path: str, collection_name: str, use_openai: bool) -> None:
    """Ejemplo de búsqueda semántica sobre el historial de commits."""
    import chromadb

    client     = chromadb.PersistentClient(path=chroma_path)
    ef         = get_embedding_function(use_openai)
    collection = client.get_or_create_collection(
        name=collection_name,
        embedding_function=ef,
    )

    query   = "cómo manejamos la autenticación de usuarios"
    results = collection.query(query_texts=[query], n_results=5)

    print(f"\nQuery: '{query}'")
    print("-" * 60)
    for doc, meta in zip(results["documents"][0], results["metadatas"][0]):
        print(f"\n[{meta['commit']}] {meta['file']}:{meta['lines_start']}")
        print(f"  intent : {meta['intent']}")
        print(f"  what   : {meta['what']}")
        print(f"  why    : {meta['why']}")
        print(f"  embed  : {doc}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Migra changes.jsonl a Chroma")
    parser.add_argument("--jsonl",      default=".memory/changes.jsonl")
    parser.add_argument("--chroma",     default=".memory/chroma")
    parser.add_argument("--collection", default="changes")
    parser.add_argument(
        "--openai",
        action="store_true",
        help="Usa OpenAI text-embedding-3-small en vez de sentence-transformers local",
    )
    parser.add_argument(
        "--demo",
        action="store_true",
        help="Ejecuta una query de ejemplo después de migrar",
    )
    args = parser.parse_args()

    migrate(args.jsonl, args.chroma, args.collection, args.openai)

    if args.demo:
        demo_query(args.chroma, args.collection, args.openai)
```

---

## Setup rápido

```bash
# 1. Instalar el hook
cp scripts/post-commit .git/hooks/post-commit
chmod +x .git/hooks/post-commit

# 2. Dependencias para migración
pip install chromadb            # embeddings locales (sentence-transformers, sin costo)
# o
pip install chromadb openai     # embeddings OpenAI (mejor calidad semántica)

# 3. Hacer commits normalmente — el hook genera .memory/changes.jsonl automáticamente

# 4. Migrar a Chroma cuando quieras habilitar búsqueda semántica
python3 scripts/migrate_to_chroma.py

# Con OpenAI embeddings:
export OPENAI_API_KEY=sk-...
python3 scripts/migrate_to_chroma.py --openai

# Verificar con query de ejemplo:
python3 scripts/migrate_to_chroma.py --demo
```

## Estructura de archivos resultante

```
tu-proyecto/
├── .memory/
│   ├── changes.jsonl        ← fuente de verdad, append-only
│   └── chroma/              ← base vectorial persistente (generada por migrate)
├── scripts/
│   ├── post-commit          ← bash wrapper del hook
│   ├── extract_changes.py   ← extractor (invocado por el hook)
│   └── migrate_to_chroma.py ← migración incremental a Chroma
└── skills/
    └── memory-commit/
        └── SKILL.md         ← instrucciones para el LLM
```
