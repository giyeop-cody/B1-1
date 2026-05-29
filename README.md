# B1-1: 리눅스 서버 운영 자동화 프로젝트

## 목차
1. [미션 개요](#미션-개요)
2. [최종 목표](#최종-목표)
3. [구현 내용](#구현-내용)
4. [실행 방법](#실행-방법)
5. [필수 증거 자료](#필수-증거-자료)
6. [평가 질문과 답변](#평가-질문과-답변)

---

## 미션 개요

이 프로젝트는 **다중 사용자 환경에서의 권한 관리**, **네트워크 보안 설정**, **시스템 모니터링 자동화**를 구현하는 과제입니다. Docker 기반 Ubuntu 22.04 컨테이너에서 실제 서버 운영에 필수적인 다음 요소들을 구축합니다:

- SSH 및 방화벽 보안 설정
- 역할 기반 계정/그룹 및 ACL 권한 체계
- 애플리케이션 배포 및 실행 환경 구성
- 시스템 리소스 모니터링 및 로그 자동화
- 로그 보존 정책 (압축/아카이브/삭제)

---

## 최종 목표

이 과제를 완료한 후 다음을 설명할 수 있어야 합니다:
- SSH 보안 설정이 기본 보안인 이유
- UFW 방화벽의 최소 권한 정책 구성
- 역할 기반 계정/그룹의 권한 분리
- 환경 변수로 실행 환경을 고정하는 이유
- 시스템 모니터링 데이터 수집 및 분석 흐름
- 로그 보존 정책의 필요성

---
## 실행 방법
`ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa.pub
cp ~/.ssh/rsa.pub ./id_rsa.pub
ssh -p 20022  사용자계정@서버주소

`



---

## 구현 내용

### 1. SSH 및 방화벽 설정

#### SSH 포트 변경 및 보안 설정 (Root 원격 로그인 차단 및 비밀번호 인증 비활성화)

**구현 위치**: Dockerfile (라인 98-102)

```bash
RUN sed -i 's/#Port 22/Port 20022/' /etc/ssh/sshd_config && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config || true && \
    sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config || true && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config || true && \
    sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config || true
```

**설명**:
- `Port 20022`: 기본 SSH 포트 22를 20022로 변경하여 무차별 자동 대입 공격(Brute Force)의 99% 이상을 방어합니다.
- `PermitRootLogin no`: 시스템 최고 권한을 가진 Root 계정의 직접 원격 로그인을 전면 차단합니다. 이를 통해 공격자가 계정명을 알아내어 접근하는 것을 불가능하게 만들고, 일반 계정으로 접속 후 `sudo` 권한을 이용하도록 강제하여 로그 감사 추적(Audit Trail)을 보장합니다.
- `PasswordAuthentication no`: 비밀번호를 통한 SSH 로그인을 금지하고, 미리 승인된 공개키/개인키 쌍(Key-based authentication)을 통한 접속만 허용합니다. 비밀번호 유출 및 사전 대입 공격을 원천 봉쇄하여 서버 보안 수준을 극대화합니다.

**확인 증거**: [evidence/ssh_firewall.md](evidence/ssh_firewall.md)

#### 방화벽(UFW) 및 네트워크 최소 권한 정책

**구현 위치**: Dockerfile (라인 104) 및 컨테이너 시작 CMD (라인 112)

```bash
RUN ufw default deny incoming && ufw default allow outgoing && ufw allow 20022/tcp && ufw allow 15034/tcp
```

**설명**:
- **최소 권한 네트워크 보안(Default Deny Incoming)**: 방화벽 기본 규칙으로 외부에서 컨테이너 내부로 들어오는 모든 미승인 인바운드 트래픽을 차단(`default deny incoming`)합니다. 
- **내부 시작 아웃바운드 허용(Default Allow Outgoing)**: 컨테이너 내부에서 시작하여 외부 네트워크로 나가는 요청은 정상적으로 작동(`default allow outgoing`)하도록 보장하여 원활한 패키지 업데이트 및 외부 API 연동을 지원합니다.
- **명시적 예외 규칙 추가**:
  - `TCP 20022 (SSH)`: 보안 가공된 관리자용 원격 제어 포트만 수용
  - `TCP 15034 (애플리케이션)`: 시스템 모니터링 수집기 포트만 수용
- **시작 시 강제 적용**: 빌드 시 정책 설정뿐 아니라 컨테이너 시작 시(`CMD`)에도 `ufw default deny incoming && ufw default allow outgoing && ufw --force enable`을 기동하여 환경 변화나 재시작 시에도 일관되고 신뢰성 있게 최소 권한 보안 정책이 활성화되도록 강제했습니다.

**확인 증거**: [evidence/ssh_firewall.md](evidence/ssh_firewall.md)

---

### 2. 사용자/그룹/권한 체계

#### 계정 및 그룹 생성

**구현 위치**: Dockerfile (라인 20-27)

```bash
RUN groupadd --system agent-common && \
    groupadd --system agent-core && \
    useradd --create-home ... agent-admin && \
    useradd --create-home ... agent-dev && \
    useradd --create-home ... agent-test
```

**계정 역할**:
- `agent-admin` (UID 1000): 운영자, cron 실행
- `agent-dev` (UID 1001): 개발자, 모니터 스크립트 작성
- `agent-test` (UID 1002): 테스터

**그룹 멤버십**:
- `agent-common` (GID 999): admin, dev, test
- `agent-core` (GID 998): admin, dev (민감 리소스)

**확인 증거**: [evidence/groups_users.md](evidence/groups_users.md)

#### 디렉토리 및 권한

**구현 위치**: Dockerfile (라인 28-33)

```bash
RUN chown -R agent-admin:agent-common $AGENT_HOME && \
    chown agent-admin:agent-common $AGENT_UPLOAD_DIR && chmod 770 $AGENT_UPLOAD_DIR && \
    chown agent-admin:agent-core $AGENT_HOME/api_keys && chmod 770 $AGENT_HOME/api_keys && \
    chown agent-admin:agent-core $AGENT_LOG_DIR && chmod 770 $AGENT_LOG_DIR
```

**권한 정책**:
- `upload_files` (770, `agent-common`): 모든 팀원 공유
- `api_keys` (770, `agent-core`): admin/dev만 접근 (민감 정보 보호)
- `/var/log/agent-app` (770, `agent-core`): admin/dev만 접근 (운영 로그)

**확인 증거**: [evidence/permissions.md](evidence/permissions.md)

#### 디렉토리 권한 및 ACL(Access Control List) 검증

역할 기반 접근 제어(RBAC) 및 보안 정책이 제대로 작동하고 있는지 검증하기 위해 POSIX 기본 권한(`ls -l`)과 확장 권한(`getfacl`)을 통해 상세 확인이 가능합니다.

**1) 파일 권한 및 소유자 확인 (`ls -l` / `ls -ld`)**
* `/home/agent-admin/agent-app/upload_files`: 소유자 `agent-admin`, 소유 그룹 `agent-common`, 권한 `770` (`drwxrwx---`)
* `/home/agent-admin/agent-app/api_keys`: 소유자 `agent-admin`, 소유 그룹 `agent-core`, 권한 `770` (`drwxrwx---`)
* `/var/log/agent-app`: 소유자 `agent-admin`, 소유 그룹 `agent-core`, 권한 `770` (`drwxrwx---`)

**2) ACL(Access Control List) 상세 구조 확인 (`getfacl`)**
컨테이너 내부에 `acl` 패키지를 설치하여 파일 시스템 수준에서 정교한 권한 검증을 제공합니다. 아래 명령어로 각각의 ACL 설정을 확인할 수 있습니다.

* **공유 업로드 디렉토리 (`upload_files`):**
  ```bash
  getfacl /home/agent-admin/agent-app/upload_files
  ```
  *예상 출력:*
  ```text
  # file: home/agent-admin/agent-app/upload_files
  # owner: agent-admin
  # group: agent-common
  user::rwx
  group::rwx
  other::---
  ```
  *(설명: `agent-common` 그룹에 속한 admin, dev, test 세 사용자 모두가 자유롭게 읽고 쓸 수 있는 공간을 제공합니다.)*

* **민감 정보 디렉토리 (`api_keys` 및 `/var/log/agent-app`):**
  ```bash
  getfacl /home/agent-admin/agent-app/api_keys
  getfacl /var/log/agent-app
  ```
  *예상 출력:*
  ```text
  # file: var/log/agent-app
  # owner: agent-admin
  # group: agent-core
  user::rwx
  group::rwx
  other::---
  ```
  *(설명: `agent-core` 그룹(admin, dev)만 읽고 쓰기가 가능하며, 테스트 담당 계정인 `agent-test` 등 외부 계정의 접근은 차단됩니다.)*

**확인 증거**: [evidence/permissions.md](evidence/permissions.md)

---

### 3. 애플리케이션 실행 환경

#### 환경 변수 설정

**구현 위치**: Dockerfile (라인 5-11)

```bash
ENV AGENT_HOME=/home/agent-admin/agent-app
ENV AGENT_PORT=15034
ENV AGENT_LOG_DIR=/var/log/agent-app
```

**목적**: 실행 환경의 일관성 보장

#### 바이너리 권한

**구현 위치**: Dockerfile (라인 83-87)

```bash
chmod 755 /usr/local/bin/agent-app
chown agent-admin:agent-common /usr/local/bin/agent-app
```

**의의**: 일반 계정(agent-admin)이 실행 가능 (Root 권한 불필요)

#### 앱 부트 시퀀스

**부트 시퀀스 5단계**:
1. User Account Check
2. Environment Variables Verification
3. Required Files Check (API 키)
4. Port Availability
5. Log Permission

**확인 증거**: [evidence/app_start.md](evidence/app_start.md)

---

### 4. 모니터링 스크립트: `monitor.sh`

#### 파일 정보

**위치**: `/home/agent-admin/agent-app/bin/monitor.sh`
- 소유자: `agent-dev`
- 그룹: `agent-core`
- 권한: `750` (rwxr-x---)

#### 주요 기능

**1) Health Check (장애 감지)**

프로세스 확인:
```bash
pgrep -f "${APP_NAME}(\\.py)?$" | head -n 1
```

포트 확인:
```bash
ss -tlnp | grep -E "LISTEN.+:${AGENT_PORT}\\b"
```

비정상 시 `exit 1`로 즉시 종료

**2) 상태 점검**

방화벽 활성화 여부 확인 (비정상 시 경고만 출력)

**3) 리소스 수집**

```bash
# CPU 사용률 (/proc/stat 기반)
awk 'NR==1 { idle1=$5+$6; total1=... } NR==2 { idle2=$5+$6; total2=... }' /proc/stat

# 메모리 사용률 (/proc/meminfo 기반)
awk '/MemTotal/ {total=$2} /MemAvailable/ {avail=$2}' /proc/meminfo

# 디스크 사용률 (df 기반)
df -P / | awk 'NR==2 {...}'
```

**4) 임계값 경고**

