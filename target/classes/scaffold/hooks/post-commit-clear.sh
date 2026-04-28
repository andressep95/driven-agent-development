#!/usr/bin/env bash
# Shared post-commit hook for Claude Code and Kiro.
# Detects git commit execution and injects a /clear reminder.
# The agent must not carry context between commits — .agents/memory is the memory.

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if echo "$CMD" | grep -q "git commit"; then
  echo '{"systemMessage": "Commit registrado en memoria. Indica al usuario que escriba /clear para limpiar el contexto por completo antes de continuar con la próxima tarea. No inicies ninguna tarea nueva hasta que el usuario ejecute /clear."}'
else
  echo '{}'
fi
