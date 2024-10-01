#!/bin/bash

# Logging function to prepend log messages with timestamps
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Function to stop running VNC server
stop_vnc_server() {
    log_message "Stopping any running VNC server..."
    pkill Xvfb || log_message "No running VNC server to stop."

    for LOCK_FILE in /tmp/.X*-lock; do
        rm -f "$LOCK_FILE" && log_message "Removed VNC lock file: $LOCK_FILE"
    done

    for SOCKET_FILE in /tmp/.X11-unix/X*; do
        rm -f "$SOCKET_FILE" && log_message "Removed stale X11 socket: $SOCKET_FILE"
    done

    log_message "VNC server stopped and cleaned up."
}

# Ensure correct ownership and permissions on /tmp/.X11-unix
ensure_permissions() {
    if [ -d /tmp/.X11-unix ]; then
        sudo chown root:root /tmp/.X11-unix
        sudo chmod 1777 /tmp/.X11-unix
        log_message "Permissions for /tmp/.X11-unix verified."
    fi
}

# Function to start the VNC server on the next available display
start_vnc_server() {
    DISPLAY_NUMBER=${1:-1}  # Default to display 1
    while [ -f /tmp/.X${DISPLAY_NUMBER}-lock ]; do
        ((DISPLAY_NUMBER++))
    done
    VNC_PORT=$((5900 + DISPLAY_NUMBER))

    log_message "Starting VNC server on display :${DISPLAY_NUMBER} (port ${VNC_PORT})..."
    Xvfb :${DISPLAY_NUMBER} -screen 0 1280x800x24 > /tmp/xvfb.log 2>&1 &

    sleep 20  # Ensure Xvfb has time to start
    log_message "VNC server started on display :${DISPLAY_NUMBER}."
}

# Function to check and restart VNC if it crashes
check_and_restart_vnc() {
    log_message "Monitoring VNC server status..."
    if ! pgrep Xvfb > /dev/null; then
        log_message "VNC server is not running. Attempting to restart..."
        stop_vnc_server
        start_vnc_server
    else
        log_message "VNC server is running normally."
    fi
}

# Function to start noVNC
start_novnc() {
    NOVNC_PORT=$(find_free_port)
    log_message "Starting noVNC on port $NOVNC_PORT..."
    /opt/novnc/utils/novnc_proxy --vnc localhost:$((5900 + 1)) --listen $NOVNC_PORT &

    sleep 10
    log_message "noVNC started and connected on port $NOVNC_PORT."
}

# Function to find a free port for noVNC
find_free_port() {
    PORT=8080
    while lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null; do
        ((PORT++))
    done
    echo "$PORT"
}

# Main script execution
stop_vnc_server
ensure_permissions
start_vnc_server
check_and_restart_vnc
start_novnc

# Keep the script running
tail -f /dev/null