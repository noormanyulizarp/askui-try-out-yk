#!/bin/bash

set -e

# Configuration
DEFAULT_DISPLAY=1
DEFAULT_NOVNC_PORT=8080
VNC_BASE_PORT=5900
XVFB_RESOLUTION="1280x800x24"
NOVNC_PATH="/opt/novnc/utils/novnc_proxy"

# Logging function
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Error handling function
handle_error() {
    log_message "Error: $1"
    exit 1
}

# Function to stop running VNC server
stop_vnc_server() {
    log_message "Stopping any running TightVNC server..."
    pkill Xvfb || log_message "No running Xvfb to stop."
    pkill Xtightvnc || log_message "No running TightVNC to stop."

    find /tmp -name '.X*-lock' -delete
    find /tmp/.X11-unix -name 'X*' -delete

    log_message "TightVNC server stopped and cleaned up."
}

# Ensure correct ownership and permissions on /tmp/.X11-unix
ensure_permissions() {
    if [ -d /tmp/.X11-unix ]; then
        sudo chown root:root /tmp/.X11-unix
        sudo chmod 1777 /tmp/.X11-unix
        log_message "Permissions for /tmp/.X11-unix verified."
    fi
}

# Function to find the next available display
find_available_display() {
    local display=$DEFAULT_DISPLAY
    while [ -f "/tmp/.X${display}-lock" ]; do
        ((display++))
    done
    echo $display
}

# Function to start the TightVNC server
start_vnc_server() {
    local display=$(find_available_display)
    local vnc_port=$((VNC_BASE_PORT + display))

    log_message "Starting Xvfb on display :${display}..."
    Xvfb :${display} -screen 0 $XVFB_RESOLUTION > /tmp/xvfb.log 2>&1 &

    sleep 5
    if ! pgrep Xvfb > /dev/null; then
        handle_error "Failed to start Xvfb on display :${display}."
    fi

    log_message "Starting TightVNC on display :${display} (port ${vnc_port})..."
    Xtightvnc :${display} -geometry $XVFB_RESOLUTION -depth 24 -rfbport ${vnc_port} -nopw > /tmp/tightvnc.log 2>&1 &

    sleep 5
    if pgrep Xtightvnc > /dev/null; then
        log_message "TightVNC server started on display :${display}."
    else
        handle_error "Failed to start TightVNC on display :${display}."
    fi
}

# Function to check and restart VNC if it crashes
check_and_restart_vnc() {
    log_message "Monitoring TightVNC server status..."
    if ! pgrep Xvfb > /dev/null || ! pgrep Xtightvnc > /dev/null; then
        log_message "TightVNC server is not running. Attempting to restart..."
        stop_vnc_server
        start_vnc_server
    else
        log_message "TightVNC server is running normally."
    fi
}

# Function to find a free port
find_free_port() {
    local port=$1
    while lsof -i :$port >/dev/null 2>&1; do
        ((port++))
    done
    echo $port
}

# Function to start noVNC
start_novnc() {
    local novnc_port=$(find_free_port $DEFAULT_NOVNC_PORT)
    log_message "Starting noVNC on port $novnc_port..."
    $NOVNC_PATH --vnc localhost:$((VNC_BASE_PORT + DEFAULT_DISPLAY)) --listen $novnc_port &

    sleep 5
    if pgrep -f novnc_proxy > /dev/null; then
        log_message "noVNC started and connected on port $novnc_port."
    else
        handle_error "Failed to start noVNC on port $novnc_port."
    fi
}

# Main script execution
main() {
    trap 'stop_vnc_server' EXIT

    stop_vnc_server
    ensure_permissions
    start_vnc_server
    start_novnc

    log_message "TightVNC and noVNC setup complete. Press Ctrl+C to exit."
    
    # Keep the script running and periodically check VNC status
    while true; do
        sleep 60
        check_and_restart_vnc
    done
}

main "$@"
