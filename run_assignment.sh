#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
IMAGE="b1-1-ubuntu"
CONTAINER="b1-1-assignment"
EVIDENCE_DIR="evidence"

mkdir -p "$EVIDENCE_DIR"

# 마크다운 헤더 출력 헬퍼
function write_header() {
  local file="$1"
  local title="$2"
  printf '# %s\n\n' "$title" >> "$file"
}

function write_section() {
  local file="$1"
  local title="$2"
  printf '## %s\n\n' "$title" >> "$file"
}

# 명령어와 결과를 각각 별도 코드블록으로 출력하는 헬퍼 (컨테이너 명령 / 실패허용)
function md_container_cmd() {
  local file="$1"
  local title="$2"
  local cmd="$3"
  local allow_fail="${4:-false}"

  printf '### %s\n\n' "$title" >> "$file"
  printf '**명령어**\n\n```bash\n%s\n```\n\n' "$cmd" >> "$file"
  printf '**결과**\n\n```\n' >> "$file"
  if [ "$allow_fail" = "true" ]; then
    docker exec "$CONTAINER" bash -lc "$cmd" >> "$file" 2>&1 || true
  else
    docker exec "$CONTAINER" bash -lc "$cmd" >> "$file" 2>&1
  fi
  printf '```\n\n' >> "$file"
}

# 명령어와 결과를 각각 별도 코드블록으로 출력하는 헬퍼 (로컬 명령)
function md_local_cmd() {
  local file="$1"
  local title="$2"
  local cmd="$3"
  local allow_fail="${4:-false}"

  printf '### %s\n\n' "$title" >> "$file"
  printf '**명령어**\n\n```bash\n%s\n```\n\n' "$cmd" >> "$file"
  printf '**결과**\n\n```\n' >> "$file"
  if [ "$allow_fail" = "true" ]; then
    bash -lc "$cmd" >> "$file" 2>&1 || true
  else
    bash -lc "$cmd" >> "$file" 2>&1
  fi
  printf '```\n\n' >> "$file"
}

# 컨테이너에서 직접 실행하고 결과를 마크다운으로 기록 (raw output, 헤더/섹션 없음)
function md_raw_container() {
  local file="$1"
  local cmd="$2"
  printf '**명령어**\n\n```bash\n%s\n```\n\n' "$cmd" >> "$file"
  printf '**결과**\n\n```\n' >> "$file"
  docker exec "$CONTAINER" bash -lc "$cmd" >> "$file" 2>&1 || true
  printf '```\n\n' >> "$file"
}

# ===========================
printf '=== Docker build ===\n'
docker_build_cmd="docker build -t $IMAGE ."
printf '%s\n' "\$ $docker_build_cmd"
bash -lc "$docker_build_cmd"
printf 'Docker build complete.\n'

printf '=== Container start ===\n'
container_run_cmd="docker rm -f $CONTAINER >/dev/null 2>&1 || true && docker run -d --name \"$CONTAINER\" --cap-add NET_ADMIN --cap-add NET_BIND_SERVICE -p 22022:20022 -p 15034:15034 \"$IMAGE\""
printf '%s\n' "\$ $container_run_cmd"
container_id=$(bash -lc "$container_run_cmd")
printf '%s\n' "$container_id"
printf 'Container started: %s\n' "$container_id"

printf 'Waiting for init services...\n'
sleep 12

# ===========================
# SSH / Firewall
# ===========================
{
  printf '# SSH 및 방화벽(UFW) 설정 증거\n\n'
} > "$EVIDENCE_DIR/ssh_firewall.md"

md_container_cmd "$EVIDENCE_DIR/ssh_firewall.md" \
  "SSH 포트·루트로그인·비밀번호인증 설정 확인" \
  "grep -E '^Port |^PermitRootLogin |^PasswordAuthentication ' /etc/ssh/sshd_config || grep -E 'Port|PermitRootLogin|PasswordAuthentication' /etc/ssh/sshd_config" \
  "true"

md_container_cmd "$EVIDENCE_DIR/ssh_firewall.md" \
  "UFW 방화벽 상태 상세 확인 (기본 정책 및 허용 포트)" \
  "ufw status verbose" \
  "true"

md_container_cmd "$EVIDENCE_DIR/ssh_firewall.md" \
  "UFW 기본(Default) 정책 요약" \
  "ufw status verbose | grep -E 'Default:|Status:' || true" \
  "true"

# ===========================
# Accounts / Groups
# ===========================
{
  printf '# 계정 및 그룹 설정 증거\n\n'
} > "$EVIDENCE_DIR/groups_users.md"

md_container_cmd "$EVIDENCE_DIR/groups_users.md" \
  "사용자 계정 및 그룹 멤버십 확인" \
  "id agent-admin && id agent-dev && id agent-test" \
  "true"

md_container_cmd "$EVIDENCE_DIR/groups_users.md" \
  "그룹 멤버 목록 확인" \
  "getent group agent-common && getent group agent-core" \
  "true"

# ===========================
# Permissions
# ===========================
{
  printf '# 디렉토리 권한 및 ACL 증거\n\n'
} > "$EVIDENCE_DIR/permissions.md"

md_container_cmd "$EVIDENCE_DIR/permissions.md" \
  "디렉토리 소유자·권한 확인 (ls -ld)" \
  "ls -ld /home/agent-admin/agent-app /home/agent-admin/agent-app/upload_files /home/agent-admin/agent-app/api_keys /var/log/agent-app" \
  "true"

md_container_cmd "$EVIDENCE_DIR/permissions.md" \
  "ACL(Access Control List) 상세 확인 (getfacl)" \
  "getfacl /home/agent-admin/agent-app/upload_files /home/agent-admin/agent-app/api_keys /var/log/agent-app 2>/dev/null || true" \
  "true"

