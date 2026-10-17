# Sourced by interactive Bash terminals in the Dev Container.
if [[ $- == *i* ]]; then
    sfw_tools=(__SFW_TOOLS__)
    for sfw_tool in "${sfw_tools[@]}"; do
        alias "$sfw_tool=sfw $sfw_tool"
    done
    unset sfw_tool

    sfw-check() {
        local missing=() tool

        if ! command -v sfw >/dev/null 2>&1 || ! sfw --version >/dev/null 2>&1; then
            missing+=(sfw)
        fi
        for tool in "${sfw_tools[@]}"; do
            if [[ $(alias "$tool" 2>/dev/null) != "alias $tool='sfw $tool'" ]]; then
                missing+=("$tool-alias")
            fi
        done

        if ((${#missing[@]} == 0)); then
            printf 'Socket Firewall: %s aliases active\n' "$(IFS=/; echo "${sfw_tools[*]}")"
        else
            printf 'Socket Firewall: inactive (%s)\n' "${missing[*]}"
            return 1
        fi
    }

    case "$PWD/" in
        __WORKSPACE_FOLDER__/*) sfw-check ;;
    esac
fi
