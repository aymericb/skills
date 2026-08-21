#!/usr/bin/env bash
set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/Library/Application Support/devseal"
IDENTITY="${DEVSEAL_IDENTITY:-$HOME/.config/age/se-identity.txt}"
# Install: replace __SECRETS_RELPATH__ with path to secrets.env.age relative to devseal/
# e.g. ../secrets/secrets.env.age or ../terraform/secrets.env.age
SECRETS_FILE="$SCRIPT_DIR/__SECRETS_RELPATH__"

# Handle --help
usage() {
    cat >&2 <<EOF
Usage: $(basename "$0") [--help]
       $(basename "$0") serve
       $(basename "$0") decrypt

  serve    Serve on localhost TCP (port and token in Application Support/devseal)
  decrypt  Decrypt secrets.env.age on the Mac
  --help   Show this help
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" || $# -eq 0 ]]; then
    usage
    exit 0
fi

# Dependencies
require() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "❌ Missing dependency: $1" >&2
        exit 1
    }
}
require age-plugin-se
require socat
require openssl

# Platform checks
if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "❌ devseal currently only supports macOS." >&2
    exit 1
fi

# Identity checks
if [[ ! -f "$IDENTITY" ]]; then
    cat >&2 <<EOF
❌ Secure Enclave age identity not found:

    $IDENTITY

Create one with:

    mkdir -p ~/.config/age
    age-plugin-se keygen \
        --access-control=any-biometry \
        -o ~/.config/age/se-identity.txt
EOF
    exit 1
fi

pick_port() {
    local port
    for port in $(seq 47100 47200); do
        if ! lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
            echo "$port"
            return 0
        fi
    done
    echo "❌ No free port found in range 47100-47200" >&2
    return 1
}

handle_request() {
    # Wire protocol (one connection per request):
    #   request:  "Bearer <token>\n" "<byte-length>\n" <ciphertext bytes>
    #   response: <plaintext bytes>  |  "ERR <message>\n"

    local auth_line content_length expected

    IFS= read -r auth_line || return 0
    auth_line="${auth_line%$'\r'}"

    expected="Bearer ${DEVSEAL_TOKEN:?}"
    if [[ "$auth_line" != "$expected" ]]; then
        printf "ERR unauthorized\n"
        return 0
    fi

    IFS= read -r content_length || return 0
    content_length="${content_length// /}"

    if ! [[ "$content_length" =~ ^[0-9]+$ ]] || ((content_length <= 0)); then
        printf "ERR bad request\n"
        return 0
    fi

    if ! head -c "$content_length" | age --decrypt -i "${DEVSEAL_IDENTITY:?}"; then
        printf "ERR decryption failed\n"
        return 0
    fi
}

case "${1:-}" in
    handle-request)
        handle_request
        ;;
    serve)
        mkdir -p "$CONFIG_DIR"
        chmod 700 "$CONFIG_DIR"

        port=$(pick_port)
        token=$(openssl rand -hex 32)

        umask 077
        printf "%s\n" "$port" >"$CONFIG_DIR/port"
        printf "%s\n" "$token" >"$CONFIG_DIR/token"

        echo "Serving on:"
        echo "  tcp://127.0.0.1:$port"
        echo "  config: $CONFIG_DIR"

        export DEVSEAL_TOKEN="$token"
        export DEVSEAL_IDENTITY="$IDENTITY"

        exec socat \
            "TCP-LISTEN:$port,bind=127.0.0.1,reuseaddr,fork" \
            "EXEC:\"$SCRIPT_DIR/host.sh handle-request\",stderr"
        ;;
    decrypt)
        age --decrypt -i "$IDENTITY" "$SECRETS_FILE"
        ;;
    *)
        usage
        exit 1
        ;;
esac
