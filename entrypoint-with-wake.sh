#!/bin/bash
# Clawdbot entrypoint wrapper that triggers a heartbeat wake on startup
# and optionally starts code-server for VS Code in browser
# Usage: Replace CMD in docker-compose with this script

set -e

GATEWAY_PORT="${GATEWAY_PORT:-18789}"
WAKE_DELAY="${WAKE_DELAY:-5}"
WAKE_TEXT="${WAKE_TEXT:-Gateway started, checking in.}"

# code-server settings
CODE_SERVER_ENABLED="${CODE_SERVER_ENABLED:-true}"
CODE_SERVER_PORT="${CODE_SERVER_PORT:-8443}"
CODE_SERVER_PASSWORD="${CODE_SERVER_PASSWORD:-}"
CODE_SERVER_AUTH="${CODE_SERVER_AUTH:-password}"
CODE_SERVER_BIND_ADDR="${CODE_SERVER_BIND_ADDR:-0.0.0.0:$CODE_SERVER_PORT}"
CODE_SERVER_WORKSPACE="${CODE_SERVER_WORKSPACE:-/root/clawd}"

# Clean up stale lock files from previous runs
echo "[entrypoint] Cleaning up stale lock files..."
find /root/.clawdbot -name "*.lock" -type f -delete 2>/dev/null || true
echo "[entrypoint] Lock cleanup complete"

echo "[entrypoint] Starting Chrome browser..."

# Start Chrome in headless mode for browser automation
# The gateway's browser control will attach to this instance
google-chrome-stable --headless=new --no-sandbox --disable-gpu \
  --remote-debugging-port=18800 \
  --user-data-dir=/root/.clawdbot/browser/clawd/user-data \
  about:blank > /tmp/chrome.log 2>&1 &
CHROME_PID=$!

echo "[entrypoint] Chrome started (PID $CHROME_PID)"

# Start code-server if enabled
CODE_SERVER_PID=""
if [ "$CODE_SERVER_ENABLED" = "true" ]; then
    echo "[entrypoint] Starting code-server on port $CODE_SERVER_PORT..."
    
    # Create code-server config
    mkdir -p /root/.config/code-server
    cat > /root/.config/code-server/config.yaml << EOF
bind-addr: $CODE_SERVER_BIND_ADDR
auth: $CODE_SERVER_AUTH
password: ${CODE_SERVER_PASSWORD:-$(openssl rand -base64 24)}
cert: false
EOF
    
    # If no password was set, show the generated one
    if [ -z "$CODE_SERVER_PASSWORD" ]; then
        echo "[entrypoint] code-server password: $(grep password /root/.config/code-server/config.yaml | cut -d' ' -f2)"
    fi
    
    # Start code-server
    code-server "$CODE_SERVER_WORKSPACE" > /tmp/code-server.log 2>&1 &
    CODE_SERVER_PID=$!
    echo "[entrypoint] code-server started (PID $CODE_SERVER_PID)"
fi

echo "[entrypoint] Starting Clawdbot gateway..."

# Start the gateway in the background
node /app/dist/index.js gateway &
GATEWAY_PID=$!

# Signal handler for graceful shutdown
shutdown() {
    echo "[entrypoint] Received shutdown signal..."
    
    # Send SIGTERM to gateway for graceful shutdown
    if kill -0 $GATEWAY_PID 2>/dev/null; then
        echo "[entrypoint] Stopping gateway (PID $GATEWAY_PID)..."
        kill -TERM $GATEWAY_PID 2>/dev/null || true
        
        # Wait up to 30s for graceful shutdown
        local timeout=30
        while [ $timeout -gt 0 ] && kill -0 $GATEWAY_PID 2>/dev/null; do
            sleep 1
            timeout=$((timeout - 1))
        done
        
        # Force kill if still alive
        if kill -0 $GATEWAY_PID 2>/dev/null; then
            echo "[entrypoint] Gateway didn't stop gracefully, sending SIGKILL..."
            kill -KILL $GATEWAY_PID 2>/dev/null || true
        else
            echo "[entrypoint] Gateway stopped gracefully"
        fi
    fi
    
    # Stop code-server
    if [ -n "$CODE_SERVER_PID" ] && kill -0 $CODE_SERVER_PID 2>/dev/null; then
        echo "[entrypoint] Stopping code-server (PID $CODE_SERVER_PID)..."
        kill -TERM $CODE_SERVER_PID 2>/dev/null || true
        sleep 2
        kill -KILL $CODE_SERVER_PID 2>/dev/null || true
    fi
    
    # Stop Chrome
    if kill -0 $CHROME_PID 2>/dev/null; then
        echo "[entrypoint] Stopping Chrome (PID $CHROME_PID)..."
        kill -TERM $CHROME_PID 2>/dev/null || true
        sleep 2
        kill -KILL $CHROME_PID 2>/dev/null || true
    fi
    
    exit 0
}

# Trap signals and forward to gateway
trap shutdown SIGTERM SIGINT SIGQUIT

# Function to check if gateway is ready
wait_for_gateway() {
    local max_attempts=30
    local attempt=0
    
    echo "[entrypoint] Waiting for gateway to be ready on port $GATEWAY_PORT..."
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:$GATEWAY_PORT/health" 2>/dev/null | grep -q "200"; then
            echo "[entrypoint] Gateway is ready!"
            return 0
        fi
        
        # Also check if gateway process is still alive
        if ! kill -0 $GATEWAY_PID 2>/dev/null; then
            echo "[entrypoint] Gateway process died unexpectedly"
            return 1
        fi
        
        attempt=$((attempt + 1))
        sleep 1
    done
    
    echo "[entrypoint] Gateway didn't become ready in time, continuing anyway..."
    return 0
}

# Function to trigger wake
trigger_wake() {
    echo "[entrypoint] Waiting ${WAKE_DELAY}s before triggering wake..."
    sleep "$WAKE_DELAY"
    
    echo "[entrypoint] Triggering startup wake..."
    node /app/dist/index.js wake --text "$WAKE_TEXT" --mode now --timeout 30000 || {
        echo "[entrypoint] Wake command failed (non-fatal)"
    }
    echo "[entrypoint] Startup wake complete!"
}

# Wait for gateway, then trigger wake in background
{
    wait_for_gateway && trigger_wake
} &

# Print startup summary
echo ""
echo "=========================================="
echo "  Clawdbot Gateway Started"
echo "=========================================="
echo "  Gateway UI:     http://localhost:$GATEWAY_PORT"
echo "  WebChat:        http://localhost:18790"
if [ "$CODE_SERVER_ENABLED" = "true" ]; then
echo "  code-server:    http://localhost:$CODE_SERVER_PORT"
fi
echo "=========================================="
echo ""

# Wait on the gateway process (keeps container running)
# Using 'wait' allows trap handlers to run when signals arrive
wait $GATEWAY_PID
EXIT_CODE=$?

echo "[entrypoint] Gateway exited with code $EXIT_CODE"
exit $EXIT_CODE