- CPU > 20%: `[WARNING]` 출력
- MEM > 10%: `[WARNING]` 출력
- DISK > 80%: `[WARNING]` 출력

**5) 로그 기록**

```bash
printf '[%s] PID:%s CPU:%s%% MEM:%s%% DISK_USED:%s%%\n' \
  "$(date '+%Y-%m-%d %H:%M:%S')" "$pid" "$cpu" "$mem" "$disk" >> "$LOG_FILE"
```

로그 포맷: `[2026-05-27 11:11:13] PID:243 CPU:0.0% MEM:4.4% DISK_USED:1%`

**확인 증거**: [evidence/monitor_run.md](evidence/monitor_run.md)

#### Cron 자동 실행

**구현**: Dockerfile (라인 103-106)

```bash
echo "* * * * * /home/agent-admin/agent-app/bin/monitor.sh >/dev/null 2>&1" | crontab -u agent-admin -
```

매분 자동 실행 → 로그 누적 기록

**확인 증거**: [evidence/cron_check.md](evidence/cron_check.md)

---

### 5. 리포트 생성: `report.sh`

#### 파일 정보

**위치**: `/home/agent-admin/agent-app/bin/report.sh`
- 소유자: `agent-dev`
- 그룹: `agent-core`
- 권한: `750`

#### 동작

**사용법**:
```bash
./report.sh [LOG_FILE] [START_TIME] [END_TIME]
```

**기능**:
- monitor.log 파싱 및 통계 계산
- CPU/MEM/DISK 평균/최대/최소 값 산출
- 샘플 개수 출력

**awk 로직**:
1. 각 라인에서 `[TIMESTAMP]`, `CPU`, `MEM`, `DISK_USED` 추출
2. 시간 범위 필터링 (시작/종료 시간 지정 시)
3. 누적값, 최대값, 최소값 계산
4. 포맷된 리포트 출력

**출력 예시**:
```
====== STATISTICS REPORT ======
Samples : 3
[CPU]
Average : 0.0%
Maximum : 0.0% at 2026-05-27 11:11:13
Minimum : 0.0% at 2026-05-27 11:11:13
```

**확인 증거**: [evidence/bonus_report.md](evidence/bonus_report.md)

---

### 6. 로그 보존 및 아카이빙 정책

시스템 로그 보존 및 관리를 위해 본 프로젝트는 **액티브 모니터링 크기 기반 회전**과 **배경 서비스 기간 기준 압축/아카이빙/삭제**의 상호보완적 이중 설계를 채택하였습니다.

#### 이중 로그 회전 설계 및 역할 분담 배경
- **크기 기반의 즉각적 로그 회전 (`monitor.sh` 내부):**
  - **역할**: 매 분 구동되는 모니터링 엔진에서 실행 로그 파일(`monitor.log`)의 크기를 즉각적으로 모니터링하여 `10MB`를 초과할 경우 즉시 회전시키고 최대 `10개`만 유지합니다.
  - **의도**: 일시적인 시스템 에러나 대량의 모니터링 출력으로 인해 단시간에 로그 파일이 임계값 이상으로 폭증하여 서버의 물리적 디스크를 고갈(Exhaustion)시키는 상황을 즉시 방지합니다.
- **기간 기준의 영구 보존 및 삭제 정책 (`logrotate` & `agent-log-retention.sh`):**
  - **역할**: 일 단위 정기 크론(Daily Cron)을 기반으로 동작하여 `/var/log/agent-app/*.log`를 관리(30일간 압축 보관)하고, `agent-log-retention.sh`를 통해 7일 이상 경과한 로그를 자동으로 `gzip` 압축하여 아카이브 디렉토리로 이동시키며 30일이 경과한 아카이브는 자동 삭제 처리합니다.
  - **의도**: 보안 규정상 로그 보존 의무를 충족하기 위해 단기 로그는 빠른 조회가 가능한 비압축 형태로 유지하고, 중장기 로그는 공간 효율성을 극대화하기 위해 압축 아카이빙 처리하여 디스크 저장 효율과 규정 준수를 동시에 만족합니다.

#### Logrotate 설정

**구현**: Dockerfile (라인 45-62)

```bash
/var/log/agent-app/*.log {
    daily                  # 매일 회전
    missingok              # 파일 미존재 시 오류 무시
    rotate 30              # 30개 파일 보관
    compress               # gzip 압축
    copytruncate           # 파일 보존, 내용만 제거
    notifempty             # 로그가 비어있으면 회전 미수행
    dateext                # 회전 파일명 뒤에 타임스탬프 접미사 추가
    dateformat -%Y%m%d%H%M%S
    olddir /var/log/monitor/agent-app/archive  # 보관 디렉토리 지정
    create 640 agent-admin agent-core
    sharedscripts
    postrotate
        install -d -m 750 -o agent-admin -g agent-core /var/log/monitor/agent-app/archive
    endscript
}
```

