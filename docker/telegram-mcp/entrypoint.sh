#!/bin/sh
set -e

require_var() {
    eval "val=\$$1"
    if [ -z "$val" ]; then
        echo "Error: $1 is required but not set" >&2
        exit 1
    fi
}

setup_proxy() {
    require_var PROXY_HOST

    PROXY_PORT="${PROXY_PORT:-1080}"

    if [ -n "$PROXY_USER" ] && [ -n "$PROXY_PASS" ]; then
        PROXY_LINE="socks5 $PROXY_HOST $PROXY_PORT $PROXY_USER $PROXY_PASS"
        echo "Proxy configured: $PROXY_HOST:$PROXY_PORT (with authentication)" >&2
    else
        PROXY_LINE="socks5 $PROXY_HOST $PROXY_PORT"
        echo "Proxy configured: $PROXY_HOST:$PROXY_PORT (no authentication)" >&2
    fi

    cat > /etc/proxychains4.conf <<EOF
strict_chain
proxy_dns
quiet_mode

[ProxyList]
$PROXY_LINE
EOF
}

cmd_init() {
    require_var TG_APP_ID
    require_var TG_API_HASH
    require_var TG_PHONE

    setup_proxy

    PASSWORD_FLAG=""
    if [ -n "$TG_2FA_PASSWORD" ]; then
        PASSWORD_FLAG="--password $TG_2FA_PASSWORD"
    fi

    proxychains4 telegram-mcp auth \
        --app-id   "$TG_APP_ID" \
        --api-hash "$TG_API_HASH" \
        --phone    "$TG_PHONE" \
        $PASSWORD_FLAG
}

cmd_serve() {
    require_var TG_APP_ID
    require_var TG_API_HASH

    # Check that session files exist
    if [ -z "$(ls -A "$HOME" 2>/dev/null)" ]; then
        echo "Error: no session files found in $HOME" >&2
        echo "Run 'docker compose --profile init run --rm session-init' first to authenticate" >&2
        exit 1
    fi

    setup_proxy

    MCP_PORT="${MCP_PORT:-8080}"

    exec supergateway \
        --port "$MCP_PORT" \
        --stdio "proxychains4 -q telegram-mcp"
}

case "${1:-serve}" in
    init)  cmd_init ;;
    serve) cmd_serve ;;
    *)
        echo "Usage: $0 {init|serve}" >&2
        exit 1
        ;;
esac
