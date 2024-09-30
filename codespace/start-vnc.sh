#!/bin/bash

# Logging function
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Function to kill existing VNC server and remove lock files
restart_vnc_server() {
    if pgrep Xvfb > /dev/null; then
        log_message "VNC server already running, attempting to restart..."
        pkill Xvfb
        rm -f /tmp/.X1-lock
        log_message "VNC server restarted successfully."
    fi
}

# Ensure proper permissions on X11 files
ensure_permissions() {
    if [ -d /tmp/.X11-unix ]; then
        # Change ownership only if necessary
        if [ "$(stat -c '%U' /tmp/.X11-unix)" != "root" ]; then
            sudo chown root:root /tmp/.X11-unix || log_message "Error: Could not change ownership of /tmp/.X11-unix"
        fi
        # Set the correct permissions
        sudo chmod 1777 /tmp/.X11-unix || log_message "Error: Could not set permissions on /tmp/.X11-unix"
    fi
}

# Ensure noVNC utilities are correctly set up
setup_novnc() {
    # Ensure websockify is not a directory and is executable
    if [ -d /opt/novnc/utils/websockify/websockify ]; then
        log_message "Error: /opt/novnc/utils/websockify/websockify is a directory, not an executable."
        exit 1
    elif [ ! -x /opt/novnc/utils/websockify/websockify ]; then
        log_message "Making websockify executable..."
        sudo chmod +x /opt/novnc/utils/websockify/websockify || log_message "Error: Could not make websockify executable"
    fi
    sudo chown -R vscode:vscode /opt/novnc/utils || log_message "Error: Could not set ownership on /opt/novnc/utils"
}

# Function to check if VNC server is running
check_vnc_server() {
    if pgrep Xvfb > /dev/null; then
        log_message "VNC server is running."
        return 0
    else
        log_message "VNC server is not running."
        return 1
    fi
}

# Kill existing VNC server if running and remove lock files
restart_vnc_server

# Ensure proper permissions
ensure_permissions

# Ensure noVNC utilities are correctly set up
setup_novnc

# Start VNC server on display :1 with Xvfb
log_message "Starting VNC server..."
Xvfb :1 -screen 0 1280x800x24 &

# Wait for VNC server to start
sleep 5

# Start noVNC server
log_message "Starting noVNC server..."
/opt/novnc/utils/websockify/websockify --web /opt/novnc/ 8080 localhost:5901 &

# Check if VNC server is running
if ! check_vnc_server; then
    log_message "Error: VNC server failed to start."
    exit 1
fi

log_message "VNC server started successfully."