# ===========================
# App Start / Boot Sequence
# ===========================
{
  printf '# 애플리케이션 부트 시퀀스 증거\n\n'
} > "$EVIDENCE_DIR/app_start.md"

# AGENT_KEY_PATH는 디렉토리 경로 (바이너리가 디렉토리를 기대함)
start_cmd='su - agent-admin -c "cd /home/agent-admin/agent-app && env AGENT_HOME=/home/agent-admin/agent-app AGENT_PORT=15034 AGENT_UPLOAD_DIR=/home/agent-admin/agent-app/upload_files AGENT_KEY_PATH=/home/agent-admin/agent-app/api_keys AGENT_LOG_DIR=/var/log/agent-app nohup /usr/local/bin/agent-app > /home/agent-admin/agent-app/agent_app.log 2>&1 & echo \$!"'

md_container_cmd "$EVIDENCE_DIR/app_start.md" \
  "agent-app 백그라운드 기동 (agent-admin 계정)" \
  "$start_cmd" \
  "true"

sleep 6

md_container_cmd "$EVIDENCE_DIR/app_start.md" \
  "포트 15034 LISTEN 상태 확인" \
  "ss -tlnp | grep -E ':15034\\b' || true" \
  "true"

md_container_cmd "$EVIDENCE_DIR/app_start.md" \
  "Agent READY 및 Boot Checks Passed 확인" \
  "grep -E 'Agent READY|Listening at port 15034|Boot Checks Passed' /home/agent-admin/agent-app/agent_app.log || true" \
  "true"

printf '\n## 부트 시퀀스 5단계 개별 검증\n\n' >> "$EVIDENCE_DIR/app_start.md"

md_container_cmd "$EVIDENCE_DIR/app_start.md" \
  "Boot Sequence 5단계 전체 [OK] 확인" \
  "grep -E '^\[([1-5])/5\]' /home/agent-admin/agent-app/agent_app.log | grep '\[OK\]'" \
  "true"

# ===========================
# Monitor Script Run
# ===========================
{
  printf '# monitor.sh 실행 결과 증거\n\n'
} > "$EVIDENCE_DIR/monitor_run.md"

md_container_cmd "$EVIDENCE_DIR/monitor_run.md" \
  "monitor.sh 수동 실행 (Health Check + 리소스 수집)" \
  "/home/agent-admin/agent-app/bin/monitor.sh" \
  "true"

md_container_cmd "$EVIDENCE_DIR/monitor_run.md" \
  "monitor.log 최근 5라인 확인 (로그 누적 확인)" \
  "tail -n 5 /var/log/agent-app/monitor.log || true" \
  "true"

# ===========================
# Cron 70초 대기 후 확인
# ===========================
printf 'Waiting 70 seconds for cron to execute...\n'
sleep 70

{
  printf '# Cron 자동 실행 및 로그 누적 증거\n\n'
} > "$EVIDENCE_DIR/cron_check.md"

md_container_cmd "$EVIDENCE_DIR/cron_check.md" \
  "agent-admin 크론탭 등록 내용 확인" \
  "crontab -u agent-admin -l" \
  "false"

md_container_cmd "$EVIDENCE_DIR/cron_check.md" \
  "monitor.log 최근 10라인 (크론 자동 실행 후 누적 확인)" \
  "tail -n 10 /var/log/agent-app/monitor.log" \
  "true"

# ===========================
# Logrotate / Retention
# ===========================
{
  printf '# 로그 보존 정책 증거\n\n'
} > "$EVIDENCE_DIR/logrotate.md"

md_container_cmd "$EVIDENCE_DIR/logrotate.md" \
  "logrotate 설정 파일 내용 (daily 회전 / 30개 보관)" \
  "cat /etc/logrotate.d/agent-app" \
  "true"

md_container_cmd "$EVIDENCE_DIR/logrotate.md" \
  "agent-log-retention.sh 스크립트 내용 (7일 압축 / 30일 삭제)" \
  "cat /usr/local/bin/agent-log-retention.sh" \
  "true"

md_container_cmd "$EVIDENCE_DIR/logrotate.md" \
  "크론탭에 등록된 로그 보존 정책 실행 스케줄 확인" \
  "crontab -u agent-admin -l | grep -E '/home/agent-admin/agent-app/bin/monitor.sh|agent-log-retention.sh' || true" \
  "true"

# ===========================
# Bonus Report
# ===========================
{
  printf '# 통계 리포트 (report.sh) 실행 증거\n\n'
} > "$EVIDENCE_DIR/bonus_report.md"

md_container_cmd "$EVIDENCE_DIR/bonus_report.md" \
  "report.sh 전체 로그 통계 분석" \
  "/home/agent-admin/agent-app/bin/report.sh /var/log/agent-app/monitor.log" \
  "true"

# ===========================
printf '=== Evidence summary ===\n'
printf '%s\n' "- ssh/firewall results: $EVIDENCE_DIR/ssh_firewall.md"
printf '%s\n' "- group/user results:   $EVIDENCE_DIR/groups_users.md"
printf '%s\n' "- permissions results:  $EVIDENCE_DIR/permissions.md"
printf '%s\n' "- app start output:     $EVIDENCE_DIR/app_start.md"
printf '%s\n' "- monitor run output:   $EVIDENCE_DIR/monitor_run.md"
printf '%s\n' "- cron log results:     $EVIDENCE_DIR/cron_check.md"
printf '%s\n' "- logrotate results:    $EVIDENCE_DIR/logrotate.md"
printf '%s\n' "- bonus report output:  $EVIDENCE_DIR/bonus_report.md"
