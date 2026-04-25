#!/usr/bin/env bash
# Installs git hooks from skills/ into .git/hooks/ via symlink.
# Run once after cloning: bash .agent/scripts/install-hooks.sh
set -euo pipefail

# Hook mapping: hook name → source path
HOOK_post_commit="skills/commit/assets/post-commit.sh"

install_hook() {
    local hook_name="$1"
    local src="${2}"
    local dst=".git/hooks/$hook_name"

    if [ ! -f "$src" ]; then
        echo "SKIP $hook_name — $src not found"
        return
    fi

    if [ -f "$dst" ] && [ ! -L "$dst" ]; then
        echo "BACKUP existing $dst → $dst.bak"
        mv "$dst" "$dst.bak"
    fi

    ln -sf "../../$src" "$dst"
    chmod +x "$src"
    echo "OK   $dst → $src"
}

install_hook "post-commit" "$HOOK_post_commit"
echo "Done. Hooks installed."
