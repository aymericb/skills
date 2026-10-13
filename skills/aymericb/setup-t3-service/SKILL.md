---
name: setup-t3-service
description: Set up T3 Code (`t3 serve`) as an auto-starting background service inside a project's Dev Container — installs t3 globally in post-create, adds a supervised t3-service.sh, wires postStartCommand, and persists ~/.t3 state. Use when asked to add, install or set up the t3 / T3 Code service in a dev container.
---

# Set up the T3 Code service in a Dev Container

Dev Containers have no systemd, so this skill installs a small supervisor script
(`.devcontainer/t3-service.sh`) that runs `t3 serve` in the background, restarts
it when it exits, and is launched by `postStartCommand`. T3 state (`~/.t3`) is
persisted on the host through a bind mount under `.state/t3`.

Templates live next to this file in `templates/`:

- `t3-service.sh` — the service wrapper (`start|stop|restart|status|pair`)
- `post-create.sh` — minimal post-create script, used only if the project has none
- `create-state.sh` — minimal host-side state directory script, used only if the project has none

**Do not modify any file until the user has approved the plan (step 3).**

## 1. Inspect the project

Read, without changing anything:

- `.devcontainer/devcontainer.json` (or `.devcontainer.json`): `name`, `runArgs`
  (`--hostname`, `--name`), `workspaceFolder`, `mounts`, `postCreateCommand`,
  `postStartCommand`, `initializeCommand`, `remoteUser`.
- `.devcontainer/post-create.sh` (or whatever `postCreateCommand` points to).
- `.devcontainer/create-state.sh` (or whatever creates the `.state` dirs, often
  `initializeCommand`).
- `.devcontainer/t3-service.sh` if it already exists.
- `.gitignore` — is `.state/` ignored?
- Every `package.json` in the repo (skip `node_modules`): is `t3` listed in
  `dependencies`, `devDependencies`, or invoked from `scripts`?

Derive the project-specific values:

| Placeholder               | Source                                                                                                          | Example (Googs)       |
| ------------------------- | --------------------------------------------------------------------------------------------------------------- | --------------------- |
| `__WORKSPACE_FOLDER__`    | `workspaceFolder`, else `/workspaces/<repo-dir-name>`                                                           | `/workspaces/Googs`   |
| `__CONTAINER_HOSTNAME__`  | `--hostname` in `runArgs`, else `--name`, else devcontainer `name` lower-cased and dash-separated               | `googs-dev`           |
| Remote user home          | `/home/<remoteUser>` (default `node` for the typescript-node images)                                            | `/home/node`          |

If a value cannot be determined, ask the user rather than guessing.

## 2. Build the plan

Work out exactly which of these changes are needed (skip anything already in place):

1. **Global install** — ensure `npm install --global t3` is in the post-create script.
   - If a post-create script exists, append the line (after any other global installs).
   - If `postCreateCommand` is an inline command, propose either appending
     `&& npm install --global t3` or converting it into a `.devcontainer/post-create.sh`.
   - If there is no post-create step at all, **propose** creating
     `.devcontainer/post-create.sh` from `templates/post-create.sh` and setting
     `"postCreateCommand": ".devcontainer/post-create.sh"`.
2. **Service script** — create `.devcontainer/t3-service.sh` from
   `templates/t3-service.sh`, replacing `__WORKSPACE_FOLDER__` and
   `__CONTAINER_HOSTNAME__`, and `chmod +x` it. If one already exists, show the diff
   against the rendered template and ask before overwriting.
3. **Auto start** — set `"postStartCommand": ".devcontainer/t3-service.sh"` in
   `devcontainer.json`. If a `postStartCommand` already exists, propose chaining
   (`"<existing> && .devcontainer/t3-service.sh"`) or converting it to the object
   form (`{ "app": "<existing>", "t3": ".devcontainer/t3-service.sh" }`).
4. **State directory** — ensure `"$state_dir/t3"` is created by `create-state.sh`
   (add it to the existing `mkdir -p` list, keeping the `\` continuation style).
   If no such script exists, propose creating `.devcontainer/create-state.sh` from
   `templates/create-state.sh` and wiring it as
   `"initializeCommand": ".devcontainer/create-state.sh"` (runs on the host,
   before the bind mount needs the directory to exist).
5. **State mount** — ensure `mounts` contains
   `"source=${localWorkspaceFolder}/.state/t3,target=<home>/.t3,type=bind"`.
6. **Git ignore** — ensure `.state/` is in `.gitignore`.

## 3. Summarize and wait for approval

Present the plan to the user before touching anything. For every file list:
create / modify / unchanged, and show the exact lines to be added or changed
(a short diff or snippet). Include the derived values (workspace folder, hostname,
OrbStack URL `http://<hostname>.orb.local:3773`) so the user can correct them.

Then ask for approval with the AskUserQuestion tool (Approve / Change something /
Cancel). **Stop and wait.** Do not edit any file until the user approves. If they
ask for changes, update the plan and summarize again.

## 4. Ask separately about a package.json install

If step 1 found `t3` in any `package.json`, ask a **separate** question (its own
AskUserQuestion call, not bundled with the plan approval): name the file(s) and the
dependency entry, explain that the service uses the globally installed `t3` so the
local dependency is redundant, and ask whether to remove it. Only if the user says
yes, remove it with `npm uninstall t3` run in that package's directory (so the
lockfile is updated too). If they say no, leave it alone.

## 5. Apply

Apply only the approved changes, preserving each file's existing formatting
(indentation, quotes, trailing commas). Keep shell scripts executable.

## 6. Verify and report

- `bash -n .devcontainer/t3-service.sh` (and any other script touched).
- Validate `devcontainer.json` still parses (it is JSONC; strip comments if needed).
- If running inside the dev container and `t3` is installed, optionally offer to run
  `.devcontainer/t3-service.sh start` then `.devcontainer/t3-service.sh status`.
  If `t3` is not installed yet, say the service will start after the container is
  rebuilt.
- Tell the user:
  - Rebuild the container for the post-create, mount and `postStartCommand` changes
    to take effect.
  - Make sure `.state/t3` exists on the host before rebuilding (run `create-state.sh`
    if it is not wired as `initializeCommand`).
  - Useful commands: `.devcontainer/t3-service.sh {start|stop|restart|status|pair}`;
    `pair` prints the pairing token/URL plus the OrbStack URL. Logs are in
    `/tmp/t3-serve.log`.
  - Settings can be overridden with `T3_HOST`, `T3_PORT`, `T3_CWD`, `T3_ORB_HOST`.
