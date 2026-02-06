#!/bin/bash
# Clawdbot + code-server entrypoint
# Starts code-server (optional) and Clawdbot gateway

set -e

# Configuration
GATEWAY_PORT="${GATEWAY_PORT:-18789}"
WAKE_DELAY="${WAKE_DELAY:-5}"
WAKE_TEXT="${WAKE_TEXT:-Gateway started, checking in.}"
CODE_SERVER_ENABLED="${CODE_SERVER_ENABLED:-true}"
CODE_SERVER_PORT="${CODE_SERVER_PORT:-8443}"
CLAWDBOT_WORKSPACE="${CLAWDBOT_WORKSPACE:-/home/coder/clawd}"

# Clean up stale lock files
echo "[entrypoint] Cleaning up stale lock files..."
find /home/coder/.clawdbot -name "*.lock" -type f -delete 2>/dev/null || true

# Start Chrome in headless mode for browser automation
echo "[entrypoint] Starting Chrome..."
google-chrome-stable --headless=new --no-sandbox --disable-gpu \
  --remote-debugging-port=18800 \
  --user-data-dir=/home/coder/.clawdbot/browser/clawd/user-data \
  about:blank 2>&1 | sed 's/^/[chrome] /' &
CHROME_PID=$!
echo "[entrypoint] Chrome started (PID $CHROME_PID)"

# Start code-server if enabled
CODE_SERVER_PID=""
if [ "$CODE_SERVER_ENABLED" = "true" ]; then
    echo "[entrypoint] Starting code-server on port $CODE_SERVER_PORT..."
    
    # code-server will use its own config or env vars
    # PASSWORD env var is picked up automatically by code-server
    code-server --bind-addr "0.0.0.0:$CODE_SERVER_PORT" "$CLAWDBOT_WORKSPACE" 2>&1 | sed 's/^/[code-server] /' &
    CODE_SERVER_PID=$!
    echo "[entrypoint] code-server started (PID $CODE_SERVER_PID)"
fi

# Start Clawdbot gateway
echo "[entrypoint] Starting Clawdbot gateway..."
clawdbot gateway 2>&1 | sed 's/^/[gateway] /' &
GATEWAY_PID=$!

# Signal handler
shutdown() {
    echo "[entrypoint] Shutting down..."
    
    [ -n "$GATEWAY_PID" ] && kill -TERM $GATEWAY_PID 2>/dev/null || true
    [ -n "$CODE_SERVER_PID" ] && kill -TERM $CODE_SERVER_PID 2>/dev/null || true
    [ -n "$CHROME_PID" ] && kill -TERM $CHROME_PID 2>/dev/null || true
    
    sleep 2
    
    [ -n "$GATEWAY_PID" ] && kill -KILL $GATEWAY_PID 2>/dev/null || true
    [ -n "$CODE_SERVER_PID" ] && kill -KILL $CODE_SERVER_PID 2>/dev/null || true
    [ -n "$CHROME_PID" ] && kill -KILL $CHROME_PID 2>/dev/null || true
    
    exit 0
}
trap shutdown SIGTERM SIGINT SIGQUIT

# Wait for gateway to be ready
wait_for_gateway() {
    local max_attempts=60
    local attempt=0
    
    echo "[entrypoint] Waiting for gateway..."
    while [ $attempt -lt $max_attempts ]; do
        if curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:$GATEWAY_PORT/health" 2>/dev/null | grep -q "200"; then
            echo "[entrypoint] Gateway ready!"
            return 0
        fi
        if ! kill -0 $GATEWAY_PID 2>/dev/null; then
            echo "[entrypoint] Gateway process died"
            return 1
        fi
        attempt=$((attempt + 1))
        sleep 1
    done
    echo "[entrypoint] Gateway timeout, continuing..."
    return 0
}

# Trigger wake after gateway is ready
trigger_wake() {
    sleep "$WAKE_DELAY"
    echo "[entrypoint] Triggering wake..."
    clawdbot wake --text "$WAKE_TEXT" --mode now --timeout 30000 || echo "[entrypoint] Wake failed (non-fatal)"
}

# Background: wait for gateway then wake
{ wait_for_gateway && trigger_wake; } &

# Startup info
echo ""
echo "=========================================="
echo "  Clawdbot + code-server"
echo "=========================================="
echo "  Dashboard:    http://localhost:$GATEWAY_PORT"
echo "  WebChat:      http://localhost:18790"
[ "$CODE_SERVER_ENABLED" = "true" ] && echo "  code-server:  http://localhost:$CODE_SERVER_PORT"
echo "=========================================="
echo ""

# Wait on gateway
wait $GATEWAY_PID
EXIT_CODE=$?

echo "[entrypoint] Gateway exited with code $EXIT_CODE"
exit $EXIT_CODE
