# B1-1: 컴퓨터가 알아서 자기 상태를 점검하게 만들기

## 📋 과제 정보

| 항목 | 내용 |
|------|------|
| **과목** | Linux와 OS |
| **난이도** | ★☆☆ (Lv.1) |
| **학습 시간** | 40분 |
| **과제 번호** | 185004 |

---

## 🎯 미션 소개

Linux 서버 운영 자동화 프로젝트입니다. 다중 사용자 환경에서 권한 관리, 네트워크 보안 설정, 시스템 모니터링 자동화를 구현합니다. Docker 기반 Ubuntu 환경에서 SSH 보안 설정, 방화벽, 역할 기반 계정/그룹, 애플리케이션 배포, 리소스 모니터링, 로그 보존 정책을 직접 구축합니다.

---

## 🎓 학습 목표

이 과제를 완료한 뒤, 다음을 설명할 수 있어야 한다:

1. SSH 보안 설정이 기본 보안인 이유를 설명할 수 있다
2. UFW 방화벽의 최소 권한 정책 구성 원리를 설명할 수 있다
3. 역할 기반 계정/그룹의 권한 분리 방식을 설명할 수 있다
4. 환경 변수로 실행 환경을 고정하는 이유를 설명할 수 있다
5. 시스템 모니터링 데이터 수집 및 분석 흐름을 설명할 수 있다
6. 로그 보존 정책의 필요성을 설명할 수 있다

---

## 📦 최종 결과물

1. Docker 기반 Ubuntu 22.04 컨테이너 구축
2. SSH/UFW/계정 권한/모니터링/로그 자동화 스크립트
3. 실행 가능한 컨테이너 (Dockerfile 포함)
4. README (실행 방법, 구현 내용, 증거 자료)

---

## 🛠️ 개발 환경

### 6\. 개발 환경

*   Ubuntu 22.04 LTS 또는 동등 리눅스 환경
*   이전 미션에서 구성한 Linux 실습 환경(컨테이너/VM)을 그대로 사용 권장

---

## ⚠️ 제약 사항

### 7\. 제약 사항

*   구현 언어/도구
    *   자동화 스크립트는 Bash로만 작성한다(Python 등으로 대체 금지)
    *   필요한 경우에만 sudo 사용(가능한 일반 계정으로 진행)
*   제공 애플리케이션
    *   제공된 Python 앱은 “실행 대상”이며, 과제의 핵심은 관제/자동화 스크립트 구현이다.

---

## 📝 결과 예시

### 8\. 결과 예시

아래는 정답이 아니라 참고 예시다. 실제 문구와 구성은 달라도 된다.

*   앱 Boot Sequence 출력 예시
    
    ```css
    > Starting Agent Boot Sequence...
    [1/5] Checking User Account               [OK]
    ... Running as service user 'agent-admin' (uid=1001)
    [2/5] Verifying Environment Variables     [OK]
    ... All required Envs correct
    [3/5] Checking Required Files             [OK]
    ... Verified key file with correct key string.
    [4/5] Checking Port Availability          [OK]
    ... Port 15034 is available.
    [5/5] Verifying Log Permission            [OK]
    ... Log directory is writable: /var/log/agent-app
    ------------------------------------------------------------
    All Boot Checks Passed!
    Agent READY
    ```
    
*   [monitor.sh](http://monitor.sh) 콘솔 출력 예시
    
    ```css
    ====== SYSTEM MONITOR RESULT ======
    
    [HEALTH CHECK]
    Checking process 'agent_app.py'... [OK] (PID: 48291)
    Checking port 15034... [OK]
    
    [RESOURCE MONITORING]
    CPU Usage : 25.3%
    MEM Usage : 5.2%
    DISK Used  : 23%
    
    [WARNING] CPU threshold exceeded (25.3% > 20%)
    
    ====== STATISTICS REPORT ======
    [CPU]
    Average : 21.4%
    Maximum : 25.3% at 2026-02-25 14:00:05
    Minimum : 10.2% at 2026-02-25 13:58:05
    [Memory]
    Average : 6.1%
    Maximum : 9.8% at 2026-02-25 14:00:05
    Minimum : 3.2% at 2026-02-25 13:58:05
    [Samples]
    Data Points: 10 samples
    
    [INFO] Log appended: /var/log/agent-app/monitor.log
    ```
    
*   monitor.log 누적 예시
    
    ```css
    [2026-02-25 13:58:01] PID:48291 CPU:10.2% MEM:3.2% DISK_USED:23%
    [2026-02-25 13:59:01] PID:48291 CPU:18.7% MEM:5.0% DISK_USED:23%
    [2026-02-25 14:00:01] PID:48291 CPU:25.3% MEM:9.8% DISK_USED:23%
    ```
    
*   (보너스 수행 시) report.sh 콘솔 출력 예시
    
    ```css
        ====== STATISTICS REPORT ======
          [CPU]
            Average : 21.4%
            Maximum : 25.3% at 2026-02-25 14:00:05
            Minimum : 10.2% at 2026-02-25 13:58:05
          [Memory]
            Average : 6.1%
            Maximum : 9.8% at 2026-02-25 14:00:05
            Minimum : 3.2% at 2026-02-25 13:58:05
          [Samples]
            Data Points: 10 samples
    ```

---

## 📦 제공 파일

agent-app-linux-x86 (x86)
agent-app-linux-arm64 (arm apple)

**다운로드**: https://dvg0ukilu1mqr.cloudfront.net/pjt7938015c-b538-4ab0-b52d-d512f7476603_agent-app.zip

---

> *이 문서는 Codyssey AI/SW 기초 과정의 과제 내용을 기반으로 작성되었습니다.*
