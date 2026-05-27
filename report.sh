#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="${1:-/var/log/agent-app/monitor.log}"
START_TIME="${2:-}"
END_TIME="${3:-}"

if [[ ! -f "$LOG_FILE" ]]; then
  echo "Log file not found: $LOG_FILE"
  exit 1
fi

awk -v start="$START_TIME" -v end="$END_TIME" '
function between(ts) {
  return ((start == "" || ts >= start) && (end == "" || ts <= end));
}
BEGIN {
  count = 0;
  cpu_sum = mem_sum = disk_sum = 0;
  cpu_max = mem_max = disk_max = -1;
  cpu_min = mem_min = disk_min = 1e12;
}
{
  cpu = mem = disk = "";
  if (match($0, /\[[^\]]+\]/)) {
    ts = substr($0, RSTART + 1, RLENGTH - 2);
    if (match($0, /CPU:([0-9.]+)%/, m) && match($0, /MEM:([0-9.]+)%/, n) && match($0, /DISK_USED:([0-9.]+)%/, o)) {
      cpu = m[1] + 0;
      mem = n[1] + 0;
      disk = o[1] + 0;
      if (between(ts)) {
        count++;
        cpu_sum += cpu;
        mem_sum += mem;
        disk_sum += disk;
        if (cpu > cpu_max) { cpu_max = cpu; cpu_max_ts = ts; }
        if (cpu < cpu_min) { cpu_min = cpu; cpu_min_ts = ts; }
        if (mem > mem_max) { mem_max = mem; mem_max_ts = ts; }
        if (mem < mem_min) { mem_min = mem; mem_min_ts = ts; }
        if (disk > disk_max) { disk_max = disk; disk_max_ts = ts; }
        if (disk < disk_min) { disk_min = disk; disk_min_ts = ts; }
      }
    }
  }
}
END {
  if (count == 0) {
    print "No matching samples found.";
    exit 1;
  }
  printf "====== STATISTICS REPORT ======\n";
  printf "Samples : %d\n", count;
  printf "[CPU]\n";
  printf "Average : %.1f%%\n", cpu_sum / count;
  printf "Maximum : %.1f%% at %s\n", cpu_max, cpu_max_ts;
  printf "Minimum : %.1f%% at %s\n", cpu_min, cpu_min_ts;
  printf "[MEMORY]\n";
  printf "Average : %.1f%%\n", mem_sum / count;
  printf "Maximum : %.1f%% at %s\n", mem_max, mem_max_ts;
  printf "Minimum : %.1f%% at %s\n", mem_min, mem_min_ts;
  printf "[DISK]\n";
  printf "Average : %.1f%%\n", disk_sum / count;
  printf "Maximum : %.1f%% at %s\n", disk_max, disk_max_ts;
  printf "Minimum : %.1f%% at %s\n", disk_min, disk_min_ts;
}
' "$LOG_FILE"
