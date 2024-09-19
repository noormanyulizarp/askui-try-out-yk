#!/bin/bash

# Function to kill existing VNC server and remove lock files
restart_vnc_server() {
    if pgrep Xtightvnc > /dev/null; then
        echo "VNC server already running, attempting to restart..."
        vncserver -kill :1
        rm -f /tmp/.X1-lock
    fi
}

# Function to check if VNC server is running
check_vnc_server() {
    if pgrep Xtightvnc > /dev/null; then
        echo "VNC server is running."
        return 0
    else
        echo "VNC server is not running."
        return 1
    fi
}

# Kill existing VNC server if running
restart_vnc_server

# Start VNC server on display :1
vncserver :1 -geometry 1280x800 -depth 24 &

# Wait for a moment to allow VNC server to start
sleep 5

# Check if VNC server started successfully
if ! check_vnc_server; then
    echo "Error: VNC server failed to start."

    # Check if log directory exists and print log files if available
    if [ -d ~/.vnc ]; then
        echo "Checking VNC server log..."
        log_files=(~/.vnc/*.log)
        if [ -e "${log_files[0]}" ]; then
            cat "${log_files[@]}"
        else
            echo "No VNC log files found."
        fi
    else
        echo "VNC log directory does not exist."
    fi

    exit 1
fi

# Start noVNC
/usr/share/novnc/utils/launch.sh --vnc localhost:5901 --listen 6080 &

# Check if noVNC started successfully
if [ $? -ne 0 ]; then
    echo "Error: noVNC failed to start."
    exit 1
fi

echo "VNC server started on port 5901"
echo "noVNC started on port 6080"

# Ensure permissions are correct for log files
if [ -d ~/.vnc ]; then
    chmod +r ~/.vnc/*.log
fi

# Step-by-step troubleshooting
echo "If you encounter issues, try the following steps:"
echo "1. Check VNC server logs for additional errors: cat ~/.vnc/*.log"
echo "2. Restart the Codespaces container to apply changes."
echo "3. Ensure no other applications are using ports 5901 or 6080."
