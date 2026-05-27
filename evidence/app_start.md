# 애플리케이션 부트 시퀀스 증거

### agent-app 백그라운드 기동 (agent-admin 계정)

**명령어**

```bash
su - agent-admin -c "cd /home/agent-admin/agent-app && env AGENT_HOME=/home/agent-admin/agent-app AGENT_PORT=15034 AGENT_UPLOAD_DIR=/home/agent-admin/agent-app/upload_files AGENT_KEY_PATH=/home/agent-admin/agent-app/api_keys AGENT_LOG_DIR=/var/log/agent-app nohup /usr/local/bin/agent-app > /home/agent-admin/agent-app/agent_app.log 2>&1 & echo \$!"
```

**결과**

```
269
```

### 포트 15034 LISTEN 상태 확인

**명령어**

```bash
ss -tlnp | grep -E ':15034\b' || true
```

**결과**

```
LISTEN 0      1            0.0.0.0:15034      0.0.0.0:*                                 
```

### Agent READY 및 Boot Checks Passed 확인

**명령어**

```bash
grep -E 'Agent READY|Listening at port 15034|Boot Checks Passed' /home/agent-admin/agent-app/agent_app.log || true
```

**결과**

```
All Boot Checks Passed!
Agent READY
```


## 부트 시퀀스 5단계 개별 검증

### Boot Sequence 5단계 전체 [OK] 확인

**명령어**

```bash
grep -E '^\[([1-5])/5\]' /home/agent-admin/agent-app/agent_app.log | grep '\[OK\]'
```

**결과**

```
[1/5] Checking User Account               [OK]
[2/5] Verifying Environment Variables     [OK]
[3/5] Checking Required Files             [OK]
[4/5] Checking Port Availability          [OK]
[5/5] Verifying Log Permission            [OK]
```

