#!/usr/bin/env bash
# The git feature / base image install Git under /usr/local without contrib/subtree.
# Copy the OS package's git-subtree into the active Git's exec-path when missing.
set -euo pipefail

exec_path="$(git --exec-path)"
target="${exec_path}/git-subtree"

if [[ -x "$target" ]]; then
    echo "git subtree already available"
    exit 0
fi

source_subtree=""

for candidate in \
    /usr/lib/git-core/git-subtree \
    /usr/libexec/git-core/git-subtree \
    /usr/share/git-core/contrib/subtree/git-subtree
do
    if [[ -x "$candidate" ]]; then
        source_subtree="$candidate"
        break
    fi
done

if [[ -z "$source_subtree" ]]; then
    echo "error: could not find an OS-provided git-subtree to install" >&2
    exit 1
fi

echo "Installing git-subtree into ${exec_path}"
if [[ -w "$exec_path" ]]; then
    install -m 755 "$source_subtree" "$target"
else
    sudo install -m 755 "$source_subtree" "$target"
fi

if [[ ! -x "$target" ]]; then
    echo "error: git-subtree install failed" >&2
    exit 1
fi

echo "git subtree installed"
