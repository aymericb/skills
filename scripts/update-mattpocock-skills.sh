#!/usr/bin/env bash
# Update skills/mattpocock/ (a git subtree of the upstream skills/ folder of
# https://github.com/mattpocock/skills.git) to the latest mattpocock/main, then
# sync the mattpocock-skills plugin list in .claude-plugin/marketplace.json.
set -euo pipefail

remote="mattpocock"
remote_url="https://github.com/mattpocock/skills.git"
upstream_ref="${remote}/main"
prefix="skills/mattpocock"
split_branch="mattpocock-skills-only"
marketplace=".claude-plugin/marketplace.json"
sync_marketplace=1

usage() {
    cat <<USAGE
Usage: $(basename "$0") [--no-marketplace]

Pulls the latest ${upstream_ref} skills/ folder into ${prefix}/ and syncs
the mattpocock-skills plugin in ${marketplace}.

Options:
  --no-marketplace  Do not update ${marketplace}
  -h, --help        Show this help
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-marketplace) sync_marketplace=0 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "error: unknown argument: $1" >&2; usage >&2; exit 1 ;;
    esac
    shift
done

cd "$(git rev-parse --show-toplevel)"

if ! git subtree --help >/dev/null 2>&1 && [[ ! -x "$(git --exec-path)/git-subtree" ]]; then
    echo "error: git subtree is not available (see .devcontainer/install-git-subtree.sh)" >&2
    exit 1
fi

if [[ "$sync_marketplace" -eq 1 ]] && ! command -v jq >/dev/null; then
    echo "error: jq is required to sync ${marketplace} (or pass --no-marketplace)" >&2
    exit 1
fi

git update-index --refresh >/dev/null 2>&1 || true
if [[ -n "$(git status --porcelain)" ]]; then
    echo "error: working tree is not clean; commit or stash your changes first" >&2
    exit 1
fi

if ! git remote get-url "$remote" >/dev/null 2>&1; then
    echo "Adding remote ${remote} -> ${remote_url}"
    git remote add "$remote" "$remote_url"
fi

echo "Fetching ${remote}"
git fetch "$remote"
upstream_sha="$(git rev-parse --short "$upstream_ref")"

cleanup() {
    git branch -D "$split_branch" >/dev/null 2>&1 || true
}
cleanup
trap cleanup EXIT

echo "Splitting skills/ from ${upstream_ref} (${upstream_sha})"
git subtree split --prefix=skills -b "$split_branch" "$upstream_ref"

before="$(git rev-parse HEAD)"
git subtree pull --prefix="$prefix" . "$split_branch" \
    -m "Update ${prefix} from ${upstream_ref} (${upstream_sha})"

if [[ "$(git rev-parse HEAD)" == "$before" ]]; then
    echo "${prefix} already up to date with ${upstream_ref} (${upstream_sha})"
else
    echo "Updated ${prefix} to ${upstream_ref} (${upstream_sha}):"
    git log --oneline --no-merges "${before}..HEAD" -- "$prefix" | head -20
fi

if [[ "$sync_marketplace" -eq 1 ]]; then
    skills_json="$(
        find "$prefix" -name SKILL.md -not -path "${prefix}/deprecated/*" \
            | sed -e 's|/SKILL.md$||' -e 's|^|./|' \
            | LC_ALL=C sort \
            | jq -R . | jq -s .
    )"
    tmp="$(mktemp)"
    jq --indent 4 --argjson skills "$skills_json" \
        '(.plugins[] | select(.name == "mattpocock-skills") | .skills) = $skills' \
        "$marketplace" > "$tmp"
    cat "$tmp" > "$marketplace"
    rm -f "$tmp"

    if git diff --quiet -- "$marketplace"; then
        echo "${marketplace} already in sync"
    else
        echo "Updated ${marketplace} (left uncommitted for review):"
        git diff -U0 -- "$marketplace" | grep -E '^[+-] ' || true
    fi
fi
