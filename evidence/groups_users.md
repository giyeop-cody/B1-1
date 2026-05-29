# 계정 및 그룹 설정 증거

### 사용자 계정 및 그룹 멤버십 확인

**명령어**

```bash
id agent-admin && id agent-dev && id agent-test
```

**결과**

```
uid=1000(agent-admin) gid=999(agent-common) groups=999(agent-common),998(agent-core)
uid=1001(agent-dev) gid=999(agent-common) groups=999(agent-common),998(agent-core)
uid=1002(agent-test) gid=999(agent-common) groups=999(agent-common)
```

### 그룹 멤버 목록 확인

**명령어**

```bash
getent group agent-common && getent group agent-core
```

**결과**

```
agent-common:x:999:agent-test
agent-core:x:998:agent-admin,agent-dev
```

