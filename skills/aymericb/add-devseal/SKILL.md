---
name: add-devseal
description: Add the devseal scripts to support encrypted secrets in containers that require touch ID interaction on host before use.
disable-model-invocation: true
---

# Add devseal

This skill installs scripts in a `devseal` directory, which are used to support encrypted secrets via age, that can only be decrypted using the `age-plugin-se` and secure enclave on the host Mac.

Templates live beside this file under [`templates/`](templates/).

For wire protocol and Mac age setup detail, see [`reference.md`](reference.md).

## Purpose

The purpose of `devseal` is to ensure the following security model:
- The secrets are always encrypted at rest
- The secrets are temporarily retrieved in the context of a dev container
- The secrets can only be decrypted with user interaction, using Touch ID, on the host
- The key is stored in the secure enclave which would make "caching" future interaction difficult to achieve

The deployment of devseal assumes that:
- The main environment that is used in a Linux Dev Containers
- The encrypted files is a simple encrypted `.env` file, that can briefly used via `source` to obtain credentials
- The decryption would be done by a human operator (not an AI agent), and the context would be terminated afterwards
- The host is a Mac, with both `age` and the `age-plugin-se` installed

## Process

### 1. Explore

Look at the target repo. Read what exists; don't assume:

- `.devcontainer/devcontainer.json` (or nested Dev Container configs) — **required**. If missing, stop: a Dev Container is a prerequisite.
- Existing `devseal/` — already installed?
- Existing `*.env.age`, `recipients.txt`, plaintext `secrets.env` locations
- `.gitignore` (or directory-local ignore) coverage for plaintext `secrets.env`
- Platform assumption: macOS host with Secure Enclave (scripts refuse non-Darwin)

**Done when:** you can state whether a Dev Container exists, whether devseal is already present, and where (if anywhere) encrypted secrets already live.

### 2. Present findings and ask

Use exploration only to **prefill recommendations**. Always present the full plan for confirmation, even when defaults seem obvious.

The only exception: the user already stated a preference earlier in this conversation — quote it back when applying it.

Summarise what's present and what's missing, then ask using **AskQuestion** when available (otherwise ask conversationally). Prefill the recommended option in each question:

  | Question                              | Options                                                        |
  |---------------------------------------|----------------------------------------------------------------|
  | Where should `secrets.env.age` live?  | `secrets/secrets.env.age` (default), `terraform/secrets.env.age`, custom path |
  | Where should `devseal/` be installed? | repo root (default), other                                     |
  | Wire Dev Container mount + `DEVSEAL_HOST`? | yes (default), no                                         |
  | Encrypt now?                          | scaffold only (default), encrypt now (Mac steps)               |

Recommendation rules (for prefilling, not for skipping confirmation):
- **Secrets path** — default `secrets/secrets.env.age`. If a `terraform/` layout already exists, prefer `terraform/secrets.env.age`.
- **Recipients file** — sibling `recipients.txt` next to the age file.
- **Install `devseal/` at repo root** — yes.
- **Wire Dev Container mount + `DEVSEAL_HOST`** — yes.
- **Encrypt now** — only if the user already has a plaintext `secrets.env` (or is ready to paste values). Otherwise scaffold ignore + encrypt docs and leave ciphertext for later.

Also show this summary and **wait for explicit approval** before step 3:

```markdown
## Proposed devseal layout

| Item                  | Path                        |
|-----------------------|-----------------------------|
|   devseal scripts     |   `devseal/` (repo root)    |
|   Encrypted secrets   |   `<chosen path>`           |
|   Recipients          |   `<sibling recipients.txt>`|
|   Plaintext (gitignored) | `<sibling secrets.env>`  |
|   Dev Container       |   mount + `DEVSEAL_HOST`    |

Reply to proceed, or tell me what to change.
```

Acceptable approval: "yes", "looks good", "proceed", or choosing options via AskQuestion.

**Done when:** the user has explicitly approved the proposed layout (or chosen options via AskQuestion). Exploration-only defaults do **not** satisfy this.

### Gate — do not write until confirmed

**STOP after presenting the plan.** Do not copy templates, patch `devcontainer.json`, or create `.gitignore` entries until the user explicitly approves the layout.

If the user wants changes, update the plan and ask again. Never infer approval from exploration alone.

### 3. Write

1. Copy [`templates/host.sh`](templates/host.sh), [`templates/unseal.sh`](templates/unseal.sh), [`templates/README.md`](templates/README.md), and [`templates/cheat.txt`](templates/cheat.txt) into `devseal/` at the repo root.
2. In both scripts, replace `__SECRETS_RELPATH__` with the path to `secrets.env.age` **relative to `devseal/`** (e.g. `../secrets/secrets.env.age`). Both scripts must use the same value.
3. In `devseal/README.md`, replace `__SECRETS_PATH__` and `__RECIPIENTS_PATH__` with the repo-relative paths chosen above.
4. `chmod +x devseal/host.sh devseal/unseal.sh`.
5. Patch Dev Container JSON — merge, don't clobber existing `mounts` / `containerEnv`:
   - Mount: `source=${localEnv:HOME}/Library/Application Support/devseal,target=/run/devseal,type=bind,readonly`
   - Env: `DEVSEAL_HOST` = `host.docker.internal`
6. Ensure plaintext is gitignored: directory-local `.gitignore` next to the age file containing `secrets.env`.
7. If `recipients.txt` is missing: do not invent a key. Document the Mac one-time `age-plugin-se keygen` steps (see [reference.md](reference.md)); the public key must be committed as `recipients.txt`.
8. If encrypting now: instruct the human (on the Mac) to run `age -R <recipients> -o <secrets.env.age> secrets.env`. Do not run Touch ID decryption from inside the Linux container yourself.

**Done when:** `devseal/` scripts exist with matching `SECRETS_FILE`, Dev Container mount/env are present, and plaintext is ignored.

### 4. Verify

- Dev Container JSON is valid JSON; mount and `DEVSEAL_HOST` are present
- Both scripts resolve the same `SECRETS_FILE` (no leftover `__SECRETS_RELPATH__`)
- Plaintext `secrets.env` is ignored; `*.age` and `recipients.txt` are tracked (or explicitly noted if the user chose otherwise)
- Hand the user the remaining **human-only** Mac steps: brew install `age` + `age-plugin-se`, keygen if needed, `./devseal/host.sh serve`, rebuild/reopen Dev Container so the mount appears, then `source <(./devseal/unseal.sh)` inside the container

**Done when:** checklist above passes and the user has the Mac follow-ups.

## Do not

- Proceed to Write without explicit user approval of devseal location and secrets paths
- Treat repo exploration (e.g. finding `terraform/`) as confirmation
- Replace or generalize Dev Container itself
- Move the SE identity into the container
- Run `host.sh serve` from inside Linux (macOS-only)
- Commit plaintext secrets
