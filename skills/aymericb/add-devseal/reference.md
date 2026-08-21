# devseal reference

## Architecture

devseal decrypts an age-encrypted `secrets.env.age` inside a Dev Container without copying the Secure Enclave private key off macOS.

1. **Mac** — `./devseal/host.sh serve` picks a free TCP port in `47100–47200`, writes `port` and `token` under `~/Library/Application Support/devseal`, and listens on `127.0.0.1` via `socat`. Decryption uses `age-plugin-se` and `~/.config/age/se-identity.txt`.
2. **Dev Container** — bind-mounts that Application Support directory read-only at `/run/devseal`, and sets `DEVSEAL_HOST=host.docker.internal`.
3. **Container** — `./devseal/unseal.sh` reads port/token, sends the ciphertext over TCP, and prints plaintext to stdout (typically `source <(./devseal/unseal.sh)`).

Plaintext is streamed; neither side writes a temp secrets file.

## Dev Container patch

Merge into `.devcontainer/devcontainer.json`:

```json
{
  "mounts": [
    "source=${localEnv:HOME}/Library/Application Support/devseal,target=/run/devseal,type=bind,readonly"
  ],
  "containerEnv": {
    "DEVSEAL_HOST": "host.docker.internal"
  }
}
```

Rebuild or reopen the Dev Container after changing mounts.

## Mac one-time setup

```sh
brew install age age-plugin-se
mkdir -p ~/.config/age
age-plugin-se keygen \
  --access-control=any-biometry \
  -o ~/.config/age/se-identity.txt
```

Commit the **public** key as `recipients.txt` next to `secrets.env.age` (one `age1se…` line per recipient). Never commit `se-identity.txt`.

## Encrypt / rotate (Mac)

```sh
age -R recipients.txt -o secrets.env.age secrets.env
```

Paths are examples — use the repo paths chosen at install time. Keep plaintext `secrets.env` gitignored.

## Wire protocol

One TCP connection per request. No HTTP.

**Request:** `Bearer <token>\n` + `<byte-length>\n` + ciphertext bytes

**Response:** plaintext bytes, or `ERR <message>\n`

Auth failures and decrypt failures return `ERR …` lines; `unseal.sh` maps those to a non-zero exit.

## Env overrides

| **Variable**          | **Default**                               | **Role**                                |
|-----------------------|-------------------------------------------|-----------------------------------------|
| `DEVSEAL_HOST`        | `host.docker.internal`                    | Host reachable from the container       |
| `DEVSEAL_DIR`         | `/run/devseal`                            | Directory with `port` and `token`       |
| `DEVSEAL_IDENTITY`    | `~/.config/age/se-identity.txt`           | Mac identity for `host.sh`              |

## Troubleshooting

| **Symptom**                                         | **Likely cause**                                                     |
| :-------------------------------------------------- | :-------------------------------------------------------------------- |
| devseal config not found under `/run/devseal`       | Host not serving, or Dev Container missing the mount/needs rebuild    |
| Cannot connect to devseal at host:port              | `host.sh serve` not running, or `DEVSEAL_HOST` is wrong              |
| `ERR unauthorized`                                  | Stale token (restart serve; reopen container if mount cached oddly)   |
| `ERR decryption failed`                             | Wrong identity, or ciphertext not encrypted to this recipient         |
| `host.sh` refuses non-Darwin                        | Serve/decrypt only runs on macOS                                      |
