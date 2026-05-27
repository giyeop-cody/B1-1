FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV AGENT_HOME=/home/agent-admin/agent-app
ENV AGENT_PORT=15034
ENV AGENT_UPLOAD_DIR=/home/agent-admin/agent-app/upload_files
ENV AGENT_KEY_PATH=/home/agent-admin/agent-app/api_keys
ENV AGENT_KEY_FILE=/home/agent-admin/agent-app/api_keys/secret.key
ENV AGENT_LOG_DIR=/var/log/agent-app
ENV AGENT_ARCHIVE_DIR=/var/log/monitor/agent-app/archive

RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-server \
    ufw \
    cron \
    logrotate \
    iproute2 \
    procps \
    grep \
    gawk \
    gzip \
    acl \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd --system agent-common && \
    groupadd --system agent-core && \
    useradd --create-home --home-dir /home/agent-admin --shell /bin/bash --gid agent-common --groups agent-core agent-admin && \
    useradd --create-home --home-dir /home/agent-dev --shell /bin/bash --gid agent-common --groups agent-core agent-dev && \
    useradd --create-home --home-dir /home/agent-test --shell /bin/bash --gid agent-common agent-test

RUN mkdir -p $AGENT_HOME/bin $AGENT_UPLOAD_DIR $AGENT_HOME/api_keys $AGENT_LOG_DIR /var/run/sshd && \
    chown -R agent-admin:agent-common $AGENT_HOME && \
    chown agent-admin:agent-common $AGENT_UPLOAD_DIR && chmod 770 $AGENT_UPLOAD_DIR && \
    chown agent-admin:agent-core $AGENT_HOME/api_keys && chmod 770 $AGENT_HOME/api_keys && \
    chown agent-admin:agent-core $AGENT_LOG_DIR && chmod 770 $AGENT_LOG_DIR && \
    chmod 755 /var/run/sshd

COPY agent-app-linux-x86 /usr/local/bin/agent-app
COPY monitor.sh /home/agent-admin/agent-app/bin/monitor.sh
COPY report.sh /home/agent-admin/agent-app/bin/report.sh

RUN mkdir -p /var/log/monitor/agent-app/archive && \
    chown agent-admin:agent-core /var/log/monitor/agent-app/archive && \
    chmod 750 /var/log/monitor/agent-app/archive

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

mkdir -p "$ARCHIVE_DIR"
chown agent-admin:agent-core "$ARCHIVE_DIR"
chmod 750 "$ARCHIVE_DIR"

find "$LOG_DIR" -maxdepth 1 -type f -name '*.log' -mtime +6 -print0 | while IFS= read -r -d '' file; do
    gzip -f "$file"
    mv -f "${file}.gz" "$ARCHIVE_DIR/"
done

find "$ARCHIVE_DIR" -maxdepth 1 -type f -name '*.gz' -mtime +29 -print0 | xargs -0 rm -f -- || true
EOF

RUN chmod 750 /usr/local/bin/agent-log-retention.sh && \
    chown agent-admin:agent-core /usr/local/bin/agent-log-retention.sh && \
    chmod 755 /usr/local/bin/agent-app && \
    chown agent-admin:agent-common /usr/local/bin/agent-app && \
    chmod 750 /home/agent-admin/agent-app/bin/monitor.sh && \
    chmod 750 /home/agent-admin/agent-app/bin/report.sh && \
    chown agent-dev:agent-core /home/agent-admin/agent-app/bin/monitor.sh && \
    chown agent-dev:agent-core /home/agent-admin/agent-app/bin/report.sh && \
    echo "agent_api_key_test" > $AGENT_KEY_FILE && \
    chown agent-admin:agent-core $AGENT_KEY_FILE && chmod 640 $AGENT_KEY_FILE && \
    ln -sf secret.key /home/agent-admin/agent-app/api_keys/t_secret.key && \
    echo "agent-admin:agentadmin" | chpasswd && \
    echo "agent-dev:agentdev" | chpasswd && \
    echo "agent-test:agenttest" | chpasswd

RUN sed -i 's/#Port 22/Port 20022/' /etc/ssh/sshd_config && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config || true && \
    sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config || true && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config || true && \
    sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config || true

RUN ufw default deny incoming && ufw default allow outgoing && ufw allow 20022/tcp && ufw allow 15034/tcp

RUN { \
      echo "* * * * * /home/agent-admin/agent-app/bin/monitor.sh >/dev/null 2>&1"; \
      echo "0 0 * * * /usr/local/bin/agent-log-retention.sh >/dev/null 2>&1"; \
    } | crontab -u agent-admin -

EXPOSE 20022 15034
CMD ["sh", "-c", "if command -v ufw >/dev/null 2>&1; then ufw default deny incoming && ufw default allow outgoing && ufw --force enable; fi; service ssh start; service cron start; crontab -u agent-admin -l >/dev/null 2>&1 || { echo '* * * * * /home/agent-admin/agent-app/bin/monitor.sh >/dev/null 2>&1'; echo '0 0 * * * /usr/local/bin/agent-log-retention.sh >/dev/null 2>&1'; } | crontab -u agent-admin -; tail -f /dev/null"]
