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
    log_message "Stopping any running VNC server..."
    pkill Xvfb || true
    pkill x11vnc || true
    pkill -f novnc_proxy || true

    # Only attempt to delete files if the directories exist
    if [ -d /tmp ]; then
        find /tmp -name '.X*-lock' -delete 2>/dev/null || true
    fi
    if [ -d /tmp/.X11-unix ]; then
        find /tmp/.X11-unix -name 'X*' -delete 2>/dev/null || true
    fi

    log_message "VNC server stopped and cleaned up."
}

# Ensure correct ownership and permissions on /tmp/.X11-unix
ensure_permissions() {
    if [ ! -d /tmp/.X11-unix ]; then
        log_message "Creating /tmp/.X11-unix directory..."
        mkdir -p /tmp/.X11-unix
    fi
    
    log_message "Setting permissions for /tmp/.X11-unix..."
    sudo chown root:root /tmp/.X11-unix
    sudo chmod 1777 /tmp/.X11-unix
    log_message "Permissions for /tmp/.X11-unix verified."
}

# Function to find the next available display
find_available_display() {
    local display=$DEFAULT_DISPLAY
    while [ -f "/tmp/.X${display}-lock" ]; do
        ((display++))
    done
    echo $display
}

# Function to start the VNC server
start_vnc_server() {
    local display=$(find_available_display)
    local vnc_port=$((VNC_BASE_PORT + display))

    log_message "Starting Xvfb on display :${display}..."
    Xvfb :${display} -screen 0 $XVFB_RESOLUTION > /dev/null 2>&1 &

    sleep 2
    if ! pgrep Xvfb > /dev/null; then
        handle_error "Failed to start Xvfb on display :${display}."
    fi

    log_message "Starting x11vnc on display :${display} (port ${vnc_port})..."
    x11vnc -display :${display} -forever -shared -rfbport ${vnc_port} -passwd $VNC_PASSWORD > /dev/null 2>&1 &

    sleep 2
    if pgrep x11vnc > /dev/null; then
        log_message "VNC server (x11vnc) started on display :${display}."
    else
        handle_error "Failed to start x11vnc on display :${display}."
    fi

    export DISPLAY=:${display}
}

# Function to start noVNC
start_novnc() {
    local novnc_port=$DEFAULT_NOVNC_PORT
    log_message "Starting noVNC on port $novnc_port..."
    $NOVNC_PATH --vnc localhost:$((VNC_BASE_PORT + DEFAULT_DISPLAY)) --listen $novnc_port > /dev/null 2>&1 &

    sleep 2
    if pgrep -f novnc_proxy > /dev/null; then
        log_message "noVNC started and connected on port $novnc_port."
    else
        handle_error "Failed to start noVNC on port $novnc_port."
    fi
}

# Function to start Xfce session
start_xfce() {
    log_message "Starting Xfce session..."
    startxfce4 &
}

# Main script execution
main() {
    trap 'stop_vnc_server' EXIT

    if [ -z "$VNC_PASSWORD" ]; then
        handle_error "VNC_PASSWORD environment variable is not set."
    fi

    stop_vnc_server
    ensure_permissions
    start_vnc_server
    start_novnc
    start_xfce

    log_message "VNC and noVNC setup complete. noVNC should be accessible on port $DEFAULT_NOVNC_PORT."
    log_message "Press Ctrl+C to exit."
    
    # Keep the script running
    tail -f /dev/null
}

main "$@"