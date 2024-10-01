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

# Function to install noVNC and websockify if missing
install_novnc() {
    log_message "Installing noVNC and websockify..."
    sudo apt update
    sudo apt install -y novnc websockify || {
        log_message "Error: Failed to install noVNC and websockify"
        exit 1
    }
    log_message "noVNC and websockify installed successfully."
}

# Function to stop VNC server and clean lock files
stop_vnc_server() {
    if pgrep Xvfb > /dev/null; then
        log_message "Stopping running VNC server..."
        pkill Xvfb || log_message "Error: Failed to stop VNC server."
        sleep 2  # Wait for processes to terminate
    fi

    # Remove lock files if they exist
    for LOCK_FILE in /tmp/.X*-lock; do
        if [ -f "$LOCK_FILE" ]; then
            log_message "Removing VNC server lock file: $LOCK_FILE..."
            rm -f "$LOCK_FILE" || log_message "Error: Could not remove $LOCK_FILE"
        fi
    done

    for SOCKET_FILE in /tmp/.X11-unix/X*; do
        if [ -f "$SOCKET_FILE" ]; then
            log_message "Removing stale X socket file: $SOCKET_FILE..."
            rm -f "$SOCKET_FILE" || log_message "Error: Could not remove $SOCKET_FILE"
        fi
    done

    log_message "VNC server stopped and cleaned up."
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

# Start the VNC server on a free display
start_vnc_server() {
    CUSTOM_DISPLAY_NUMBER=${1:-1}  # Default to 1 if not provided
    CUSTOM_VNC_PORT=$((5900 + CUSTOM_DISPLAY_NUMBER))  # Calculate port based on display number

    # Check if the specified display number is in use
    while [ -f /tmp/.X${CUSTOM_DISPLAY_NUMBER}-lock ]; do
        log_message "Display :${CUSTOM_DISPLAY_NUMBER} is in use. Trying next display..."
        ((CUSTOM_DISPLAY_NUMBER++))
        CUSTOM_VNC_PORT=$((5900 + CUSTOM_DISPLAY_NUMBER))  # Update the port
    done

    log_message "Starting VNC server on display :${CUSTOM_DISPLAY_NUMBER} (port ${CUSTOM_VNC_PORT})..."
    
    # Start the Xvfb server
    Xvfb :${CUSTOM_DISPLAY_NUMBER} -screen 0 1280x800x24 > /tmp/xvfb.log 2>&1 &

    # Wait for a longer time for the VNC server to initialize
    sleep 20  # Increased sleep duration for better initialization

    log_message "VNC server started on display :${CUSTOM_DISPLAY_NUMBER}."
}

# Find a free port dynamically
find_free_port() {
    PORT=8080  # Start checking from this port
    while lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null; do
        log_message "Port $PORT is in use, trying next port..."
        ((PORT++))
    done
    log_message "Found available port: $PORT"
    echo "$PORT"
}

# Main Script Execution

# Install pip3 if not already installed
install_pip3

# Install noVNC and websockify if not already installed
install_novnc

# Stop any existing VNC server and clean lock files
stop_vnc_server

# Ensure proper permissions
ensure_permissions

# Start the VNC server
start_vnc_server

# Find a free port for noVNC dynamically
NOVNC_PORT=$(find_free_port)

# Start noVNC server on the dynamic VNC port
log_message "Starting noVNC server on port $NOVNC_PORT..."
websockify --web /opt/novnc/ $NOVNC_PORT localhost:$((5900 + 1)) &

# Check if the noVNC server can connect to the VNC server
log_message "Waiting for noVNC to connect..."
sleep 10  # Increased wait time for connection

if ! netstat -an | grep "5901" &> /dev/null; then
    log_message "Error: noVNC could not connect to localhost:5901. Check if the VNC server is running on port 5901."
    exit 1
else
    log_message "noVNC successfully connected to VNC server at localhost:5901 on port $NOVNC_PORT."
fi
