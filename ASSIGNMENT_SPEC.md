# ASSIGNMENT SPEC

## 목표

- Ubuntu Docker 환경에서 `B1-1` 과제를 재현한다.
- 보안 설정, 계정/그룹/권한 설계, 애플리케이션 실행 환경 구성, 모니터링 자동화를 구현한다.
- 과제 목표를 이해하고 설명할 수 있게 문서화한다.

## 요구사항 요약

### 1. 보안 및 네트워크 설정

- SSH 포트를 `20022`로 변경
- Root 원격 로그인을 차단
- UFW 또는 firewalld 중 하나를 활성화
- 인바운드 포트는 `20022/tcp`, `15034/tcp`만 허용

### 2. 계정/그룹/디렉토리 권한

- 생성 계정
  - `agent-admin`
  - `agent-dev`
  - `agent-test`
- 생성 그룹
  - `agent-common`: admin, dev, test
  - `agent-core`: admin, dev
- 디렉토리
  - `$AGENT_HOME`
  - `$AGENT_HOME/upload_files`
  - `$AGENT_HOME/api_keys`
  - `/var/log/agent-app`
- 권한 정책
  - `upload_files`: group=agent-common, R/W
  - `api_keys`, `/var/log/agent-app`: group=agent-core ONLY, R/W

### 3. 애플리케이션 실행 환경

- 환경 변수
  - `AGENT_HOME`
  - `AGENT_PORT=15034`
  - `AGENT_UPLOAD_DIR`
  - `AGENT_KEY_PATH` (키 디렉토리 경로)
  - `AGENT_LOG_DIR=/var/log/agent-app`
- 키 파일 생성
  - 경로: `$AGENT_HOME/api_keys/t_secret.key`
  - 내용: `agent_api_key_test`
- 실행 기준
  - 일반 계정으로 실행
  - Boot Sequence 5단계 `[OK]` 출력
  - 마지막에 `Agent READY`
  - `0.0.0.0:15034` LISTEN 확인

### 4. 자동화 스크립트 `monitor.sh`

- 위치: `$AGENT_HOME/bin/monitor.sh`
- 소유자: `agent-dev`
- 그룹: `agent-core`
- 권한: `750`
- cron 실행 계정: `agent-admin`
- Health Check
  - 프로세스 확인
  - 포트 확인
- 경고
  - 방화벽 비활성 시 `[WARNING]`
  - `CPU > 20%`, `MEM > 10%`, `DISK_USED > 80%`
- 로그
  - 파일: `/var/log/agent-app/monitor.log`
  - 포맷: `[YYYY-MM-DD HH:MM:SS] PID:... CPU:..% MEM:..% DISK_USED:..%`
- 로그 용량 관리
  - 최대 10MB / 10개 파일 유지
- cron 매분 실행 등록

## 보너스 기능

### 보너스 1: `report.sh`

- `monitor.log`를 분석하여 CPU/MEM/DISK 평균, 최대, 최소, 샘플 수 출력
- 선택: 시작/종료 시간 구간 분석

### 보너스 2: 로그 보존 정책

- 7일 경과 로그 압축 및 아카이브
- 30일 경과 아카이브 삭제
- 디렉토리 미존재, 권한 부족, 파일 없음 등의 예외 처리