**주요 옵션**:
- `daily`: 매일 회전
- `compress`: 50-90% 용량 감소
- `copytruncate`: 애플리케이션 파일 핸들 유지
- `olddir`: 회전 파일 별도 디렉토리로 이동

#### 추가 보존 스크립트: `agent-log-retention.sh`

**구현**: Dockerfile (라인 64-81)

```bash
#!/usr/bin/env bash
set -euo pipefail

ARCHIVE_DIR=/var/log/monitor/agent-app/archive
LOG_DIR=/var/log/agent-app

mkdir -p "$ARCHIVE_DIR"
chown agent-admin:agent-core "$ARCHIVE_DIR"
chmod 750 "$ARCHIVE_DIR"

# 7일 경과한 로그 파일 탐색 및 안전한 압축/아카이브 이동
find "$LOG_DIR" -maxdepth 1 -type f -name '*.log' -mtime +6 -print0 | while IFS= read -r -d '' file; do
    gzip -f "$file"
    mv -f "${file}.gz" "$ARCHIVE_DIR/"
done

# 30일 경과한 아카이브 백업 삭제 (파일명 공백 문자 오동작 안전성 보장)
find "$ARCHIVE_DIR" -maxdepth 1 -type f -name '*.gz' -mtime +29 -print0 | xargs -0 rm -f -- || true
```

**공백 포함 파일명 안전성 보강**:
- `find ... -print0` 명령어와 `while IFS= read -r -d ''` 및 `xargs -0` 파이프라인을 일관되게 활용하여, 파일명에 예기치 않게 공백이나 특수 문자가 포함되더라도 인자가 쪼개지거나 잘못된 파일을 삭제하는 보안 취약점을 완벽하게 차단했습니다.

**Cron 등록**:
```bash
0 0 * * * /usr/local/bin/agent-log-retention.sh >/dev/null 2>&1
```

매일 00:00 자동 실행

**확인 증거**: [evidence/logrotate.md](evidence/logrotate.md)

---

## 필수 증거 자료

| 항목 | 파일 | 내용 |
|------|------|------|
| SSH/방화벽 | [evidence/ssh_firewall.md](evidence/ssh_firewall.md) | Port 20022, PermitRootLogin no, UFW 활성화 |
| 계정/그룹 | [evidence/groups_users.md](evidence/groups_users.md) | 사용자 생성, 그룹 멤버십 |
| 권한 설정 | [evidence/permissions.md](evidence/permissions.md) | 디렉토리 소유자/권한 |
| 앱 부트 | [evidence/app_start.md](evidence/app_start.md) | 5단계 OK, Agent READY |
| 모니터 실행 | [evidence/monitor_run.md](evidence/monitor_run.md) | Health Check, 리소스 수집 |
| Cron 작업 | [evidence/cron_check.md](evidence/cron_check.md) | 크론 등록, 로그 누적 |
| Logrotate | [evidence/logrotate.md](evidence/logrotate.md) | 설정 및 보존 정책 |
| 리포트 | [evidence/bonus_report.md](evidence/bonus_report.md) | report.sh 통계 |

---

## 평가 질문과 답변

### Q1. SSH 포트 변경과 Root 원격 접속 차단이 왜 기본 보안인가?

**A1. 자동 공격 방어 및 권한 상승 공격 방지**

**포트 변경의 효과**:
- 기본 포트 22는 전 세계 스캔 도구의 타겟
- 포트 변경만으로 자동 공격의 99% 이상 방어
- 실제 서버는 수시간마다 수천 건의 22번 포트 접근 시도 기록

**Root 로그인 차단의 효과**:
- Root 계정 침해 = 시스템 완전 제어
- 일반 계정 로그인 후 `sudo` 사용으로 감사 추적 가능
- 규제 준수: 사용자 행동 추적 의무화된 산업 많음

**구현**:
```bash
# Dockerfile 라인 96-98
sed -i 's/#Port 22/Port 20022/' /etc/ssh/sshd_config
sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config
```

### Q2. UFW 방화벽의 "필요 포트만 허용" 정책은?

**A2. 최소 권한의 원칙 (Principle of Least Privilege)**

**기본 거부 + 필요한 것만 허용**:
- 인바운드: 모든 포트 기본 차단
- 예외: 20022(SSH), 15034(App)만 명시적 허용
- 결과: 의도치 않은 서비스 노출 방지

**구현**:
```bash
ufw allow 20022/tcp  # SSH
ufw allow 15034/tcp  # 애플리케이션
# 다른 모든 inbound는 자동 거부
```

### Q3. 역할 기반 계정/그룹으로 권한을 분리하는 이유는?

**A3. 책임 분리 (Separation of Duties)**

**팀 구성과 권한**:
- `agent-admin`: 운영자
- `agent-dev`: 개발자
- `agent-test`: 테스터

**권한 분리**:
- `upload_files` (agent-common): 모두 공유
- `api_keys` (agent-core): admin/dev만 접근 (테스터 차단)
- `/var/log/agent-app` (agent-core): admin/dev만 접근

**효과**:
- 각 역할이 필요한 리소스만 접근
- 실수나 악의적 행동 방지
- 감사 추적 가능

### Q4. 환경 변수로 실행 환경을 고정하는 이유는?

**A4. 배포 일관성 보장**

**문제**: 환경 변수 없이
```bash
# 개발자 A
/usr/local/bin/agent-app  # 로그가 어디?

# 개발자 B
AGENT_LOG_DIR=/tmp ./agent-app  # /tmp?

→ 로그 경로 불일치 → 장애 원인 분석 실패
```

**해결**: Dockerfile에서 ENV 설정
```bash
ENV AGENT_HOME=/home/agent-admin/agent-app
ENV AGENT_LOG_DIR=/var/log/agent-app
ENV AGENT_PORT=15034
```

**확인**: 부트 시퀀스 단계 2에서 검증

### Q5. 모니터링 데이터 수집 흐름은?

**A5. 수집 → 저장 → 분석 → 대응**

**1) 매분 수집 (monitor.sh)**:
```
프로세스 확인 → 포트 확인 → CPU 수집 → MEM 수집 → DISK 수집
```

**2) 로그 저장**:
```
[2026-05-27 11:11:13] PID:243 CPU:0.0% MEM:4.4% DISK_USED:1%
```

**3) 분석 (report.sh)**:
```bash
awk로 파싱 → 통계 계산 → 평균/최대/최소 출력
```

**4) 대응 예시**:
```
메모리 증가 추세 발견 → 앱 재시작 예약 → 장애 방지
```

### Q6. 로그 보존 정책이 필요한 이유는?

**A6. 디스크 관리 및 성능 최적화**

**계산**:
- 로그: 60 바이트/분
- 1일: 86.4 KB
- 1년: 31.5 MB
- 5년: 157.5 MB (문제없음... 하지만)

**다중 로그 고려**:
```
agent-app.log
syslog
auth.log
...

→ 5년 데이터: 5GB 이상
→ 디스크 부족 → 로그 기록 중단 → 운영 파탄
```

**해결: Logrotate + Retention**:
```
Day 1  : monitor.log (60B)
Day 2  : monitor.log.20260527 → gzip → 6KB
        monitor.log (60B) ← 새로 쓰기
...
Day 31: 30개 파일 * 6KB = 180KB (5년치 데이터)
Day 31+: 가장 오래된 파일 삭제 (30일 경과)
```

**효과**:
- 최근: 빠른 조회 (원본)
- 중기: 압축 저장 (조회 가능)
- 장기: 자동 삭제 (디스크 절약)

---

## 실행 및 상세 수동 검증 절차

아래 단계를 따라 Docker 환경에서 모든 구성 요소를 수동으로 빌드하고 세부 정책(방화벽, 권한, 부트 시퀀스, 모니터링, 로그 보관, 리포트 등)을 직접 검증할 수 있습니다.

### 1. 컨테이너 빌드 및 구동

