#!/bin/bash

# Logging function
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Function to install pip3 if not installed
install_pip3() {
    if ! command -v pip3 &> /dev/null; then
        log_message "pip3 not found, installing pip3..."
        sudo apt update
        sudo apt install -y python3-pip || {
            log_message "Error: Failed to install pip3"
            exit 1
        }
        log_message "pip3 installed successfully."
    else
        log_message "pip3 already installed."
    fi
}

# Function to install noVNC, websockify, and Python websockify if missing
install_novnc() {
    if ! command -v websockify &> /dev/null; then
        log_message "websockify not found, installing noVNC and websockify..."
        sudo apt update
        sudo apt install -y novnc websockify || {
            log_message "Error: Failed to install noVNC and websockify"
            exit 1
        }
        log_message "noVNC and websockify installed successfully."
    else
        log_message "websockify already installed."
    fi

    # Ensure the Python websockify module is installed
    if ! python3 -c "import websockify" &> /dev/null; then
        log_message "Python websockify module not found, installing..."
        sudo pip3 install websockify || {
            log_message "Error: Failed to install Python websockify module"
            exit 1
        }
        log_message "Python websockify module installed successfully."
    else
        log_message "Python websockify module already installed."
    fi
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
    # Find the correct path to websockify
    WEBSOCKIFY_PATH=$(command -v websockify)
    
    if [ -z "$WEBSOCKIFY_PATH" ]; then
        log_message "Error: websockify not found after installation. Exiting..."
        exit 1
    fi

    log_message "Found websockify at $WEBSOCKIFY_PATH"

    # Ensure websockify is executable
    if [ ! -x "$WEBSOCKIFY_PATH" ]; then
        log_message "Making websockify executable..."
        sudo chmod +x "$WEBSOCKIFY_PATH" || log_message "Error: Could not make websockify executable"
    fi

    sudo chown -R vscode:vscode "$(dirname "$WEBSOCKIFY_PATH")" || log_message "Error: Could not set ownership on noVNC utils"
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

# Install pip3 if not already installed
install_pip3

# Install noVNC, websockify, and Python websockify module if not already installed
install_novnc

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
$WEBSOCKIFY_PATH --web /opt/novnc/ 8080 localhost:5901 &

# Check if VNC server is running
if ! check_vnc_server; then
    log_message "Error: VNC server failed to start."
    exit 1
fi

log_message "VNC server started successfully."
