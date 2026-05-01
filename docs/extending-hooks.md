# Extending Driven — Hooks, Commands & Injection Guide

Este documento explica cómo agregar nuevos hooks, comandos y comportamientos automáticos al scaffold de Driven Agent Development. Todo se basa en el sistema de hooks de Claude Code / Kiro que interceptan eventos del ciclo de vida del agente.

---

## Arquitectura

```
usuario escribe prompt
  │
  ├─ UserPromptSubmit hooks    ← ANTES de que el agente responda
  │    └─ puede inyectar additionalContext, bloquear, o modificar
  │
  ├─ agente genera respuesta
  │    ├─ PreToolUse hooks     ← ANTES de ejecutar una herramienta
  │    ├─ [herramienta se ejecuta]
  │    └─ PostToolUse hooks    ← DESPUÉS de ejecutar una herramienta
  │
  ├─ Stop hooks                ← cuando el agente termina su turno
  │
  └─ SessionStart hooks        ← al iniciar una sesión nueva
```

Cada hook es un script que recibe JSON por stdin y devuelve JSON por stdout.

---

## Eventos disponibles

| Evento | Cuándo se dispara | Input clave | Qué puede hacer |
|--------|-------------------|-------------|-----------------|
| `UserPromptSubmit` | Cada mensaje del usuario | `prompt` | Inyectar contexto, bloquear, modificar prompt |
| `SessionStart` | Al iniciar sesión | `source` (startup/resume/clear) | Inyectar protocolo base, configurar env |
| `PreToolUse` | Antes de ejecutar herramienta | `tool_name`, `tool_input` | Aprobar/bloquear, modificar input, inyectar contexto |
| `PostToolUse` | Después de ejecutar herramienta | `tool_name`, `tool_input`, `tool_response` | Inyectar contexto, modificar output MCP |
| `Stop` | Agente termina su turno | `last_assistant_message` | Forzar continuación |
| `Notification` | Notificaciones del sistema | — | Inyectar contexto |

---

## Anatomía de un hook

### Input (JSON por stdin)

Todos los hooks reciben al menos:

```json
{
  "session_id": "abc-123",
  "cwd": "/path/to/project",
  "hook_event_name": "UserPromptSubmit"
}
```

Campos adicionales según el evento:

- **UserPromptSubmit**: `"prompt": "texto del usuario"`
- **PreToolUse**: `"tool_name": "Write"`, `"tool_input": {...}`
- **PostToolUse**: `"tool_name": "Bash"`, `"tool_input": {...}`, `"tool_response": {...}`
- **Stop**: `"last_assistant_message": "texto"`

### Output (JSON por stdout)

```json
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "texto que el agente verá como contexto del sistema"
  }
}
```

Devolver `{}` = no hacer nada.

### Códigos de salida

| Exit code | Efecto |
|-----------|--------|
| `0` | Éxito — stdout se procesa |
| `2` | **Bloqueo** — stderr se muestra al agente como error |
| otro | Error no-bloqueante — stderr se muestra al usuario |

---

## Cómo agregar un nuevo hook

### Paso 1: Crear el script

Crear en `src/main/resources/scaffold/scripts/`:

```bash
#!/usr/bin/env bash
# mi-hook.sh — descripción breve
set -uo pipefail

INPUT=$(cat)
# extraer lo que necesites del JSON
PROMPT=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('prompt',''))" 2>/dev/null)

# tu lógica acá...

# devolver JSON o {} si no hay nada que inyectar
echo '{}'
```

### Paso 2: Registrar en Claude Code

Agregar al `src/main/resources/scaffold/.claude/settings.json`:

```json
{
  "hooks": {
    "EVENTO": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": ".agents/scripts/mi-hook.sh",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

- `matcher`: filtro para PreToolUse/PostToolUse (ej: `"Bash"`, `"Write|Edit"`, `""` = todos)
- `timeout`: segundos antes de cancelar

### Paso 3: Registrar en Kiro

Crear `src/main/resources/scaffold/.kiro/hooks/mi-hook.yaml`:

```yaml
name: mi-hook
description: Descripción breve.
trigger:
  type: EVENTO
  matcher: Bash          # solo para PreToolUse/PostToolUse, omitir si no aplica
action:
  type: command
  command: .agents/scripts/mi-hook.sh
  timeout: 10
```

### Paso 4: Registrar en SetupAgentCommand.java

En la sección de Kiro, agregar:

```java
extractFile(".kiro/hooks/mi-hook.yaml", ".kiro/hooks/mi-hook.yaml");
```

Los scripts se extraen automáticamente con `extractDir("scripts/", ".agents/scripts/")`.

### Paso 5: Rebuild y test

```bash
mvn package -q
java -jar target/agent.jar setup-agent
# probar:
echo '{"prompt":"test"}' | bash .agents/scripts/mi-hook.sh
```

---

## Recetas: hooks útiles que podés agregar

### 1. Guardia de archivos protegidos (PreToolUse)

Bloquea escritura en archivos críticos sin confirmación:

```bash
#!/usr/bin/env bash
# guard-protected-files.sh
set -uo pipefail
INPUT=$(cat)
TOOL=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null)
FILE=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))" 2>/dev/null)

PROTECTED="pom.xml|Dockerfile|.github/|.agents/rules.md"

if [[ "$TOOL" =~ ^(Write|Edit)$ ]] && echo "$FILE" | grep -qE "$PROTECTED"; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Archivo protegido. Pedí confirmación al usuario antes de modificar."}}'
else
  echo '{}'
