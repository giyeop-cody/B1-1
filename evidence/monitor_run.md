# monitor.sh 실행 결과 증거

### monitor.sh 수동 실행 (Health Check + 리소스 수집)

**명령어**

```bash
/home/agent-admin/agent-app/bin/monitor.sh
```

**결과**

```
====== SYSTEM MONITOR RESULT ======
[HEALTH CHECK] Checking port 15034... [OK]
[HEALTH CHECK] Firewall status: UFW active
[RESOURCE MONITORING]
CPU Usage : 0.7%
MEM Usage : 4.6%
DISK Used  : 1%
[INFO] Log appended: /var/log/agent-app/monitor.log
```

### monitor.log 최근 5라인 확인 (로그 누적 확인)

**명령어**

```bash
tail -n 5 /var/log/agent-app/monitor.log || true
```

**결과**

```
[2026-05-27 14:18:20] PID:271 CPU:0.7% MEM:4.6% DISK_USED:1%
```

