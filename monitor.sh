#!/usr/bin/env bash
set -euo pipefail

AGENT_HOME="${AGENT_HOME:-/home/agent-admin/agent-app}"
AGENT_PORT="${AGENT_PORT:-15034}"
AGENT_LOG_DIR="${AGENT_LOG_DIR:-/var/log/agent-app}"
LOG_FILE="$AGENT_LOG_DIR/monitor.log"
APP_NAME="agent-app"
MAX_LOG_SIZE=$((10 * 1024 * 1024))
MAX_LOG_FILES=10

mkdir -p "$AGENT_LOG_DIR" 2>/dev/null || true

timestamp() {
  date '+%Y-%m-%d %H:%M:%S'
}

warn() {
  echo "[WARNING] $1"
}

rotate_logs() {
  if [[ -f "$LOG_FILE" && $(stat -c%s "$LOG_FILE") -ge $MAX_LOG_SIZE ]]; then
    local rotated="${LOG_FILE}.$(date '+%Y%m%d%H%M%S')"
    mv "$LOG_FILE" "$rotated"
    gzip -f "$rotated"
  fi

  local files
  mapfile -t files < <(ls -1t "${LOG_FILE}."*.gz 2>/dev/null || true)
  if [[ ${#files[@]} -gt $MAX_LOG_FILES ]]; then
    for idx in "${!files[@]}"; do
      if [[ $idx -ge $MAX_LOG_FILES ]]; then
        rm -f "${files[$idx]}"
      fi
    done
  fi
}

check_process() {
  local pid
  pid=$(pgrep -f "/usr/local/bin/${APP_NAME}" || pgrep -x "${APP_NAME}" || pgrep -f "${APP_NAME}" | head -n 1 || true)
  if [[ -z "$pid" ]]; then
    echo "[HEALTH CHECK] Checking process '${APP_NAME}'... [FAIL]"
    exit 1
  fi
  echo "[HEALTH CHECK] Checking process '${APP_NAME}'... [OK] (PID: $pid)"
  echo "$pid"
}

check_port() {
  if ss -tlnp 2>/dev/null | grep -E "LISTEN.+:${AGENT_PORT}\\b" >/dev/null 2>&1; then
    echo "[HEALTH CHECK] Checking port ${AGENT_PORT}... [OK]"
  else
    echo "[HEALTH CHECK] Checking port ${AGENT_PORT}... [FAIL]"
    exit 1
  fi
}

check_firewall() {
  if command -v ufw >/dev/null 2>&1; then
    if ufw status | grep -qi 'Status: active'; then
      echo "[HEALTH CHECK] Firewall status: UFW active"
    else
      warn "Firewall is not active (UFW)"
    fi
  elif command -v firewall-cmd >/dev/null 2>&1; then
    if firewall-cmd --state >/dev/null 2>&1; then
      echo "[HEALTH CHECK] Firewall status: firewalld active"
    else
      warn "Firewall is not active (firewalld)"
    fi
  else
    warn "No supported firewall tool found"
  fi
}

collect_resources() {
  local cpu_usage mem_total mem_avail mem_usage disk_used

  # Robust CPU calculation using 1-second sampling delta
  local stat1 stat2
  stat1=$(head -n 1 /proc/stat)
  sleep 1
  stat2=$(head -n 1 /proc/stat)

  cpu_usage=$(awk -v s1="$stat1" -v s2="$stat2" '
    BEGIN {
      split(s1, a1);
      split(s2, a2);
      idle1 = a1[5] + a1[6];
      total1 = a1[2] + a1[3] + a1[4] + a1[5] + a1[6] + a1[7] + a1[8] + a1[9] + a1[10] + a1[11];
      idle2 = a2[5] + a2[6];
      total2 = a2[2] + a2[3] + a2[4] + a2[5] + a2[6] + a2[7] + a2[8] + a2[9] + a2[10] + a2[11];
      diff_idle = idle2 - idle1;
      diff_total = total2 - total1;
      if (diff_total > 0) {
        printf "%.1f", 100 * (1 - diff_idle / diff_total);
      } else {
        printf "0.0";
      }
    }
  ')

  mem_total=$(awk '/MemTotal:/ {print $2}' /proc/meminfo)
  mem_avail=$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)
  mem_usage=$(awk "BEGIN { printf \"%.1f\", 100 * (1 - ($mem_avail / $mem_total)) }")
  disk_used=$(df -P / | awk 'NR==2 {gsub(/%/, "", $5); print $5}')

  echo "[RESOURCE MONITORING]"
  echo "CPU Usage : ${cpu_usage}%"
  echo "MEM Usage : ${mem_usage}%"
  echo "DISK Used  : ${disk_used}%"

  if [ "$(echo "$cpu_usage > 20" | bc)" -eq 1 ]; then
      echo "[WARN] CPU threshold exceeded: (${cpu_usage}% > 20%)"
  fi
  
  if [ "$(echo "$mem_usage > 10" | bc)" -eq 1 ]; then
      echo "[WARN] MEM threshold exceeded: (${mem_usage}% > 10%)"
  fi
  if [ "$(echo "$disk_used > 80" | bc)" -eq 1 ]; then
    warn "DISK_USED threshold exceeded (${disk_used}% > 80%)"
  fi

  rotate_logs
  printf '[%s] PID:%s CPU:%s%% MEM:%s%% DISK_USED:%s%%\n' "$(timestamp)" "$1" "$cpu_usage" "$mem_usage" "$disk_used" >> "$LOG_FILE"
  echo "[INFO] Log appended: $LOG_FILE"
}

main() {
  echo "====== SYSTEM MONITOR RESULT ======"
  local pid
  pid=$(check_process | tail -n 1)
  check_port
  check_firewall
  collect_resources "$pid"
}

main
