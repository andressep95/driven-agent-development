# Claude Code Hooks — Post-Commit Context Clear

Configuración del hook que detecta cada `git commit` y le indica al agente
que solicite `/clear` al usuario para limpiar el contexto completamente.

El agente no necesita recordar nada entre commits — Chroma es la memoria.

---

## Archivos a crear

### 1. `.claude/settings.json` (en la raíz de tu proyecto)

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/post-commit-clear.sh"
          }
        ]
      }
    ]
  }
}
```

### 2. `~/.claude/hooks/post-commit-clear.sh`

```bash
#!/usr/bin/env bash
# Hook post-commit para Claude Code.
# Detecta cuando el agente ejecutó un git commit y le indica que solicite /clear.
# El agente no debe acumular contexto entre commits — Chroma provee el contexto relevante.

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if echo "$CMD" | grep -q "git commit"; then
  echo '{"systemMessage": "Commit registrado en memoria. Indicale al usuario que escriba /clear para limpiar el contexto por completo antes de continuar con la próxima tarea. No inicies ninguna tarea nueva hasta que el usuario ejecute /clear."}'
else
  echo '{}'
fi
```

---

## Setup

```bash
# Crear directorio de hooks si no existe
mkdir -p ~/.claude/hooks

# Copiar el script
cp post-commit-clear.sh ~/.claude/hooks/post-commit-clear.sh

# Dar permisos de ejecución
chmod +x ~/.claude/hooks/post-commit-clear.sh
```

---

## Por qué `/clear` y no `/compact`

| | `/compact` | `/clear` |
|---|---|---|
| Qué hace | Resume la conversación en un snapshot | Borra todo, contexto cero |
| Qué queda | Un resumen comprimido de lo hecho | Nada |
| Tokens consumidos | Algunos — el resumen ocupa espacio | Cero |
| Para este caso | Mal — arrastra contexto innecesario | Correcto |

El agente es experto en su tarea y nada más.
Todo el conocimiento del proyecto viene de Chroma, no del historial de conversación.
Un resumen del commit anterior es ruido para la próxima tarea.

## Flujo resultante

```
Tarea A
  → agente trabaja
  → git commit
  → hook inyecta recordatorio
  → agente dice "escribí /clear"
  → usuario escribe /clear → contexto cero
  → Tarea B
  → agente consulta Chroma → recibe solo lo relevante para B
  → git commit
  → ...
```
