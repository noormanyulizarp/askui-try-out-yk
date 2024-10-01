#!/bin/bash

# Logging function to prepend log messages with timestamps
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Function to check if pip3 is installed, and install it if not
install_pip3() {
    if ! command -v pip3 &> /dev/null; then
        log_message "pip3 not found, installing pip3..."
        # Update package lists and install pip3
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

# Function to install noVNC and websockify, which are required to run the VNC server via a web browser
install_novnc() {
    log_message "Installing noVNC and websockify..."
    sudo apt update
    sudo apt install -y novnc websockify || {
        log_message "Error: Failed to install noVNC and websockify"
        exit 1
    }
    log_message "noVNC and websockify installed successfully."
}

# Function to stop any running VNC server and clean up leftover lock files
stop_vnc_server() {
    # Check if Xvfb is running (VNC backend), and stop it if so
    if pgrep Xvfb > /dev/null; then
        log_message "Stopping running VNC server..."
        pkill Xvfb || log_message "Error: Failed to stop VNC server."
        sleep 2  # Wait for processes to completely terminate
    fi

    # Loop through any lingering lock files and remove them
    for LOCK_FILE in /tmp/.X*-lock; do
        if [ -f "$LOCK_FILE" ]; then
            log_message "Removing VNC server lock file: $LOCK_FILE..."
            rm -f "$LOCK_FILE" || log_message "Error: Could not remove $LOCK_FILE"
        fi
    done

    # Remove any stale X11 socket files if they exist
    for SOCKET_FILE in /tmp/.X11-unix/X*; do
        if [ -f "$SOCKET_FILE" ]; then
            log_message "Removing stale X socket file: $SOCKET_FILE..."
            rm -f "$SOCKET_FILE" || log_message "Error: Could not remove $SOCKET_FILE"
        fi
    done

    log_message "VNC server stopped and cleaned up."
}

# Ensure proper ownership and permissions on the /tmp/.X11-unix directory
ensure_permissions() {
    if [ -d /tmp/.X11-unix ]; then
        # Change ownership to root if not already root
        if [ "$(stat -c '%U' /tmp/.X11-unix)" != "root" ]; then
            sudo chown root:root /tmp/.X11-unix || log_message "Error: Could not change ownership of /tmp/.X11-unix"
        fi
        # Ensure the directory has the sticky bit and correct permissions
        sudo chmod 1777 /tmp/.X11-unix || log_message "Error: Could not set permissions on /tmp/.X11-unix"
    fi
}

# Function to start the VNC server on an available display number
start_vnc_server() {
    CUSTOM_DISPLAY_NUMBER=${1:-1}  # Use display 1 by default if no argument is given
    CUSTOM_VNC_PORT=$((5900 + CUSTOM_DISPLAY_NUMBER))  # Calculate the VNC port based on display number

    # Ensure the display number is not already in use by checking for a lock file
    while [ -f /tmp/.X${CUSTOM_DISPLAY_NUMBER}-lock ]; do
        log_message "Display :${CUSTOM_DISPLAY_NUMBER} is in use. Trying next display..."
        ((CUSTOM_DISPLAY_NUMBER++))
        CUSTOM_VNC_PORT=$((5900 + CUSTOM_DISPLAY_NUMBER))  # Recalculate the port
    done

    log_message "Starting VNC server on display :${CUSTOM_DISPLAY_NUMBER} (port ${CUSTOM_VNC_PORT})..."
    
    # Start the Xvfb server (virtual framebuffer) for the selected display
    Xvfb :${CUSTOM_DISPLAY_NUMBER} -screen 0 1280x800x24 > /tmp/xvfb.log 2>&1 &

    # Allow some time for Xvfb to start fully before continuing
    sleep 20  # Increase sleep duration to ensure stable startup

    log_message "VNC server started on display :${CUSTOM_DISPLAY_NUMBER}."
}

# Function to find an available port for noVNC
find_free_port() {
    PORT=8080  # Start searching from port 8080
    while lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null; do
        log_message "Port $PORT is in use, trying next port..."
        ((PORT++))  # Increment the port and check again
    done
    log_message "Found available port: $PORT"
    echo "$PORT"  # Output the free port
}

# Main Script Execution

# Install pip3 if not already installed
install_pip3

# Install noVNC and websockify if they are not already installed
install_novnc

# Stop any running VNC server and clean up leftover lock files
stop_vnc_server

# Ensure the X11 socket directory has correct permissions
ensure_permissions

# Start the VNC server on an available display number
start_vnc_server

# Find a free port for noVNC
NOVNC_PORT=$(find_free_port)

# Start the noVNC server, pointing it to the appropriate VNC port
log_message "Starting noVNC server on port $NOVNC_PORT..."
websockify --web /opt/novnc/ $NOVNC_PORT localhost:$((5900 + 1)) &

# Wait for the noVNC server to establish a connection
log_message "Waiting for noVNC to connect..."
sleep 10  # Allow time for connection to be established

# Check if noVNC successfully connected to the VNC server on port 5901
if ! netstat -an | grep "5901" &> /dev/null; then
    log_message "Error: noVNC could not connect to localhost:5901. Check if the VNC server is running on port 5901."
    exit 1
else
    log_message "noVNC successfully connected to VNC server at localhost:5901 on port $NOVNC_PORT."
fi
