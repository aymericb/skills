---
name: setup-sfw
description: Route npm and/or cargo through Socket Firewall (sfw) in a Dev Container, installed via mise or a global npm install.
disable-model-invocation: true
---

# Setup Socket Firewall

Installs [Socket Firewall](https://www.npmjs.com/package/sfw) (`sfw`) into the repo's Dev Container and aliases `npm` / `cargo` to `sfw npm` / `sfw cargo` in interactive shells, so package installs are screened before they hit disk.

Templates live beside this file under [`templates/`](templates/):

- [`sfw-shell.mise.sh`](templates/sfw-shell.mise.sh): shell file when sfw comes from mise; aliases come from mise `[shell_alias]`.
- [`sfw-shell.global.sh`](templates/sfw-shell.global.sh): shell file when sfw is a global npm install; defines the aliases itself.
- [`post-create.snippet.sh`](templates/post-create.snippet.sh): idempotently sources the shell file from `~/.bashrc`.

Both shell files define `sfw-check`, which prints `Socket Firewall: <tools> aliases active` or `inactive (<what's missing>)`, and run it when a terminal opens inside the workspace.

## Process

### 1. Explore

Read what exists; don't assume:

- `.devcontainer/devcontainer.json` (or nested Dev Container configs) — **required**. If missing, stop: a Dev Container is a prerequisite.
- In it: `features` (mise feature `ghcr.io/devcontainers-extra/features/mise:1`, Node feature), `postCreateCommand`, `remoteEnv.PATH`, `workspaceFolder`.
- The post-create script, if `postCreateCommand` points at one.
- mise in use: `mise.toml` / `.mise.toml` present, or the mise feature is installed.
- Existing sfw setup: `npm:sfw` in mise `[tools]`, `[shell_alias]` entries, `.devcontainer/sfw-shell.sh`, `npm install -g sfw` anywhere.
- Ecosystems: `package.json` anywhere → npm; `Cargo.toml` anywhere → cargo.
- Commands that bypass shell aliases: mise tasks, scripts, and Dockerfiles invoking bare `npm install` / `npm ci` / `cargo build` / `cargo install` etc. Aliases only apply in interactive shells, so these need an explicit `sfw` prefix.

**Done when:** you can state, for each bullet above, what is present.

### 2. Present findings and ask

Summarise what's present and missing, then ask with **AskUserQuestion**, prefilling the recommended option from exploration. Always ask, even when the defaults look obvious; the only exception is a preference the user already stated in this conversation (quote it back).

| Question | Options |
|---|---|
| Install sfw how? | **mise** (`"npm:sfw"` in `[tools]`) — recommended when mise is in use; **global npm** (`npm install -g sfw` in post-create) — recommended otherwise |
| Set up shell aliases? | yes (default), no |
| Alias which tools? | npm + cargo, npm only, cargo only — prefill from the ecosystems found. Skip if aliases declined. |
| Prefix bypassing commands with `sfw`? | yes (default), no — only ask if step 1 found any; list them |

Then show the full change list and **wait for explicit approval**:

```markdown
## Proposed sfw setup

| Change | File |
|---|---|
| Install sfw via <mise / npm -g> | `<mise.toml / post-create script>` |
| Aliases: <npm/cargo> | `<mise.toml [shell_alias] / .devcontainer/sfw-shell.sh>` |
| Shell file + sfw-check | `.devcontainer/sfw-shell.sh` |
| Source from ~/.bashrc | `<post-create script>` |
| Dev Container wiring | `.devcontainer/devcontainer.json` (<what changes>) |
| sfw prefix on | `<files / tasks>` or none |
| Docs | `README.md` |

Reply to proceed, or tell me what to change.
```

**Done when:** the user has explicitly approved (or chosen options via AskUserQuestion and confirmed the table).

### Gate — do not write until confirmed

STOP after presenting the plan. Exploration-derived defaults are not approval.

### 3. Write

Merge into existing files; keep every unrelated setting, feature, mount and command.

**mise install:**

1. In `mise.toml` `[tools]`: add `node` (e.g. `node = "24"`) if absent, and `"npm:sfw" = { version = "latest", depends = ["node"] }`.
2. If aliases approved, add `[shell_alias]` entries for the chosen tools: `npm = "sfw npm"`, `cargo = "sfw cargo"`.
3. `devcontainer.json`: ensure the mise feature `"ghcr.io/devcontainers-extra/features/mise:1": {}` and `remoteEnv.PATH` = `/home/<remoteUser>/.local/share/mise/shims:${containerEnv:PATH}`.
4. Post-create script: ensure it runs `mise trust --all` then `mise install` before the alias snippet.
5. Shell template: `sfw-shell.mise.sh`.

**Global npm install:**

1. `devcontainer.json`: if Node isn't otherwise available in the image, add the feature `"ghcr.io/devcontainers/features/node:1": {}`.
2. Post-create script: run `npm install -g sfw`.
3. Shell template: `sfw-shell.global.sh`.

**Shell aliases (both paths, if approved):**

1. Copy the chosen template to `.devcontainer/sfw-shell.sh`. Replace `__SFW_TOOLS__` with the space-separated tool list (`npm cargo`, `npm`, or `cargo`) and `__WORKSPACE_FOLDER__` with `workspaceFolder` from `devcontainer.json` (default `/workspaces/<repo dir name>`).
2. Post-create script: if `postCreateCommand` already runs a script, append [`post-create.snippet.sh`](templates/post-create.snippet.sh) to it (adjust the `workspace_root` derivation if the script doesn't live in `.devcontainer/`). Otherwise create `.devcontainer/post-create.sh` (`#!/bin/bash`, `set -eu`, the install steps, then the snippet) and set `"postCreateCommand": ["bash", "${containerWorkspaceFolder}/.devcontainer/post-create.sh"]`. If `postCreateCommand` is an inline command, chain the new script after it rather than replacing it.

**Other:**

- If approved, prefix each bypassing command found in step 1 with `sfw` (e.g. `sfw npm ci`, `sfw cargo build --release`). Leave non-installing commands (`npm run dev`, `cargo fmt`) alone.
- Add a short README note: sfw is installed via <mise / npm -g>, and which commands are aliased.

**Done when:** every row of the approved table is applied.

### 4. Verify

- `devcontainer.json` still parses (strip comments if JSONC, e.g. `npx -y strip-json-comments-cli` or read it back carefully).
- `bash -n` passes on `.devcontainer/sfw-shell.sh` and the post-create script.
- `grep -rn '__SFW_TOOLS__\|__WORKSPACE_FOLDER__' .devcontainer` returns nothing.
- mise path: `mise ls npm:sfw` resolves after `mise install`.
- If currently inside the Dev Container, `bash -ic sfw-check` from the workspace prints `aliases active` (run the install and bashrc steps first; otherwise skip).
- Tell the user to rebuild the Dev Container and expect `Socket Firewall: <tools> aliases active` in a new terminal.

**Done when:** all checks pass or the user has been told which one couldn't run and why.
