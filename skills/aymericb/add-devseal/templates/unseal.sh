#!/usr/bin/env bash
set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${DEVSEAL_DIR:-/run/devseal}"
HOST="${DEVSEAL_HOST:-host.docker.internal}"
# Install: replace __SECRETS_RELPATH__ with path to secrets.env.age relative to devseal/
# e.g. ../secrets/secrets.env.age or ../terraform/secrets.env.age
SECRETS_FILE="$SCRIPT_DIR/__SECRETS_RELPATH__"

# Handle --help
usage() {
    cat >&2 <<EOF
Usage: $(basename "$0") [--help]

  Decrypt secrets.env.age via the devseal host TCP service and write to stdout.
  --help  Show this help
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    usage
    exit 0
fi

if [[ $# -gt 0 ]]; then
    usage
    exit 1
fi

# Check if the config files exist
port_file="$CONFIG_DIR/port"
token_file="$CONFIG_DIR/token"

if [[ ! -f "$port_file" || ! -f "$token_file" ]]; then
    cat >&2 <<EOF
❌ devseal config not found:

    $port_file
    $token_file

Start the host on your Mac with:

    ./devseal/host.sh serve
EOF
    exit 1
fi

# Check if the secrets file exists
if [[ ! -f "$SECRETS_FILE" ]]; then
    echo "❌ Encrypted secrets not found: $SECRETS_FILE" >&2
    exit 1
fi

# Load port/token
port=$(tr -d "[:space:]" <"$port_file")
token=$(tr -d "[:space:]" <"$token_file")
content_length=$(wc -c <"$SECRETS_FILE" | tr -d " ")

if ! exec 3<>"/dev/tcp/${HOST}/${port}"; then
    echo "❌ Cannot connect to devseal at ${HOST}:${port}" >&2
    exit 1
fi

# Send request
printf "Bearer %s\n" "$token" >&3
printf "%s\n" "$content_length" >&3
cat "$SECRETS_FILE" >&3

# Read response
prefix=""
IFS= read -r -n 4 prefix <&3 || [[ -n "$prefix" ]]

if [[ "$prefix" == "ERR " ]]; then
    err_line=""
    IFS= read -r err_line <&3 || true
    echo "❌ devseal: ${err_line:-unknown error}" >&2
    exit 1
fi

printf "%s" "$prefix"
cat <&3
