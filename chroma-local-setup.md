# Configuración Chroma Local -- Opción A (PersistentClient)

> Sin Docker, sin servidor, sin dependencias externas.

---

## 1. Eliminar la configuración Docker

Remueve el servicio de Chroma del `docker-compose.yml`:

```yaml
# ELIMINAR esto completamente:
# image: chromadb/chroma:1.5.3
# container_name: chroma
# ports:
#   - "8765:8000"
# environment:
#   ANONYMIZED_TELEMETRY: "FALSE"
#   IS_PERSISTENT: "TRUE"
# volumes:
#   - chroma_data:/chroma/chroma
```

También puedes eliminar el volumen `chroma_data` si lo tenías declarado en la sección volumes del compose.

---

## 2. Inicialización del Cliente

Usa exclusivamente `PersistentClient` en todos los archivos del proyecto:

```python
import chromadb

# Única inicialización necesaria -- no requiere servidor
client = chromadb.PersistentClient(path=".agents/memory/chroma")
```

- Los datos se persisten en `.agents/memory/chroma/`
- Un solo directorio, una sola DB
- No se necesita iniciar ningún servicio antes de correr los scripts

---

## 3. Archivos a Actualizar

### `.agents/scripts/sync-to-chroma.py`

```python
# ANTES
client = chromadb.HttpClient(host="localhost", port=8765)

# DESPUÉS
client = chromadb.PersistentClient(path=".agents/memory/chroma")
```

### `.agents/scripts/query-memory.py`

```python
# ANTES
client = chromadb.HttpClient(host="localhost", port=8765)

# DESPUÉS
client = chromadb.PersistentClient(path=".agents/memory/chroma")
```

> El resto del código -- `get_or_create_collection`, `add`, `query` -- no cambia nada.

---

## 4. Variables de Entorno a Eliminar

Remueve del `.env` o de cualquier configuración de entorno:

```bash
# ELIMINAR -- ya no son necesarias
CHROMA_HOST=localhost
CHROMA_PORT=8765
```

---

## 5. Agregar al `.gitignore`

```
```
# Chroma local -- no subir al repo
.agents/memory/chroma/
```

> Opcional: si prefieres versionar la DB dentro del repo para compartirla entre equipo, quita esta línea.

---

## 6. Validación

Corre este script para confirmar que todo funciona:

```python
import chromadb

client = chromadb.PersistentClient(path=".agents/memory/chroma")

# Crear colección de prueba
col = client.get_or_create_collection("test")

# Insertar
col.add(
    documents=["Prueba de configuración local"],
    ids=["test-1"]
)

# Query
results = col.query(query_texts=["configuración"], n_results=1)
print(results)
# Si imprime resultados, todo está correcto -- sin Docker
```

---

## Resumen

| Aspecto | Antes | Después |
|---|---|---|
| Docker | ✕ Requerido | ✄ Eliminado |
| Servidor HTTP | ✕ Corriendo en 8765 | ✄ No existe |
| Datos en | Volumen Docker | `.agents/memory/chroma/` |
| Dependencias | Docker + imagen | Solo `pip install chromadb` |
| Inicio | `docker compose up` | Nada -- corre directo |