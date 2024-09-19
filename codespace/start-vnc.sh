#!/bin/bash

# Function to kill existing VNC server and remove lock files
restart_vnc_server() {
    if pgrep Xvfb > /dev/null; then
        echo "VNC server already running, attempting to restart..."
        pkill Xvfb
        rm -f /tmp/.X1-lock
    fi
}

# Function to check if VNC server is running
check_vnc_server() {
    if pgrep Xvfb > /dev/null; then
        echo "VNC server is running."
        return 0
    else
        echo "VNC server is not running."
        return 1
    fi
}

# Kill existing VNC server if running and remove lock files
restart_vnc_server

# Start VNC server on display :1 with Xvfb
Xvfb :1 -screen 0 1280x800x24 &

# Wait for VNC server to start
sleep 5

# Start noVNC server
/opt/novnc/utils/novnc_proxy --vnc localhost:5901 --listen 8080 &

# Check if VNC server is running
if ! check_vnc_server; then
    echo "Error: VNC server failed to start."
    exit 1
fi

echo "VNC server started successfully."
