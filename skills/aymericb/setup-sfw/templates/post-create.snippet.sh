workspace_root="$(cd "$(dirname "$0")/.." && pwd)"
shell_init="source \"$workspace_root/.devcontainer/sfw-shell.sh\""
if ! grep -Fqx "$shell_init" "$HOME/.bashrc"; then
    printf '\n%s\n' "$shell_init" >> "$HOME/.bashrc"
fi
