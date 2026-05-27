# 로그 보존 정책 증거

### logrotate 설정 파일 내용 (daily 회전 / 30개 보관)

**명령어**

```bash
cat /etc/logrotate.d/agent-app
```

**결과**

```
/var/log/agent-app/*.log {
    daily
    missingok
    rotate 30
    compress
    copytruncate
    notifempty
    dateext
    dateformat -%Y%m%d%H%M%S
    olddir /var/log/monitor/agent-app/archive
    create 640 agent-admin agent-core
    sharedscripts
    postrotate
        install -d -m 750 -o agent-admin -g agent-core /var/log/monitor/agent-app/archive
    endscript
}
```

### agent-log-retention.sh 스크립트 내용 (7일 압축 / 30일 삭제)

**명령어**

```bash
cat /usr/local/bin/agent-log-retention.sh
```

**결과**

```
#!/usr/bin/env bash
set -euo pipefail

ARCHIVE_DIR=/var/log/monitor/agent-app/archive
LOG_DIR=/var/log/agent-app

mkdir -p ""
chown agent-admin:agent-core ""
chmod 750 ""

find "" -maxdepth 1 -type f -name '*.log' -mtime +6 -print0 | while IFS= read -r -d '' file; do
    gzip -f ""
    mv -f ".gz" "/"
done

find "" -maxdepth 1 -type f -name '*.gz' -mtime +29 -print0 | xargs -0 rm -f -- || true
```

### 크론탭에 등록된 로그 보존 정책 실행 스케줄 확인

**명령어**

```bash
crontab -u agent-admin -l | grep -E '/home/agent-admin/agent-app/bin/monitor.sh|agent-log-retention.sh' || true
```

**결과**

```
* * * * * /home/agent-admin/agent-app/bin/monitor.sh >/dev/null 2>&1
0 0 * * * /usr/local/bin/agent-log-retention.sh >/dev/null 2>&1
```

