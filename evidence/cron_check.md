# Cron 자동 실행 및 로그 누적 증거

### agent-admin 크론탭 등록 내용 확인

**명령어**

```bash
crontab -u agent-admin -l
```

**결과**

```
* * * * * /home/agent-admin/agent-app/bin/monitor.sh >/dev/null 2>&1
0 0 * * * /usr/local/bin/agent-log-retention.sh >/dev/null 2>&1
```

### monitor.log 최근 10라인 (크론 자동 실행 후 누적 확인)

**명령어**

```bash
tail -n 10 /var/log/agent-app/monitor.log
```

**결과**

```
[2026-05-27 14:18:20] PID:271 CPU:0.7% MEM:4.6% DISK_USED:1%
```