```bash
# 1) Docker 이미지 빌드
docker build -t b1-1-ubuntu .

# 2) 이전 컨테이너 정리 및 재생성 (방화벽 동작을 위해 NET_ADMIN 및 NET_BIND_SERVICE 권한 추가)
docker rm -f b1-1-assignment >/dev/null 2>&1 || true
docker run -d --name b1-1-assignment \
  --cap-add NET_ADMIN \
  --cap-add NET_BIND_SERVICE \
  -p 22022:20022 \
  -p 15034:15034 \
  b1-1-ubuntu

# 3) 초기 서비스 기동 대기
sleep 5
```

### 2. 단계별 세부 기능 수동 검증 명세

컨테이너가 정상적으로 실행 중인지 검증하기 위해 호스트 터미널에서 다음 명령어들을 실행하고 결과를 확인합니다.

#### 1단계: 사용자 계정 및 권한 정책 검증
* **검증 명령어**:
  ```bash
  docker exec b1-1-assignment id agent-admin && \
  docker exec b1-1-assignment id agent-dev && \
  docker exec b1-1-assignment id agent-test
  ```
  *기대 출력*: 각 계정의 UID/GID 정보와 소속 그룹 정보가 정상적으로 나타나야 합니다. (`agent-admin` 및 `agent-dev`는 `agent-core` 그룹에 속해 있어야 합니다.)
* **디렉토리 소유권 및 POSIX 권한 검증**:
  ```bash
  docker exec b1-1-assignment ls -ld /home/agent-admin/agent-app /home/agent-admin/agent-app/upload_files /home/agent-admin/agent-app/api_keys /var/log/agent-app
  ```
  *기대 출력*: 각 디렉토리의 소유자와 그룹, 그리고 접근 권한(770)이 정확히 설정되어 있는지 확인합니다.

#### 2단계: ACL(Access Control List) 설정 검증
* **검증 명령어**:
  ```bash
  docker exec b1-1-assignment getfacl /home/agent-admin/agent-app/upload_files /home/agent-admin/agent-app/api_keys /var/log/agent-app
  ```
  *기대 출력*: 각 파일/폴더의 확장 권한 구조와 소유권 정보가 출력됩니다. `other::---` 설정을 통해 명시적으로 지정되지 않은 사용자의 접근이 완벽히 통제됨을 확인할 수 있습니다.

#### 3단계: SSH 포트 및 비밀번호 인증 비활성화 설정 검증
* **검증 명령어**:
  ```bash
  docker exec b1-1-assignment grep -E '^Port |^PermitRootLogin |^PasswordAuthentication ' /etc/ssh/sshd_config
  ```
  *기대 출력*:
  ```text
  Port 20022
  PermitRootLogin no
  PasswordAuthentication no
  ```
  *(비밀번호를 통한 접속 차단과 루트 직접 접근 차단, 대체 포트 20022번 지정이 올바르게 반영되었음을 보여줍니다.)*

#### 4단계: UFW 방화벽 활성화 상태 및 기본 차단/허용 규칙 검증
* **검증 명령어**:
  ```bash
  docker exec b1-1-assignment ufw status verbose
  ```
  *기대 출력*:
  ```text
  Status: active
  Logging: on (low)
  Default: deny (incoming), allow (outgoing), disabled (routed)
  New profiles: skip

  To                         Action      From
  --                         ------      ----
  20022/tcp                  ALLOW IN    Anywhere
  15034/tcp                  ALLOW IN    Anywhere
  ```
  *(기본 인바운드 정책이 `deny (incoming)`로 차단 상태이며 아웃바운드는 `allow (outgoing)`로 작동하며, 20022번과 15034번 포트에 대해서만 명시적으로 외부 인바운드가 열려 있음을 확증합니다.)*

#### 5단계: 애플리케이션 부트 시퀀스 5단계 수동 실행 및 검증
관리자 계정(`agent-admin`) 권한으로 데몬을 구동한 뒤, 로그 파일을 통해 순차적인 안전 진단 단계를 수행하는 부트 시퀀스를 검사합니다.

* **구동 및 검증 명령어**:
  ```bash
  # 1) 데몬 백그라운드 구동 실행 (agent-admin 계정)
  docker exec -d b1-1-assignment su - agent-admin -c "cd /home/agent-admin/agent-app && env AGENT_HOME=/home/agent-admin/agent-app AGENT_PORT=15034 AGENT_UPLOAD_DIR=/home/agent-admin/agent-app/upload_files AGENT_KEY_PATH=/home/agent-admin/agent-app/api_keys AGENT_LOG_DIR=/var/log/agent-app nohup /usr/local/bin/agent-app > /home/agent-admin/agent-app/agent_app.log 2>&1 &"
  
  # 2) 잠시 대기 후 포트 15034 바인딩 감지 확인
  sleep 3
  docker exec b1-1-assignment ss -tlnp | grep -E ':15034\b'
  
  # 3) 부트 시퀀스 5단계 출력 검증
  docker exec b1-1-assignment cat /home/agent-admin/agent-app/agent_app.log | head -n 15
  ```
* *기대 출력*: 로그의 상단부에서 아래의 5개 단계가 모두 `[OK]`로 완료되었고, `Agent READY`에 성공했는지 검출되어야 합니다:
  ```text
  >>> Starting Agent Boot Sequence...
  [1/5] Checking User Account               [OK]
  [2/5] Verifying Environment Variables     [OK]
  [3/5] Checking Required Files             [OK]
  [4/5] Checking Port Availability          [OK]
  [5/5] Verifying Log Permission            [OK]
  ------------------------------------------------------------
  All Boot Checks Passed!
  Agent READY
  ```

#### 6단계: 시스템 리소스 모니터링 엔진 (`monitor.sh`) 수동 작동 검증
* **검증 명령어**:
  ```bash
  docker exec b1-1-assignment /home/agent-admin/agent-app/bin/monitor.sh
  ```
* *기대 출력*: 아래와 같이 프로세스 확인, 포트 확인, 방화벽 체크 후 CPU 사용률(1초 샘플링 델타 연산)과 메모리/디스크 사용량이 정확히 계산되어 1회용 결과 리포트가 터미널에 표시됩니다:
  ```text
  ====== SYSTEM MONITOR RESULT ======
  [HEALTH CHECK] Checking process 'agent-app'... [OK] (PID: <PID_NUMBER>)
  [HEALTH CHECK] Checking port 15034... [OK]
  [HEALTH CHECK] Firewall status: UFW active
  [RESOURCE MONITORING]
  CPU Usage : 0.0%
  MEM Usage : 4.4%
  DISK Used  : 1%
  [INFO] Log appended: /var/log/agent-app/monitor.log
  ```

#### 7단계: 크론탭 자동 기동 및 로그 파일 누적 검증
* **검증 명령어**:
  ```bash
  # 1) 크론 스케줄링 검출
  docker exec b1-1-assignment crontab -u agent-admin -l
  
  # 2) 누적된 모니터링 로그 출력 확인
  docker exec b1-1-assignment tail -n 5 /var/log/agent-app/monitor.log
  ```
  *기대 출력*: 1분 주기로 cron이 돌면서 로그가 지속적으로 뒤에 쌓이는 상태를 확인합니다.

#### 8단계: 리포트 분석 도구 (`report.sh`) 수동 가동 검증
* **검증 명령어**:
  ```bash
  # 전체 로그에 대한 통계 리포트 생성
  docker exec b1-1-assignment /home/agent-admin/agent-app/bin/report.sh /var/log/agent-app/monitor.log
  ```
  *기대 출력*: 샘플 수와 CPU/MEMORY/DISK 평균, 최대/최소값 및 발생 시각이 포맷된 형태로 출력됩니다.
* **시간 필터 기반 리포트 생성**:
  ```bash
  # 시작 시간 및 종료 시간을 직접 지정하여 파싱 (포맷: YYYY-MM-DD HH:MM:SS)
  docker exec b1-1-assignment /home/agent-admin/agent-app/bin/report.sh /var/log/agent-app/monitor.log "2026-05-27 00:00:00" "2026-05-27 23:59:59"
  ```
