# Stage 1: download telegram-mcp binary
FROM curlimages/curl:latest AS downloader

ARG TARGETARCH=amd64

RUN set -e; \
    case "$TARGETARCH" in \
        amd64) ARCH="x86_64" ;; \
        arm64) ARCH="arm64" ;; \
        *) echo "Unsupported architecture: $TARGETARCH" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "https://github.com/chaindead/telegram-mcp/releases/latest/download/telegram-mcp_Linux_${ARCH}.tar.gz" \
        -o /tmp/telegram-mcp.tar.gz && \
    tar -xzf /tmp/telegram-mcp.tar.gz -C /tmp && \
    chmod +x /tmp/telegram-mcp

# Stage 2: runtime
FROM node:20-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends proxychains4 && \
    rm -rf /var/lib/apt/lists/*

RUN npm install -g supergateway

COPY --from=downloader /tmp/telegram-mcp /usr/local/bin/telegram-mcp

ENV HOME=/data
WORKDIR /data

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

VOLUME /data
EXPOSE 8080

ENTRYPOINT ["/entrypoint.sh"]
CMD ["serve"]
