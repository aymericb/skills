#!/usr/bin/env bash
# Lightweight "service" wrapper for T3 Code inside the dev container.
# The container has no systemd, so this supervises `t3 serve` in the
# background and restarts it if it exits.
set -euo pipefail

t3_host="${T3_HOST:-0.0.0.0}"
t3_port="${T3_PORT:-3773}"
t3_cwd="${T3_CWD:-__WORKSPACE_FOLDER__}"
t3_orb_host="${T3_ORB_HOST:-__CONTAINER_HOSTNAME__.orb.local}"
pid_file="/tmp/t3-service.pid"
log_file="/tmp/t3-serve.log"

isRunning() {
    [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null
}

start() {
    if isRunning; then
        echo "T3 service already running (pid $(cat "$pid_file"))"
        return 0
    fi
    if ! command -v t3 >/dev/null 2>&1; then
        echo "t3 is not installed; run: npm install --global t3" >&2
        return 1
    fi

    nohup setsid bash -c "
        while true; do
            # The npm launcher spawns a native t3 binary; if only the launcher
            # dies the binary keeps the port, so clear leftovers in our group.
            pkill -g \$\$ -f '[@]t3code/t3-' 2>/dev/null && sleep 1
            echo \"[\$(date -Is)] starting t3 serve on ${t3_host}:${t3_port}\"
            t3 serve --mode web --host '${t3_host}' --port '${t3_port}' --no-browser '${t3_cwd}' || true
            echo \"[\$(date -Is)] t3 serve exited; restarting in 2s\"
            sleep 2
        done
    " >>"$log_file" 2>&1 </dev/null &
    echo $! >"$pid_file"
    echo "T3 service started (pid $!), logging to $log_file"
}

stop() {
    if ! isRunning; then
        echo "T3 service not running"
        rm -f "$pid_file"
        return 0
    fi
    kill -- "-$(cat "$pid_file")" 2>/dev/null || true
    rm -f "$pid_file"
    echo "T3 service stopped"
}

status() {
    if isRunning; then
        echo "T3 service running (pid $(cat "$pid_file")) on ${t3_host}:${t3_port}"
    else
        echo "T3 service not running"
    fi
    echo "Log: $log_file"
    return 0
}

# Start the service if needed, then print the most recent pairing token/URL.
pair() {
    local offset=0
    if ! isRunning; then
        offset=$(stat -c %s "$log_file" 2>/dev/null || echo 0)
        start
    fi
    local deadline=$((SECONDS + 30))
    until tail -c "+$((offset + 1))" "$log_file" 2>/dev/null | grep -q '^Pairing URL:'; do
        if [ "$SECONDS" -ge "$deadline" ]; then
            echo "Timed out waiting for pairing URL; see $log_file" >&2
            return 1
        fi
        sleep 0.5
    done
    local lines
    lines=$(tail -c "+$((offset + 1))" "$log_file" | grep -E '^(Token|Pairing URL):' | tail -n 2)
    echo "$lines"
    echo "$lines" | sed -nE "s#^Pairing URL: (https?://)[^:/]+#OrbStack URL: \1${t3_orb_host}#p"
}

case "${1:-start}" in
    start) start ;;
    stop) stop ;;
    restart) stop; sleep 1; start ;;
    status) status ;;
    pair) pair ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|pair}" >&2
        exit 1
        ;;
esac