* **비정상 입력 또는 범위 외 조회 시 Exit Code 확인**:
  ```bash
  # 범위 밖에 존재하여 데이터가 존재하지 않는 경우
  docker exec b1-1-assignment /home/agent-admin/agent-app/bin/report.sh /var/log/agent-app/monitor.log "2030-01-01 00:00:00" "2030-01-01 23:59:59" || echo "Status Code: $?"
  ```
  *기대 출력*: `No matching samples found.` 메시지와 함께 비정상 코드 `Status Code: 1`이 리턴되어야 합니다.

#### 9단계: 로그 백업 보존 정책 (`logrotate` 및 아카이브 크론) 수동 가동 검증
* **검증 명령어**:
  ```bash
  # 1) logrotate 설정을 강제 강도 테스트
  docker exec b1-1-assignment logrotate -f /etc/logrotate.d/agent-app
  
  # 2) 아카이브에 파일이 생성되었는지 확인
  docker exec b1-1-assignment ls -l /var/log/monitor/agent-app/archive
  
  # 3) 보조 영구보존 스크립트 수동 기동
  docker exec b1-1-assignment /usr/local/bin/agent-log-retention.sh
  ```
  *기대 출력*: 회전된 로그 파일들이 archive 디렉토리로 안전하게 이동되고 `gzip` 형태로 남아 있어야 합니다.

## 주요 파일

| 파일 | 역할 |
|------|------|
| `Dockerfile` | 컨테이너 이미지 빌드 |
| `monitor.sh` | 시스템 모니터링 |
| `report.sh` | 로그 통계 분석 |
| `evidence/` | 실행 결과 증거 |


**확인 증거**: [evidence/ssh_firewall.md](evidence/ssh_firewall.md)

#### 방화벽(UFW) 및 네트워크 최소 권한 정책

**구현 위치**: Dockerfile (라인 104) 및 컨테이너 시작 CMD (라인 112)

```bash
RUN ufw default deny incoming && ufw default allow outgoing && ufw allow 20022/tcp && ufw allow 15034/tcp
```

**설명**:
- **최소 권한 네트워크 보안(Default Deny Incoming)**: 방화벽 기본 규칙으로 외부에서 컨테이너 내부로 들어오는 모든 미승인 인바운드 트래픽을 차단(`default deny incoming`)합니다. 
- **내부 시작 아웃바운드 허용(Default Allow Outgoing)**: 컨테이너 내부에서 시작하여 외부 네트워크로 나가는 요청은 정상적으로 작동(`default allow outgoing`)하도록 보장하여 원활한 패키지 업데이트 및 외부 API 연동을 지원합니다.
- **명시적 예외 규칙 추가**:
  - `TCP 20022 (SSH)`: 보안 가공된 관리자용 원격 제어 포트만 수용
  - `TCP 15034 (애플리케이션)`: 시스템 모니터링 수집기 포트만 수용
- **시작 시 강제 적용**: 빌드 시 정책 설정뿐 아니라 컨테이너 시작 시(`CMD`)에도 `ufw default deny incoming && ufw default allow outgoing && ufw --force enable`을 기동하여 환경 변화나 재시작 시에도 일관되고 신뢰성 있게 최소 권한 보안 정책이 활성화되도록 강제했습니다.

**확인 증거**: [evidence/ssh_firewall.md](evidence/ssh_firewall.md)

---

### 2. 사용자/그룹/권한 체계

#### 계정 및 그룹 생성

**구현 위치**: Dockerfile (라인 20-27)

```bash
RUN groupadd --system agent-common && \
    groupadd --system agent-core && \
    useradd --create-home ... agent-admin && \
    useradd --create-home ... agent-dev && \
    useradd --create-home ... agent-test
```

**계정 역할**:
- `agent-admin` (UID 1000): 운영자, cron 실행
- `agent-dev` (UID 1001): 개발자, 모니터 스크립트 작성
- `agent-test` (UID 1002): 테스터

**그룹 멤버십**:
- `agent-common` (GID 999): admin, dev, test
- `agent-core` (GID 998): admin, dev (민감 리소스)

**확인 증거**: [evidence/groups_users.md](evidence/groups_users.md)

#### 디렉토리 및 권한

**구현 위치**: Dockerfile (라인 28-33)

```bash
RUN chown -R agent-admin:agent-common $AGENT_HOME && \
    chown agent-admin:agent-common $AGENT_UPLOAD_DIR && chmod 750 $AGENT_UPLOAD_DIR && \
    chown agent-admin:agent-core $AGENT_HOME/api_keys && chmod 750 $AGENT_HOME/api_keys && \
    chown agent-admin:agent-core $AGENT_LOG_DIR && chmod 750 $AGENT_LOG_DIR
```

**권한 정책**:
- `upload_files` (750, `agent-common`): 모든 팀원 공유
- `api_keys` (750, `agent-core`): admin/dev만 접근 (민감 정보 보호)
- `/var/log/agent-app` (750, `agent-core`): admin/dev만 접근 (운영 로그)

**확인 증거**: [evidence/permissions.md](evidence/permissions.md)

#### 디렉토리 권한 및 ACL(Access Control List) 검증

역할 기반 접근 제어(RBAC) 및 보안 정책이 제대로 작동하고 있는지 검증하기 위해 POSIX 기본 권한(`ls -l`)과 확장 권한(`getfacl`)을 통해 상세 확인이 가능합니다.

**1) 파일 권한 및 소유자 확인 (`ls -l` / `ls -ld`)**
* `/home/agent-admin/agent-app/upload_files`: 소유자 `agent-admin`, 소유 그룹 `agent-common`, 권한 `750` (`drwxr-x---`)
* `/home/agent-admin/agent-app/api_keys`: 소유자 `agent-admin`, 소유 그룹 `agent-core`, 권한 `750` (`drwxr-x---`)
* `/var/log/agent-app`: 소유자 `agent-admin`, 소유 그룹 `agent-core`, 권한 `750` (`drwxr-x---`)

**2) ACL(Access Control List) 상세 구조 확인 (`getfacl`)**
컨테이너 내부에 `acl` 패키지를 설치하여 파일 시스템 수준에서 정교한 권한 검증을 제공합니다. 아래 명령어로 각각의 ACL 설정을 확인할 수 있습니다.

* **공유 업로드 디렉토리 (`upload_files`):**
  ```bash
  getfacl /home/agent-admin/agent-app/upload_files
  ```
  *예상 출력:*
  ```text
  # file: home/agent-admin/agent-app/upload_files
  # owner: agent-admin
  # group: agent-common
  user::rwx
  group::r-x
  other::---
  ```
  *(설명: `agent-common` 그룹에 속한 admin, dev, test 세 사용자 모두가 자유롭게 읽고 쓸 수 있는 공간을 제공합니다.)*

* **민감 정보 디렉토리 (`api_keys` 및 `/var/log/agent-app`):**
  ```bash
  getfacl /home/agent-admin/agent-app/api_keys
  getfacl /var/log/agent-app
  ```
  *예상 출력:*
  ```text
  # file: var/log/agent-app
  # owner: agent-admin
  # group: agent-core
  user::rwx
  group::r-x
  other::---
  ```
  *(설명: `agent-core` 그룹(admin, dev)만 읽고 쓰기가 가능하며, 테스트 담당 계정인 `agent-test` 등 외부 계정의 접근은 차단됩니다.)*

**확인 증거**: [evidence/permissions.md](evidence/permissions.md)

---

### 3. 애플리케이션 실행 환경

#### 환경 변수 설정

**구현 위치**: Dockerfile (라인 5-11)

```bash
ENV AGENT_HOME=/home/agent-admin/agent-app
ENV AGENT_PORT=15034
ENV AGENT_LOG_DIR=/var/log/agent-app
```

**목적**: 실행 환경의 일관성 보장

#### 바이너리 권한

**구현 위치**: Dockerfile (라인 83-87)

```bash
chmod 750 /usr/local/bin/agent-app
chown agent-admin:agent-common /usr/local/bin/agent-app
```

**의의**: 일반 계정(agent-admin)이 실행 가능 (Root 권한 불필요)

