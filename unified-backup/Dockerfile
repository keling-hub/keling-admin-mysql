FROM mysql:8.0

RUN microdnf -y update && \
    microdnf -y install cronie tzdata ca-certificates jq python3-pip curl tar gzip && \
    microdnf clean all

# 安装 restic 二进制（.bz2 包）
ENV RESTIC_VERSION=0.16.4
RUN curl -fsSL -o /tmp/restic.bz2 "https://github.com/restic/restic/releases/download/v${RESTIC_VERSION}/restic_${RESTIC_VERSION}_linux_amd64.bz2" && \
    bunzip2 /tmp/restic.bz2 && mv /tmp/restic /usr/local/bin/restic && chmod +x /usr/local/bin/restic

# Python 依赖（用于 export_browse.py）
RUN pip3 install --no-cache-dir pymysql cryptography

WORKDIR /app

COPY entrypoint.sh /app/entrypoint.sh
COPY mysql-backup.sh /app/mysql/backup.sh
COPY media-cleanup.sh /app/media/cleanup.sh
COPY export_browse.py /app/media/export_browse.py
COPY sync-to-e-drive.sh /app/sync-to-e-drive.sh

RUN chmod +x /app/entrypoint.sh /app/mysql/backup.sh /app/media/cleanup.sh /app/sync-to-e-drive.sh && \
    sed -i 's/\r$//' /app/entrypoint.sh /app/mysql/backup.sh /app/media/cleanup.sh /app/sync-to-e-drive.sh

VOLUME ["/backup", "/data"]

ENTRYPOINT ["/app/entrypoint.sh"]


