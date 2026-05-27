# CHECKLIST

## 1. 환경 준비

- [ ] `Dockerfile`로 Ubuntu 22.04 이미지 빌드
- [ ] 컨테이너 실행 및 `sshd`, `cron` 동작 확인
- [ ] `B1-1.md` 원본은 수정하지 않음

## 2. SSH 및 방화벽

- [ ] `/etc/ssh/sshd_config`에서 `Port 20022` 설정
- [ ] `PermitRootLogin no` 설정
- [ ] `ufw` 또는 `firewall-cmd`가 활성화됨
- [ ] `20022/tcp`, `15034/tcp`만 허용됨

## 3. 사용자/그룹/권한

- [ ] 계정 생성: `agent-admin`, `agent-dev`, `agent-test`
- [ ] 그룹 생성: `agent-common`, `agent-core`
- [ ] `agent-admin`과 `agent-dev`가 `agent-core`에 포함됨
- [ ] 디렉토리 생성: `$AGENT_HOME`, `$AGENT_HOME/upload_files`, `$AGENT_HOME/api_keys`, `/var/log/agent-app`
- [ ] `upload_files`는 `agent-common` 그룹 접근 허용
- [ ] `api_keys`와 `/var/log/agent-app`은 `agent-core` 전용 접근

## 4. 애플리케이션 실행

- [ ] `AGENT_HOME` 환경 변수 설정
- [ ] `t_secret.key` 생성 및 내용 확인
- [ ] 일반 계정으로 앱 실행
- [ ] Boot Sequence 5단계 통과 및 `Agent READY` 출력
- [ ] `0.0.0.0:15034` LISTEN 확인

## 5. 모니터링 자동화

- [ ] `monitor.sh` 작성 및 실행 권한 설정
- [ ] 소유자 `agent-dev`, 그룹 `agent-core`, 권한 `750`
- [ ] Health Check: 프로세스/포트 정상 확인
- [ ] 경고 출력: 방화벽, CPU/MEM/DISK 임계값
- [ ] `monitor.log`에 누적 기록 저장
- [ ] 로그 용량 관리 구현
- [ ] `agent-admin` crontab에 매분 등록
- [ ] 1~2분 후 `monitor.log`에 새 라인 기록 확인

## 6. 보너스

- [ ] `report.sh`로 `monitor.log` 요약 리포트 생성
- [ ] 로그 압축과 아카이브/삭제 정책 문서화 또는 구현

## 7. 증거 수집

- [ ] `evidence/`에 실행 결과를 리다이렉션하여 저장
- [ ] `README.md`에 증거 문서 링크 추가
- [ ] `PRESENTATION_SCRIPT.md`로 평가 대본 준비