#### 앱 부트 시퀀스

**부트 시퀀스 5단계**:
1. User Account Check
2. Environment Variables Verification
3. Required Files Check (API 키)
4. Port Availability
5. Log Permission

**확인 증거**: [evidence/app_start.md](evidence/app_start.md)

---

### 4. 모니터링 스크립트: `monitor.sh`

#### 파일 정보

**위치**: `/home/agent-admin/agent-app/bin/monitor.sh`
- 소유자: `agent-dev`
- 그룹: `agent-core`
- 권한: `750` (rwxr-x---)

#### 주요 기능

**1) Health Check (장애 감지)**

프로세스 확인:
```bash
pgrep -f "${APP_NAME}(\\.py)?$" | head -n 1
```

포트 확인:
```bash
ss -tlnp | grep -E "LISTEN.+:${AGENT_PORT}\\b"
```

비정상 시 `exit 1`로 즉시 종료

**2) 상태 점검**

방화벽 활성화 여부 확인 (비정상 시 경고만 출력)

**3) 리소스 수집**

```bash
# CPU 사용률 (/proc/stat 기반)
awk 'NR==1 { idle1=$5+$6; total1=... } NR==2 { idle2=$5+$6; total2=... }' /proc/stat

# 메모리 사용률 (/proc/meminfo 기반)
awk '/MemTotal/ {total=$2} /MemAvailable/ {avail=$2}' /proc/meminfo

# 디스크 사용률 (df 기반)
df -P / | awk 'NR==2 {...}'
```

**4) 임계값 경고**

- CPU > 20%: `[WARNING]` 출력
- MEM > 10%: `[WARNING]` 출력
- DISK > 80%: `[WARNING]` 출력

**5) 로그 기록**

```bash
printf '[%s] PID:%s CPU:%s%% MEM:%s%% DISK_USED:%s%%\n' \
  "$(date '+%Y-%m-%d %H:%M:%S')" "$pid" "$cpu" "$mem" "$disk" >> "$LOG_FILE"
```

로그 포맷: `[2026-05-27 11:11:13] PID:243 CPU:0.0% MEM:4.4% DISK_USED:1%`

**확인 증거**: [evidence/monitor_run.md](evidence/monitor_run.md)

#### Cron 자동 실행

**구현**: Dockerfile (라인 103-106)

```bash
echo "* * * * * /home/agent-admin/agent-app/bin/monitor.sh >/dev/null 2>&1" | crontab -u agent-admin -
```

매분 자동 실행 → 로그 누적 기록

**확인 증거**: [evidence/cron_check.md](evidence/cron_check.md)

---

### 5. 리포트 생성: `report.sh`

#### 파일 정보

**위치**: `/home/agent-admin/agent-app/bin/report.sh`
- 소유자: `agent-dev`
- 그룹: `agent-core`
- 권한: `750`

#### 동작

**사용법**:
```bash
./report.sh [LOG_FILE] [START_TIME] [END_TIME]
```

**기능**:
- monitor.log 파싱 및 통계 계산
- CPU/MEM/DISK 평균/최대/최소 값 산출
- 샘플 개수 출력

**awk 로직**:
1. 각 라인에서 `[TIMESTAMP]`, `CPU`, `MEM`, `DISK_USED` 추출
2. 시간 범위 필터링 (시작/종료 시간 지정 시)
3. 누적값, 최대값, 최소값 계산
4. 포맷된 리포트 출력

**출력 예시**:
```
====== STATISTICS REPORT ======
Samples : 3
[CPU]
Average : 0.0%
Maximum : 0.0% at 2026-05-27 11:11:13
Minimum : 0.0% at 2026-05-27 11:11:13
```

**확인 증거**: [evidence/bonus_report.md](evidence/bonus_report.md)

---

### 6. 로그 보존 및 아카이빙 정책

시스템 로그 보존 및 관리를 위해 본 프로젝트는 **액티브 모니터링 크기 기반 회전**과 **배경 서비스 기간 기준 압축/아카이빙/삭제**의 상호보완적 이중 설계를 채택하였습니다.

#### 이중 로그 회전 설계 및 역할 분담 배경
- **크기 기반의 즉각적 로그 회전 (`monitor.sh` 내부):**
  - **역할**: 매 분 구동되는 모니터링 엔진에서 실행 로그 파일(`monitor.log`)의 크기를 즉각적으로 모니터링하여 `10MB`를 초과할 경우 즉시 회전시키고 최대 `10개`만 유지합니다.
  - **의도**: 일시적인 시스템 에러나 대량의 모니터링 출력으로 인해 단시간에 로그 파일이 임계값 이상으로 폭증하여 서버의 물리적 디스크를 고갈(Exhaustion)시키는 상황을 즉시 방지합니다.
- **기간 기준의 영구 보존 및 삭제 정책 (`logrotate` & `agent-log-retention.sh`):**
  - **역할**: 일 단위 정기 크론(Daily Cron)을 기반으로 동작하여 `/var/log/agent-app/*.log`를 관리(30일간 압축 보관)하고, `agent-log-retention.sh`를 통해 7일 이상 경과한 로그를 자동으로 `gzip` 압축하여 아카이브 디렉토리로 이동시키며 30일이 경과한 아카이브는 자동 삭제 처리합니다.
  - **의도**: 보안 규정상 로그 보존 의무를 충족하기 위해 단기 로그는 빠른 조회가 가능한 비압축 형태로 유지하고, 중장기 로그는 공간 효율성을 극대화하기 위해 압축 아카이빙 처리하여 디스크 저장 효율과 규정 준수를 동시에 만족합니다.

#### Logrotate 설정

**구현**: Dockerfile (라인 45-62)

```bash
/var/log/agent-app/*.log {
    daily                  # 매일 회전
    missingok              # 파일 미존재 시 오류 무시
    rotate 30              # 30개 파일 보관
    compress               # gzip 압축
    copytruncate           # 파일 보존, 내용만 제거
    notifempty             # 로그가 비어있으면 회전 미수행
    dateext                # 회전 파일명 뒤에 타임스탬프 접미사 추가
    dateformat -%Y%m%d%H%M%S
    olddir /var/log/monitor/agent-app/archive  # 보관 디렉토리 지정
    create 640 agent-admin agent-core
    sharedscripts
    postrotate
        install -d -m 750 -o agent-admin -g agent-core /var/log/monitor/agent-app/archive
    endscript
}
```

**주요 옵션**:
- `daily`: 매일 회전
- `compress`: 50-90% 용량 감소
- `copytruncate`: 애플리케이션 파일 핸들 유지
- `olddir`: 회전 파일 별도 디렉토리로 이동

#### 추가 보존 스크립트: `agent-log-retention.sh`

**구현**: Dockerfile (라인 64-81)

```bash
#!/usr/bin/env bash
set -euo pipefail

ARCHIVE_DIR=/var/log/monitor/agent-app/archive
LOG_DIR=/var/log/agent-app

mkdir -p "$ARCHIVE_DIR"
chown agent-admin:agent-core "$ARCHIVE_DIR"
chmod 750 "$ARCHIVE_DIR"

# 7일 경과한 로그 파일 탐색 및 안전한 압축/아카이브 이동
find "$LOG_DIR" -maxdepth 1 -type f -name '*.log' -mtime +6 -print0 | while IFS= read -r -d '' file; do
    gzip -f "$file"
    mv -f "${file}.gz" "$ARCHIVE_DIR/"
done

# 30일 경과한 아카이브 백업 삭제 (파일명 공백 문자 오동작 안전성 보장)
find "$ARCHIVE_DIR" -maxdepth 1 -type f -name '*.gz' -mtime +29 -print0 | xargs -0 rm -f -- || true
```

**공백 포함 파일명 안전성 보강**:
- `find ... -print0` 명령어와 `while IFS= read -r -d ''` 및 `xargs -0` 파이프라인을 일관되게 활용하여, 파일명에 예기치 않게 공백이나 특수 문자가 포함되더라도 인자가 쪼개지거나 잘못된 파일을 삭제하는 보안 취약점을 완벽하게 차단했습니다.

