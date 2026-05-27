# PRESENTATION SCRIPT

## 1. 시작 인사 및 개요

안녕하세요. 저는 `B1-1` 과제를 Docker 기반 Ubuntu 22.04 환경에서 재현했습니다. 이 프로젝트는 SSH 보안, 방화벽, 계정/그룹/권한 관리, 애플리케이션 실행 환경 구성, 자동 모니터링 및 로그 기록을 포함합니다.

## 2. 구현 목표 설명

- 본 구현은 `ASSIGNMENT_SPEC.md`를 주 스펙으로 선택했습니다. `B1-1.md`는 원본 설명 참고용으로 보존하였지만, 실제 과제 수행과 검증은 `ASSIGNMENT_SPEC`에 맞춰 진행했습니다.
- `SSH 포트 20022`로 변경하고 `Root 원격 로그인`을 차단했습니다.
- `UFW`를 활성화하고 `20022/tcp`, `15034/tcp`만 허용했습니다. (실제 구현: UFW 사용)
- `agent-admin`, `agent-dev`, `agent-test` 계정을 생성하고 `agent-common`, `agent-core` 그룹을 구성했습니다.
- `AGENT_HOME` 기반 디렉토리 구조와 권한을 분리하여 `upload_files`와 `api_keys`를 관리했습니다.
- `monitor.sh`를 작성하여 프로세스/포트/CPU/MEM/DISK 상태를 수집하고 `monitor.log`에 기록했습니다.
- `agent-admin` 사용자 crontab에 매분 실행 등록을 추가했습니다.

## 3. 데모 순서

1. Docker 이미지 빌드
   ```bash
   ./run_assignment.sh
   ```
2. SSH 설정 확인
   ```bash
   docker exec b1-1-assignment grep -E '^Port |^PermitRootLogin ' /etc/ssh/sshd_config
   ```
3. 방화벽 상태 확인
   ```bash
   docker exec b1-1-assignment ufw status verbose
   ```
4. 계정/그룹/권한 확인
   ```bash
   docker exec b1-1-assignment id agent-admin
   docker exec b1-1-assignment id agent-dev
   docker exec b1-1-assignment ls -l /home/agent-admin/agent-app
   docker exec b1-1-assignment ls -ld /var/log/agent-app
   ```
5. 애플리케이션 부트 시퀀스 확인
   ```bash
   docker exec b1-1-assignment su - agent-admin -c 'cd /home/agent-admin/agent-app && env AGENT_HOME=/home/agent-admin/agent-app AGENT_PORT=15034 AGENT_UPLOAD_DIR=/home/agent-admin/agent-app/upload_files AGENT_KEY_PATH=/home/agent-admin/agent-app/api_keys/t_secret.key AGENT_LOG_DIR=/var/log/agent-app /usr/local/bin/agent-app'
   ```
6. `monitor.sh` 실행 및 로그 확인
   ```bash
   docker exec b1-1-assignment /home/agent-admin/agent-app/bin/monitor.sh
   docker exec b1-1-assignment tail -n 5 /var/log/agent-app/monitor.log
   ```
7. cron 자동 실행 증빙
   ```bash
   docker exec b1-1-assignment tail -n 5 /var/log/agent-app/monitor.log
   ```
8. 증거 파일(전체 부트 로그) 확인

```bash
cat evidence/app_start.md
```

추가: `evaluation_question.md`의 평가 기준 항목을 프레젠테이션 중 요약해서 답변할 수 있도록 준비했습니다.

## 4. 평가 포인트 정리

- 보안 설정: SSH 포트 변경, Root 로그인 차단, 방화벽 정책
- 사용자/그룹: 최소 권한 원칙 적용
- 로그와 모니터링: 자동 수집, 경고 출력, 로그 보존 설계
- 재현성: Docker로 동일한 환경 생성 가능

## 5. 평가 질의응답 (전체 문항)

발표 중 심사위원의 질문에 대응하기 위해 모든 평가 기준 항목에 대한 상세 답변을 준비했습니다.

### 항목 1 (기본 요건 검증)
- **Q: SSH 포트가 20022로 변경되었고, Root 원격 접속이 차단되었는가?**
  - A: 네, 포트 변경과 Root 접속 차단을 통해 자동 스캐닝 및 무차별 대입 공격 노출을 최소화하고, 직접적인 시스템 최고 권한 탈취를 방지했습니다.
- **Q: 방화벽이 활성화되어 있고, 20022/tcp와 15034/tcp만 허용되는가?**
  - A: UFW를 활성화하여 기본 Inbound를 차단하고, 필수 포트만 허용함으로써 최소 권한 네트워크 접근 원칙을 적용했습니다.
- **Q: agent-admin/dev/test 계정과 agent-common/core 그룹이 요구사항대로 구성되어 있는가?**
  - A: 역할 분리와 최소 권한 적용을 위해 계정과 그룹을 명확히 분리하여 권한 관리와 감사가 용이하도록 구성했습니다.
- **Q: 앱이 Boot Sequence 5단계를 통과하고 "Agent READY"가 출력되는가?**
  - A: 네, 모든 초기화가 정상적으로 끝났음을 로그를 통해 검증하였으며, 이를 통해 외부 서비스가 트래픽을 보낼 수 있는 상태임을 확인했습니다.
- **Q: monitor.sh가 상태를 점검하고, 비정상 상태에서 exit 1로 종료되는가?**
  - A: `pgrep`과 `ss` 명령으로 점검하며, 포트 미바인드 등 이상 시 즉각 exit 1로 종료되어 자동 복구 시스템이 이를 감지할 수 있게 했습니다.