fi
```

Registro en settings.json:
```json
"PreToolUse": [{"matcher": "Write|Edit", "hooks": [{"type": "command", "command": ".agents/scripts/guard-protected-files.sh"}]}]
```

### 2. Auto-lint después de escribir código (PostToolUse)

```bash
#!/usr/bin/env bash
# post-write-lint.sh
set -uo pipefail
INPUT=$(cat)
FILE=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))" 2>/dev/null)

if echo "$FILE" | grep -qE '\.java$'; then
  # ejecutar checkstyle o spotless
  LINT_OUTPUT=$(mvn spotless:check -q 2>&1 | tail -5 || true)
  if [ -n "$LINT_OUTPUT" ]; then
    python3 -c "
import json,sys
print(json.dumps({'hookSpecificOutput':{'hookEventName':'PostToolUse','additionalContext':'Lint issues detected:\n'+sys.stdin.read()}}))
" <<< "$LINT_OUTPUT"
    exit 0
  fi
fi
echo '{}'
```

Registro: `"PostToolUse": [{"matcher": "Write|Edit", "hooks": [...]}]`

### 3. Inyectar stack/contexto del proyecto al inicio de sesión (SessionStart)

```bash
#!/usr/bin/env bash
# session-start.sh
cat <<'EOF'
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"## Project Context\n- Stack: Java 21 + Spring Boot 3.3 + PostgreSQL\n- Build: mvn package\n- Test: mvn test\n- Deploy: docker compose up\n\nSiempre consultá memoria antes de implementar."}}
EOF
```

Registro: `"SessionStart": [{"hooks": [{"type": "command", "command": ".agents/scripts/session-start.sh"}]}]`

### 4. Forzar que el agente no pare hasta pasar tests (Stop)

```bash
#!/usr/bin/env bash
# stop-verify-tests.sh
set -uo pipefail
INPUT=$(cat)

# verificar si hay tests fallando
if mvn test -q 2>&1 | grep -q "BUILD FAILURE"; then
  python3 -c "
import json
print(json.dumps({'continue': True, 'hookSpecificOutput':{'hookEventName':'Stop','additionalContext':'Tests are failing. Fix them before stopping.'}}))"
else
  echo '{}'
fi
```

Registro: `"Stop": [{"hooks": [{"type": "command", "command": ".agents/scripts/stop-verify-tests.sh", "timeout": 60}]}]`

### 5. Validar formato de commit antes de ejecutar git commit (PreToolUse)

```bash
#!/usr/bin/env bash
# validate-commit-msg.sh
set -uo pipefail
INPUT=$(cat)
CMD=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null)

if echo "$CMD" | grep -q "git commit"; then
  # verificar que tiene what:/why:/breaking: en el body
  if ! echo "$CMD" | grep -qE "what:|why:|breaking:"; then
    echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Commit body must include what:, why:, and breaking: fields. Rewrite the commit message."}}' 
    exit 0
  fi
fi
echo '{}'
```

Registro: `"PreToolUse": [{"matcher": "Bash", "hooks": [...]}]`

### 6. Inyectar OpenAPI spec cuando se toca un controller (UserPromptSubmit)

Extender `user-prompt-submit.sh` o crear uno separado:

```bash
#!/usr/bin/env bash
# inject-openapi-context.sh
set -uo pipefail
INPUT=$(cat)
PROMPT=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('prompt','').lower())" 2>/dev/null)

if echo "$PROMPT" | grep -qE "endpoint|controller|api|rest|http"; then
  if [ -f "api/openapi.yaml" ]; then
    SPEC=$(head -100 api/openapi.yaml)
    python3 -c "
import json,sys
print(json.dumps({'hookSpecificOutput':{'hookEventName':'UserPromptSubmit','additionalContext':'## Current OpenAPI Spec (first 100 lines)\n'+sys.stdin.read()}}))" <<< "$SPEC"
    exit 0
  fi
fi
echo '{}'
```

---

## Campos de respuesta por evento

### UserPromptSubmit

```json
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "texto inyectado al agente"
  }
}
```

### PreToolUse

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow|deny|ask",
    "permissionDecisionReason": "por qué",
    "updatedInput": { "command": "comando modificado" },
    "additionalContext": "contexto extra"
  }
}
```

### PostToolUse

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "contexto extra post-ejecución"
  }
}
```

### SessionStart

```json
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "protocolo base",
    "initialUserMessage": "mensaje inicial modificado"
  }
}
```

### Stop

```json
{
  "continue": true,
  "hookSpecificOutput": {
    "hookEventName": "Stop",
    "additionalContext": "por qué debe continuar"
  }
}
```

---

## Tips

- **Múltiples hooks del mismo evento** se ejecutan en paralelo. Todos los `additionalContext` se concatenan.
- **`timeout`** por defecto es 10 minutos. Poné valores bajos (5-15s) para hooks que no deben bloquear.
- **Testear siempre** con `echo '{"prompt":"..."}' | bash .agents/scripts/mi-hook.sh` antes de integrar.
- **`{}` es seguro** — si tu hook no tiene nada que inyectar, devolver `{}` no afecta nada.
- **stderr** se muestra al usuario pero no al agente (excepto exit code 2 que sí llega al agente).
- **Variables de entorno**: los hooks reciben `CLAUDE_PROJECT_DIR` con la raíz del proyecto.