**Cron 등록**:
```bash
0 0 * * * /usr/local/bin/agent-log-retention.sh >/dev/null 2>&1
```

매일 00:00 자동 실행

**확인 증거**: [evidence/logrotate.md](evidence/logrotate.md)

---

## 필수 증거 자료

| 항목 | 파일 | 내용 |
|------|------|------|
| SSH/방화벽 | [evidence/ssh_firewall.md](evidence/ssh_firewall.md) | Port 20022, PermitRootLogin no, UFW 활성화 |
| 계정/그룹 | [evidence/groups_users.md](evidence/groups_users.md) | 사용자 생성, 그룹 멤버십 |
| 권한 설정 | [evidence/permissions.md](evidence/permissions.md) | 디렉토리 소유자/권한 |
| 앱 부트 | [evidence/app_start.md](evidence/app_start.md) | 5단계 OK, Agent READY |
| 모니터 실행 | [evidence/monitor_run.md](evidence/monitor_run.md) | Health Check, 리소스 수집 |
| Cron 작업 | [evidence/cron_check.md](evidence/cron_check.md) | 크론 등록, 로그 누적 |
| Logrotate | [evidence/logrotate.md](evidence/logrotate.md) | 설정 및 보존 정책 |
| 리포트 | [evidence/bonus_report.md](evidence/bonus_report.md) | report.sh 통계 |

---

## 평가 질문과 답변

### Q1. SSH 포트 변경과 Root 원격 접속 차단이 왜 기본 보안인가?

**A1. 자동 공격 방어 및 권한 상승 공격 방지**

**포트 변경의 효과**:
- 기본 포트 22는 전 세계 스캔 도구의 타겟
- 포트 변경만으로 자동 공격의 99% 이상 방어
- 실제 서버는 수시간마다 수천 건의 22번 포트 접근 시도 기록

**Root 로그인 차단의 효과**:
- Root 계정 침해 = 시스템 완전 제어
- 일반 계정 로그인 후 `sudo` 사용으로 감사 추적 가능
- 규제 준수: 사용자 행동 추적 의무화된 산업 많음

**구현**:
```bash
# Dockerfile 라인 96-98
sed -i 's/#Port 22/Port 20022/' /etc/ssh/sshd_config
sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config
```

### Q2. UFW 방화벽의 "필요 포트만 허용" 정책은?

**A2. 최소 권한의 원칙 (Principle of Least Privilege)**

**기본 거부 + 필요한 것만 허용**:
- 인바운드: 모든 포트 기본 차단
- 예외: 20022(SSH), 15034(App)만 명시적 허용
- 결과: 의도치 않은 서비스 노출 방지

**구현**:
```bash
ufw allow 20022/tcp  # SSH
ufw allow 15034/tcp  # 애플리케이션
# 다른 모든 inbound는 자동 거부
```

### Q3. 역할 기반 계정/그룹으로 권한을 분리하는 이유는?

**A3. 책임 분리 (Separation of Duties)**

**팀 구성과 권한**:
- `agent-admin`: 운영자
- `agent-dev`: 개발자
- `agent-test`: 테스터

**권한 분리**:
- `upload_files` (agent-common): 모두 공유
- `api_keys` (agent-core): admin/dev만 접근 (테스터 차단)
- `/var/log/agent-app` (agent-core): admin/dev만 접근

**효과**:
- 각 역할이 필요한 리소스만 접근
- 실수나 악의적 행동 방지
- 감사 추적 가능

### Q4. 환경 변수로 실행 환경을 고정하는 이유는?

**A4. 배포 일관성 보장**

**문제**: 환경 변수 없이
```bash
# 개발자 A
/usr/local/bin/agent-app  # 로그가 어디?

# 개발자 B
AGENT_LOG_DIR=/tmp ./agent-app  # /tmp?

→ 로그 경로 불일치 → 장애 원인 분석 실패
```

**해결**: Dockerfile에서 ENV 설정
```bash
ENV AGENT_HOME=/home/agent-admin/agent-app
ENV AGENT_LOG_DIR=/var/log/agent-app
ENV AGENT_PORT=15034
```

**확인**: 부트 시퀀스 단계 2에서 검증

### Q5. 모니터링 데이터 수집 흐름은?

**A5. 수집 → 저장 → 분석 → 대응**

**1) 매분 수집 (monitor.sh)**:
```
프로세스 확인 → 포트 확인 → CPU 수집 → MEM 수집 → DISK 수집
```

**2) 로그 저장**:
```
[2026-05-27 11:11:13] PID:243 CPU:0.0% MEM:4.4% DISK_USED:1%
```

**3) 분석 (report.sh)**:
```bash
awk로 파싱 → 통계 계산 → 평균/최대/최소 출력
```

**4) 대응 예시**:
```
메모리 증가 추세 발견 → 앱 재시작 예약 → 장애 방지
```

### Q6. 로그 보존 정책이 필요한 이유는?

**A6. 디스크 관리 및 성능 최적화**

**계산**:
- 로그: 60 바이트/분
- 1일: 86.4 KB
- 1년: 31.5 MB
- 5년: 157.5 MB (문제없음... 하지만)

**다중 로그 고려**:
```
agent-app.log
syslog
auth.log
...

→ 5년 데이터: 5GB 이상
→ 디스크 부족 → 로그 기록 중단 → 운영 파탄
```

**해결: Logrotate + Retention**:
```
Day 1  : monitor.log (60B)
Day 2  : monitor.log.20260527 → gzip → 6KB
        monitor.log (60B) ← 새로 쓰기
...
Day 31: 30개 파일 * 6KB = 180KB (5년치 데이터)
Day 31+: 가장 오래된 파일 삭제 (30일 경과)
```

**효과**:
- 최근: 빠른 조회 (원본)
- 중기: 압축 저장 (조회 가능)
- 장기: 자동 삭제 (디스크 절약)

---

## 실행 및 상세 수동 검증 절차

아래 단계를 따라 Docker 환경에서 모든 구성 요소를 수동으로 빌드하고 세부 정책(방화벽, 권한, 부트 시퀀스, 모니터링, 로그 보관, 리포트 등)을 직접 검증할 수 있습니다.

### 1. 컨테이너 빌드 및 구동

```bash
# 1) Docker 이미지 빌드
docker build -t b1-1-ubuntu .

# 2) 이전 컨테이너 정리 및 재생성 (방화벽 동작을 위해 NET_ADMIN 및 NET_BIND_SERVICE 권한 추가)
docker rm -f b1-1-assignment >/dev/null 2>&1 || true
docker run -d --name b1-1-assignment \
  --cap-add NET_ADMIN \
  --cap-add NET_BIND_SERVICE \
  -p 22022:20022 \
  -p 15034:15034 \
  b1-1-ubuntu

# 3) 초기 서비스 기동 대기
sleep 5
```

### 2. 단계별 세부 기능 수동 검증 명세

컨테이너가 정상적으로 실행 중인지 검증하기 위해 호스트 터미널에서 다음 명령어들을 실행하고 결과를 확인합니다.

#### 1단계: 사용자 계정 및 권한 정책 검증
* **검증 명령어**:
  ```bash
  docker exec b1-1-assignment id agent-admin && \
  docker exec b1-1-assignment id agent-dev && \
  docker exec b1-1-assignment id agent-test
  ```
  *기대 출력*: 각 계정의 UID/GID 정보와 소속 그룹 정보가 정상적으로 나타나야 합니다. (`agent-admin` 및 `agent-dev`는 `agent-core` 그룹에 속해 있어야 합니다.)
* **디렉토리 소유권 및 POSIX 권한 검증**:
  ```bash
  docker exec b1-1-assignment ls -ld /home/agent-admin/agent-app /home/agent-admin/agent-app/upload_files /home/agent-admin/agent-app/api_keys /var/log/agent-app
  ```
  *기대 출력*: 각 디렉토리의 소유자와 그룹, 그리고 접근 권한(770)이 정확히 설정되어 있는지 확인합니다.

