# 디렉토리 권한 및 ACL 증거

### 디렉토리 소유자·권한 확인 (ls -ld)

**명령어**

```bash
ls -ld /home/agent-admin/agent-app /home/agent-admin/agent-app/upload_files /home/agent-admin/agent-app/api_keys /var/log/agent-app
```

**결과**

```
drwxr-x--- 1 agent-admin agent-common 22 May 27 12:45 /home/agent-admin/agent-app
drwxr-x--- 1 agent-admin agent-core   44 May 27 14:17 /home/agent-admin/agent-app/api_keys
drwxr-x--- 1 agent-admin agent-common  0 May 27 12:45 /home/agent-admin/agent-app/upload_files
drwxr-x--- 1 agent-admin agent-core    0 May 27 12:45 /var/log/agent-app
```

### ACL(Access Control List) 상세 확인 (getfacl)

**명령어**

```bash
getfacl /home/agent-admin/agent-app/upload_files /home/agent-admin/agent-app/api_keys /var/log/agent-app 2>/dev/null || true
```

**결과**

```
# file: home/agent-admin/agent-app/upload_files
# owner: agent-admin
# group: agent-common
user::rwx
group::r-x
other::---

# file: home/agent-admin/agent-app/api_keys
# owner: agent-admin
# group: agent-core
user::rwx
group::r-x
other::---

# file: var/log/agent-app
# owner: agent-admin
# group: agent-core
user::rwx
group::r-x
other::---

```

