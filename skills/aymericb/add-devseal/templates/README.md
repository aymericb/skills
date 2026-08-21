# devseal

Decrypt project secrets inside the Dev Container without copying the Secure Enclave age identity off your Mac.

`__SECRETS_PATH__` is encrypted with [age](https://github.com/FiloSottile/age) and [age-plugin-se](https://github.com/remko/age-plugin-se) (Touch ID / Secure Enclave). The private key never leaves macOS.

devseal runs a small localhost TCP service on the Mac that decrypts on demand; the container sends ciphertext and receives plaintext over the wire.

## How it works

```
┌─────────────────────┐         bind mount          ┌──────────────────────┐
│  Mac (host)         │  port + token files only    │  Linux Dev Container  │
│                     │ ──────────────────────────► │                      │
│  host.sh serve      │                             │  /run/devseal/       │
│  age-plugin-se key  │ ◄──── TCP (host.docker.     │  unseal.sh           │
│  127.0.0.1:47xxx    │       internal)             │                      │
└─────────────────────┘                             └──────────────────────┘
```

1. **`host.sh serve`** (Mac) picks a free port, writes `port` and `token` to `~/Library/Application Support/devseal`, and listens on `127.0.0.1` via `socat`.

2. The Dev Container bind-mounts that directory read-only at `/run/devseal` (see `.devcontainer/devcontainer.json`).

3. **`unseal.sh`** (container) reads port/token, connects to `host.docker.internal`, sends `__SECRETS_PATH__`, and prints decrypted `secrets.env` to stdout.

Plaintext is streamed through a pipe so that nothing is written to temp files on either side.

## Usage

**Mac — start the service** (once per session, before using the container):

```sh
./devseal/host.sh serve
```

**Container — load secrets into the shell:**

```sh
source <(./devseal/unseal.sh)
```

**Mac — decrypt locally** (no service needed):

```sh
./devseal/host.sh decrypt
```

## Encrypt / rotate secrets (Mac)

```sh
age -R __RECIPIENTS_PATH__ -o __SECRETS_PATH__ secrets.env
```

Plaintext `secrets.env` must stay gitignored. Commit `__SECRETS_PATH__` and `__RECIPIENTS_PATH__`.

## Wire protocol

One TCP connection per request. No HTTP.

**Request:** `Bearer <token>\n` + `<byte-length>\n` + ciphertext bytes

**Response:** plaintext bytes, or `ERR <message>\n`