#### 2단계: ACL(Access Control List) 설정 검증
* **검증 명령어**:
  ```bash
  docker exec b1-1-assignment getfacl /home/agent-admin/agent-app/upload_files /home/agent-admin/agent-app/api_keys /var/log/agent-app
  ```
  *기대 출력*: 각 파일/폴더의 확장 권한 구조와 소유권 정보가 출력됩니다. `other::---` 설정을 통해 명시적으로 지정되지 않은 사용자의 접근이 완벽히 통제됨을 확인할 수 있습니다.

#### 3단계: SSH 포트 및 비밀번호 인증 비활성화 설정 검증
* **검증 명령어**:
  ```bash
  docker exec b1-1-assignment grep -E '^Port |^PermitRootLogin |^PasswordAuthentication ' /etc/ssh/sshd_config
  ```
  *기대 출력*:
  ```text
  Port 20022
  PermitRootLogin no
  PasswordAuthentication no
  ```
  *(비밀번호를 통한 접속 차단과 루트 직접 접근 차단, 대체 포트 20022번 지정이 올바르게 반영되었음을 보여줍니다.)*

#### 4단계: UFW 방화벽 활성화 상태 및 기본 차단/허용 규칙 검증
* **검증 명령어**:
  ```bash
  docker exec b1-1-assignment ufw status verbose
  ```
  *기대 출력*:
  ```text
  Status: active
  Logging: on (low)
  Default: deny (incoming), allow (outgoing), disabled (routed)
  New profiles: skip

  To                         Action      From
  --                         ------      ----
  20022/tcp                  ALLOW IN    Anywhere
  15034/tcp                  ALLOW IN    Anywhere
  ```
  *(기본 인바운드 정책이 `deny (incoming)`로 차단 상태이며 아웃바운드는 `allow (outgoing)`로 작동하며, 20022번과 15034번 포트에 대해서만 명시적으로 외부 인바운드가 열려 있음을 확증합니다.)*

#### 5단계: 애플리케이션 부트 시퀀스 5단계 수동 실행 및 검증
관리자 계정(`agent-admin`) 권한으로 데몬을 구동한 뒤, 로그 파일을 통해 순차적인 안전 진단 단계를 수행하는 부트 시퀀스를 검사합니다.

* **구동 및 검증 명령어**:
  ```bash
  # 1) 데몬 백그라운드 구동 실행 (agent-admin 계정)
  docker exec -d b1-1-assignment su - agent-admin -c "cd /home/agent-admin/agent-app && env AGENT_HOME=/home/agent-admin/agent-app AGENT_PORT=15034 AGENT_UPLOAD_DIR=/home/agent-admin/agent-app/upload_files AGENT_KEY_PATH=/home/agent-admin/agent-app/api_keys AGENT_LOG_DIR=/var/log/agent-app nohup /usr/local/bin/agent-app > /home/agent-admin/agent-app/agent_app.log 2>&1 &"
  
  # 2) 잠시 대기 후 포트 15034 바인딩 감지 확인
  sleep 3
  docker exec b1-1-assignment ss -tlnp | grep -E ':15034\b'
  
  # 3) 부트 시퀀스 5단계 출력 검증
  docker exec b1-1-assignment cat /home/agent-admin/agent-app/agent_app.log | head -n 15
  ```
* *기대 출력*: 로그의 상단부에서 아래의 5개 단계가 모두 `[OK]`로 완료되었고, `Agent READY`에 성공했는지 검출되어야 합니다:
  ```text
  >>> Starting Agent Boot Sequence...
  [1/5] Checking User Account               [OK]
  [2/5] Verifying Environment Variables     [OK]
  [3/5] Checking Required Files             [OK]
  [4/5] Checking Port Availability          [OK]
  [5/5] Verifying Log Permission            [OK]
  ------------------------------------------------------------
  All Boot Checks Passed!
  Agent READY
  ```

#### 6단계: 시스템 리소스 모니터링 엔진 (`monitor.sh`) 수동 작동 검증
* **검증 명령어**:
  ```bash
  docker exec b1-1-assignment /home/agent-admin/agent-app/bin/monitor.sh
  ```
* *기대 출력*: 아래와 같이 프로세스 확인, 포트 확인, 방화벽 체크 후 CPU 사용률(1초 샘플링 델타 연산)과 메모리/디스크 사용량이 정확히 계산되어 1회용 결과 리포트가 터미널에 표시됩니다:
  ```text
  ====== SYSTEM MONITOR RESULT ======
  [HEALTH CHECK] Checking process 'agent-app'... [OK] (PID: <PID_NUMBER>)
  [HEALTH CHECK] Checking port 15034... [OK]
  [HEALTH CHECK] Firewall status: UFW active
  [RESOURCE MONITORING]
  CPU Usage : 0.0%
  MEM Usage : 4.4%
  DISK Used  : 1%
  [INFO] Log appended: /var/log/agent-app/monitor.log
  ```

#### 7단계: 크론탭 자동 기동 및 로그 파일 누적 검증
* **검증 명령어**:
  ```bash
  # 1) 크론 스케줄링 검출
  docker exec b1-1-assignment crontab -u agent-admin -l
  
  # 2) 누적된 모니터링 로그 출력 확인
  docker exec b1-1-assignment tail -n 5 /var/log/agent-app/monitor.log
  ```
  *기대 출력*: 1분 주기로 cron이 돌면서 로그가 지속적으로 뒤에 쌓이는 상태를 확인합니다.

#### 8단계: 리포트 분석 도구 (`report.sh`) 수동 가동 검증
* **검증 명령어**:
  ```bash
  # 전체 로그에 대한 통계 리포트 생성
  docker exec b1-1-assignment /home/agent-admin/agent-app/bin/report.sh /var/log/agent-app/monitor.log
  ```
  *기대 출력*: 샘플 수와 CPU/MEMORY/DISK 평균, 최대/최소값 및 발생 시각이 포맷된 형태로 출력됩니다.
* **시간 필터 기반 리포트 생성**:
  ```bash
  # 시작 시간 및 종료 시간을 직접 지정하여 파싱 (포맷: YYYY-MM-DD HH:MM:SS)
  docker exec b1-1-assignment /home/agent-admin/agent-app/bin/report.sh /var/log/agent-app/monitor.log "2026-05-27 00:00:00" "2026-05-27 23:59:59"
  ```
* **비정상 입력 또는 범위 외 조회 시 Exit Code 확인**:
  ```bash
  # 범위 밖에 존재하여 데이터가 존재하지 않는 경우
  docker exec b1-1-assignment /home/agent-admin/agent-app/bin/report.sh /var/log/agent-app/monitor.log "2030-01-01 00:00:00" "2030-01-01 23:59:59" || echo "Status Code: $?"
  ```
  *기대 출력*: `No matching samples found.` 메시지와 함께 비정상 코드 `Status Code: 1`이 리턴되어야 합니다.

#### 9단계: 로그 백업 보존 정책 (`logrotate` 및 아카이브 크론) 수동 가동 검증
* **검증 명령어**:
  ```bash
  # 1) logrotate 설정을 강제 강도 테스트
  docker exec b1-1-assignment logrotate -f /etc/logrotate.d/agent-app
  
  # 2) 아카이브에 파일이 생성되었는지 확인
  docker exec b1-1-assignment ls -l /var/log/monitor/agent-app/archive
  
  # 3) 보조 영구보존 스크립트 수동 기동
  docker exec b1-1-assignment /usr/local/bin/agent-log-retention.sh
  ```
  *기대 출력*: 회전된 로그 파일들이 archive 디렉토리로 안전하게 이동되고 `gzip` 형태로 남아 있어야 합니다.

## 주요 파일

| 파일 | 역할 |
|------|------|
| `Dockerfile` | 컨테이너 이미지 빌드 |
| `monitor.sh` | 시스템 모니터링 |
| `report.sh` | 로그 통계 분석 |
| `evidence/` | 실행 결과 증거 |