- **Q: monitor.log가 지정 포맷으로 누적 기록되는가?**
  - A: 타임스탬프와 `key=value` 포맷으로 누적 기록하여 파싱과 집계, 그리고 감사 증적에 유리하도록 구성했습니다.
- **Q: cron 매분 실행으로 로그가 자동 증가하는가?**
  - A: 주기적 상태 수집을 위해 cron을 통해 매분 실행되며, 추세 분석 및 이상 탐지가 가능합니다.
- **Q: 로그 용량 관리(10MB/10개)가 설정되어 있는가?**
  - A: `logrotate`를 이용해 디스크가 가득 차는 장애를 예방하고 적정량의 과거 기록만 안전하게 보관하도록 구현했습니다.

### 항목 2 (기술적 깊이)
- **Q: 프로세스 식별(pgrep)과 포트 확인(ss)에 사용한 명령의 선택 이유는?**
  - A: `pgrep -f`는 전체 커맨드라인 매칭으로 간결하며, `ss -tlnp`는 netstat보다 빠르고 정확하게 포트와 PID 매핑을 제공하기 때문입니다.
- **Q: 리소스 파싱 방식 및 로그 포맷을 고정한 이유는?**
  - A: `/proc/stat` 및 `/proc/meminfo` 등 커널 데이터를 `awk`로 직접 파싱해 오차를 줄였고, 고정된 `key=value` 형태는 ELK나 Prometheus 같은 관제 도구에서 자동화된 파싱과 알람 적용을 쉽게 합니다.
- **Q: 권한 정책을 어떻게 만족시켰는가?**
  - A: 민감한 `apikeys`는 소유자(`agent-dev`)와 특정 그룹(`agent-core`)으로 읽기를 640으로 제한하였고, 스크립트 실행은 관리자(`agent-admin`) 권한으로 명확히 구분했습니다.
- **Q: 용량 기반 로그 관리 구현 방식은?**
  - A: 업계 표준인 `logrotate`를 사용하여 파일 크기, 보관 개수, 압축 등의 정책을 가장 안정적이고 신뢰성 있게 처리했습니다.

### 항목 3 (보안 및 운영 철학)
- **Q: SSH 포트 변경 및 Root 차단의 위협 모델 관점에서의 효과는?**
  - A: 대부분의 스크립트 봇이 노리는 22번 포트를 우회하고, Root 직접 접근을 막음으로써 권한 상승(Privilege Escalation)을 위한 추가 취약점이 없다면 시스템 완전 장악을 막아냅니다.
- **Q: 주요 디렉토리를 agent-core로 제한한 이유는?**
  - A: '최소 권한 원칙(Least Privilege)'에 따라 필요한 주체에게만 접근을 허용하여, 계정 탈취 시 내부 정보 유출 및 오용의 위험을 극적으로 낮춥니다.
- **Q: 경고는 출력하되 종료하지 않는 항목을 분리한 이유는?**
  - A: 서비스 가용성을 유지하기 위함입니다. 치명적이지 않은 문제(임계치 초과 등)로 데몬이 수시로 재시작되는 것을 막고, 운영자가 개입할 여지를 주었습니다.
- **Q: 리다이렉션(`>>`, `2>`)이 로그 누적에 필요한 이유는?**
  - A: `>`(덮어쓰기)로 과거 기록이 유실되는 것을 방지하기 위해 `>>`(이어쓰기)를 썼으며, `2>&1`을 통해 예상치 못한 런타임 표준 에러까지 하나의 파일에 담아 정확한 장애 분석을 가능하게 합니다.

### 항목 4 (응용 및 트러블슈팅)
- **Q: 웹 서버 모니터링으로 바뀐다면 수정해야 할 부분은?**
  - A: 확인 대상 프로세스(Nginx), 포트(80/443), 로그 경로를 변경하고, 단순히 포트 바인딩 확인을 넘어 HTTP 헬스체크(curl 등)와 응답 시간 임계치 점검 로직을 추가해야 합니다.
- **Q: 트러블슈팅 - "프로세스는 살아있는데 포트가 안 열리는 상황" 대처법은?**
  - A: `ss`, `ps`, `lsof`로 바인딩 주소 및 충돌 여부를 확인합니다. 원인이 불분명할 경우 **`strace`**를 활용합니다. `strace -p <PID> -e trace=network,file` 또는 기동 시 `strace -e trace=bind,listen`으로 시스템 콜을 추적하면, 커널 레벨에서 발생하는 `EADDRINUSE`(포트 선점)나 `EACCES`(권한 부족) 에러를 명확히 찾아낼 수 있습니다.
- **Q: 로그 급증 시 운영자의 대응 방안은?**
  - A: 단기적으로는 로그 레벨을 Info 이하로 낮추고 `logrotate`를 즉시 수동 기동해 임시 디스크 공간을 확보합니다. 중장기적으로는 외부 중앙 집중형 로그 시스템(ELK) 도입, 로그 샘플링 적용, 그리고 이상 트래픽 발생 근본 원인을 해소해야 합니다.

## 6. 추가 설명

- `B1-1.md`는 원본 참고 문서로 보존하였고, 리포지토리 내에서는 별도 `README.md`와 `ASSIGNMENT_SPEC.md`를 중심으로 과제를 정리했습니다.
- `run_assignment.sh`를 실행하면 검증 결과가 `evidence/`에 저장되어, 발표 및 제출 시 완벽한 증빙 자료로 활용할 수 있습니다.
