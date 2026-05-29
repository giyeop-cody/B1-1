요구 문서(Copied text 1780015524, Copied text 1780015655)와 비교해서 어떤 차이가 있는지 설명 





FROM ubuntu:22.04



# --------------------------------------------------------------------

# 1. 필수 패키지 설치 및 환경 설정

# --------------------------------------------------------------------

ENV DEBIAN_FRONTEND=noninteractive



RUN apt-get update && apt-get install -y --no-install-recommends \

    openssh-server \

    ufw \

    sudo \

    python3 \

    python3-pip \

    cron \

    logrotate \

    iproute2 \

    procps \

    grep \

    gawk \

    gzip \

    acl \

    bc \

    && rm -rf /var/lib/apt/lists/*



# --------------------------------------------------------------------

# 2. 환경 변수 정의 (과제 요구사항 고정)

# --------------------------------------------------------------------

ENV AGENT_HOME=/home/agent-admin/agent-app

ENV AGENT_PORT=15034

ENV AGENT_UPLOAD_DIR=/home/agent-admin/agent-app/upload_files

# 명세 요구사항: AGENT_KEY_PATH는 실제 키 파일의 전체 경로를 가리킴

ENV AGENT_KEY_PATH=/home/agent-admin/agent-app/api_keys/t_secret.key

ENV AGENT_KEY_FILE=/home/agent-admin/agent-app/api_keys/secret.key

ENV AGENT_LOG_DIR=/var/log/agent-app

ENV AGENT_ARCHIVE_DIR=/var/log/monitor/agent-app/archive



# --------------------------------------------------------------------

# 3. 계정 및 역할 기반 그룹 체계 구성 (협업 + 최소 권한)

# --------------------------------------------------------------------

RUN groupadd --system agent-common && \

    groupadd --system agent-core && \

    useradd --create-home --home-dir /home/agent-admin --shell /bin/bash --gid agent-common --groups agent-core,agent-admin agent-admin && \

    useradd --create-home --home-dir /home/agent-dev --shell /bin/bash --gid agent-common --groups agent-core,agent-dev agent-dev && \

    useradd --create-home --home-dir /home/agent-test --shell /bin/bash --gid agent-common agent-test



# 사용자 비밀번호 설정

RUN echo "agent-admin:agentadmin" | chpasswd && \

    echo "agent-dev:agentdev" | chpasswd && \

    echo "agent-test:agenttest" | chpasswd



# --------------------------------------------------------------------

# 4. 기본 디렉토리 구조 생성 및 1차 소유권 할당

# --------------------------------------------------------------------

# 중요: $AGENT_KEY_PATH는 파일 경로이므로 상위 디렉토리인 $AGENT_HOME/api_keys를 생성해야 함

RUN mkdir -p $AGENT_HOME/bin $AGENT_UPLOAD_DIR $AGENT_HOME/api_keys $AGENT_LOG_DIR /var/run/sshd && \

    chown -R agent-admin:agent-common $AGENT_HOME



# SSH 접근을 위한 기본 디렉토리 구성

RUN mkdir -p /home/agent-admin/.ssh /home/agent-dev/.ssh /home/agent-test/.ssh && \

    chmod 700 /home/agent-admin/.ssh /home/agent-dev/.ssh /home/agent-test/.ssh



COPY id_rsa.pub /home/agent-admin/.ssh/authorized_keys

RUN chmod 600 /home/agent-admin/.ssh/authorized_keys && chown -R agent-admin:agent-admin /home/agent-admin/.ssh



# --------------------------------------------------------------------

# 5. 애플리케이션 및 관제 스크립트 배치

# --------------------------------------------------------------------

COPY agent-app-linux-x86 /usr/local/bin/agent-app

COPY monitor.sh /home/agent-admin/agent-app/bin/monitor.sh

COPY report.sh /home/agent-admin/agent-app/bin/report.sh



# --------------------------------------------------------------------

# 6. 명세서 기준 디렉토리/파일 권한 및 ACL 세부 설정

# --------------------------------------------------------------------

# 1) upload_files: group=agent-common, R/W 가능, 하위 상속 ACL 적용

RUN chown agent-admin:agent-common $AGENT_UPLOAD_DIR && \

    chmod 770 $AGENT_UPLOAD_DIR && \

    chmod g+s $AGENT_UPLOAD_DIR && \

    setfacl -d -m g:agent-common:rwx $AGENT_UPLOAD_DIR



# 2) api_keys 디렉토리: group=agent-core ONLY, 외부인 차단

RUN chown agent-admin:agent-core $AGENT_HOME/api_keys && \

    chmod 750 $AGENT_HOME/api_keys && \

    chmod g+s $AGENT_HOME/api_keys && \

    setfacl -d -m g:agent-core:rwx $AGENT_HOME/api_keys && \

    setfacl -m o::--- $AGENT_HOME/api_keys



# 3) /var/log/agent-app 디렉토리: 외부 경로이므로 명시적 권한 격리 (agent-core ONLY)

RUN chown agent-admin:agent-core $AGENT_LOG_DIR && \

    chmod 750 $AGENT_LOG_DIR && \

    chmod g+s $AGENT_LOG_DIR && \

    setfacl -d -m g:agent-core:rwx $AGENT_LOG_DIR && \

    setfacl -m o::--- $AGENT_LOG_DIR



# 4) 핵심 인증 키 파일 생성 및 심볼릭 링크 처리

RUN echo "agent_api_key_test" > $AGENT_KEY_FILE && \

    chown agent-admin:agent-core $AGENT_KEY_FILE && \

    chmod 640 $AGENT_KEY_FILE && \

    ln -sf secret.key $AGENT_KEY_PATH && \

    chown -h agent-admin:agent-core $AGENT_KEY_PATH



# 5) 관제 스크립트 권한 수정 (소유자: agent-dev, 그룹: agent-core, 권한: 750)

RUN chmod 750 /home/agent-admin/agent-app/bin/monitor.sh && \

    chmod 750 /home/agent-admin/agent-app/bin/report.sh && \

    chown agent-dev:agent-core /home/agent-admin/agent-app/bin/monitor.sh && \

    chown agent-dev:agent-core /home/agent-admin/agent-app/bin/report.sh && \

    chown agent-admin:agent-common /usr/local/bin/agent-app && \

    chmod 750 /usr/local/bin/agent-app



# --------------------------------------------------------------------

# 7. 보너스 요구사항: 로그 관리 정책 (logrotate & 보존 스크립트)

# --------------------------------------------------------------------

RUN mkdir -p $AGENT_ARCHIVE_DIR && \

    chown agent-admin:agent-core $AGENT_ARCHIVE_DIR && \

    chmod 750 $AGENT_ARCHIVE_DIR



RUN cat > /etc/logrotate.d/agent-app <<EOF

${AGENT_LOG_DIR}/*.log {

    daily

    missingok

    rotate 30

    compress

    copytruncate

    notifempty

    dateext

    dateformat -%Y%m%d%H%M%S

    olddir ${AGENT_ARCHIVE_DIR}

    create 640 agent-admin agent-core

    sharedscripts

    postrotate

        install -d -m 750 -o agent-admin -g agent-core ${AGENT_ARCHIVE_DIR}

    endscript

}

EOF



RUN cat > /usr/local/bin/agent-log-retention.sh <<EOF

#!/usr/bin/env bash

set -euo pipefail



ARCHIVE_DIR=${AGENT_ARCHIVE_DIR}

LOG_DIR=${AGENT_LOG_DIR}



mkdir -p "\$ARCHIVE_DIR"

chown agent-admin:agent-core "\$ARCHIVE_DIR"

chmod 750 "\$ARCHIVE_DIR"



find "\$LOG_DIR" -maxdepth 1 -type f -name '*.log' -mtime +6 -print0 | while IFS= read -r -d '' file; do

    gzip -f "\$file"

    mv -f "\${file}.gz" "\$ARCHIVE_DIR/"

done



find "\$ARCHIVE_DIR" -maxdepth 1 -type f -name '*.gz' -mtime +29 -print0 | xargs -0 rm -f -- || true

EOF



RUN chmod 750 /usr/local/bin/agent-log-retention.sh && \

    chown agent-admin:agent-core /usr/local/bin/agent-log-retention.sh



# --------------------------------------------------------------------

# 8. 네트워크 보안 (SSH 포트 변경, 인증 비활성화 및 UFW 기본 정책)

# --------------------------------------------------------------------

RUN sed -i 's/#Port 22/Port 20022/' /etc/ssh/sshd_config && \

    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config || true && \

    sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config || true && \

    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config || true && \

    sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config || true && \

    chmod 755 /var/run/sshd



# --------------------------------------------------------------------

# 9. 크론 스케줄링 자동화 등록 (agent-admin 사용자 크론탭)

# --------------------------------------------------------------------

RUN { \

      echo "* * * * * /home/agent-admin/agent-app/bin/monitor.sh >/dev/null 2>&1"; \

      echo "0 0 * * * /usr/local/bin/agent-log-retention.sh >/dev/null 2>&1"; \

    } | crontab -u agent-admin -



# 외부 포트 개방 안내

EXPOSE 20022 15034



# --------------------------------------------------------------------

# 10. 컨테이너 인라인 부트스트랩 (서비스 활성화 및 네트워크 통제 강제)

# --------------------------------------------------------------------

CMD ["sh", "-c", "\

    if command -v ufw >/dev/null 2>&1; then \

        ufw default deny incoming && \

        ufw default allow outgoing && \

        ufw allow 20022/tcp && \

        ufw allow 15034/tcp && \

        ufw --force enable; \

    fi; \

    service ssh start; \

    service cron start; \

    tail -f /dev/null"]
