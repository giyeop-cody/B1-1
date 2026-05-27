# SSH 및 방화벽(UFW) 설정 증거

### SSH 포트·루트로그인·비밀번호인증 설정 확인

**명령어**

```bash
grep -E '^Port |^PermitRootLogin |^PasswordAuthentication ' /etc/ssh/sshd_config || grep -E 'Port|PermitRootLogin|PasswordAuthentication' /etc/ssh/sshd_config
```

**결과**

```
Port 20022
PermitRootLogin no
PasswordAuthentication no
```

### UFW 방화벽 상태 상세 확인 (기본 정책 및 허용 포트)

**명령어**

```bash
ufw status verbose
```

**결과**

```
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), deny (routed)
New profiles: skip

To                         Action      From
--                         ------      ----
20022/tcp                  ALLOW IN    Anywhere                  
15034/tcp                  ALLOW IN    Anywhere                  
20022/tcp (v6)             ALLOW IN    Anywhere (v6)             
15034/tcp (v6)             ALLOW IN    Anywhere (v6)             

```

### UFW 기본(Default) 정책 요약

**명령어**

```bash
ufw status verbose | grep -E 'Default:|Status:' || true
```

**결과**

```
Status: active
Default: deny (incoming), allow (outgoing), deny (routed)
```

