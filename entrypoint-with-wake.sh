#!/bin/bash
# Clawdbot entrypoint wrapper that triggers a heartbeat wake on startup
# Usage: Replace CMD in docker-compose with this script

set -e

GATEWAY_PORT="${GATEWAY_PORT:-18789}"
WAKE_DELAY="${WAKE_DELAY:-5}"
WAKE_TEXT="${WAKE_TEXT:-Gateway started, checking in.}"

echo "[entrypoint] Starting Clawdbot gateway..."

# Start the gateway in the background
node /app/dist/index.js gateway &
GATEWAY_PID=$!

# Signal handler for graceful shutdown
shutdown() {
    echo "[entrypoint] Received shutdown signal, forwarding to gateway (PID $GATEWAY_PID)..."
    
    # Send SIGTERM to gateway for graceful shutdown
    if kill -0 $GATEWAY_PID 2>/dev/null; then
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

# Wait on the gateway process (keeps container running)
# Using 'wait' allows trap handlers to run when signals arrive
wait $GATEWAY_PID
EXIT_CODE=$?

echo "[entrypoint] Gateway exited with code $EXIT_CODE"
exit $EXIT_CODE
