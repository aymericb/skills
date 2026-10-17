# Sourced by interactive Bash terminals in the Dev Container.
if [[ $- == *i* ]] && command -v mise >/dev/null 2>&1; then
    # MISE_SHELL is exported, so it can leak in from a parent process without
    # the hook functions; check for the hook itself instead.
    if ! declare -F _mise_hook >/dev/null; then
        eval "$(mise activate bash)"
    fi
    # [shell_alias] entries are applied by hook-env, which normally first runs
    # at the prompt; run it now so the aliases exist before sfw-check.
    eval "$(mise hook-env -s bash)"

    sfw-check() {
        local tools=(__SFW_TOOLS__)
        local missing=() tool

        if ! mise which sfw >/dev/null 2>&1 || ! sfw --version >/dev/null 2>&1; then
            missing+=(sfw)
        fi
        for tool in "${tools[@]}"; do
            if [[ $(alias "$tool" 2>/dev/null) != "alias $tool='sfw $tool'" ]]; then
                missing+=("$tool-alias")
            fi
        done

        if ((${#missing[@]} == 0)); then
            printf 'Socket Firewall: %s aliases active\n' "$(IFS=/; echo "${tools[*]}")"
        else
            printf 'Socket Firewall: inactive (%s)\n' "${missing[*]}"
            return 1
        fi
    }

    case "$PWD/" in
        __WORKSPACE_FOLDER__/*) sfw-check ;;
    esac
fi
