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

# Function to stop VNC server and clean lock files
stop_vnc_server() {
    if pgrep Xvfb > /dev/null; then
        log_message "Stopping running VNC server..."
        pkill Xvfb || log_message "Error: Failed to stop VNC server."
        sleep 2  # Wait for processes to terminate
    fi
    
    # Remove lock files if exist
    if [ -f /tmp/.X1-lock ]; then
        log_message "Removing VNC server lock file..."
        rm -f /tmp/.X1-lock || log_message "Error: Could not remove /tmp/.X1-lock"
    fi

    if [ -f /tmp/.X11-unix/X1 ]; then
        log_message "Removing stale X1 socket file..."
        rm -f /tmp/.X11-unix/X1 || log_message "Error: Could not remove /tmp/.X11-unix/X1"
    fi

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

# Start the VNC server on a free display
start_vnc_server() {
    DISPLAY_NUMBER=1
    while [ -f /tmp/.X${DISPLAY_NUMBER}-lock ]; do
        log_message "Display :${DISPLAY_NUMBER} is in use. Trying next display..."
        ((DISPLAY_NUMBER++))
    done
    
    log_message "Starting VNC server on display :${DISPLAY_NUMBER}..."
    Xvfb :${DISPLAY_NUMBER} -screen 0 1280x800x24 &
    
    # Wait a few seconds for VNC server to initialize
    sleep 5
    
    if pgrep Xvfb > /dev/null; then
        log_message "VNC server started successfully on display :${DISPLAY_NUMBER}."
    else
        log_message "Error: VNC server failed to start."
        exit 1
    fi
}

# Check if a port is in use and kill the process using it
kill_process_on_port() {
    local PORT=$1
    if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null ; then
        log_message "Port $PORT is in use, killing the process..."
        fuser -k $PORT/tcp || {
            log_message "Error: Failed to kill process on port $PORT"
            exit 1
        }
        log_message "Process on port $PORT killed successfully."
    else
        log_message "Port $PORT is free."
    fi
}

# Function to check if VNC server is running on port 5901
check_vnc_port() {
    log_message "Checking if VNC server is running on port 5901..."
    if ! netstat -tuln | grep ":5901" > /dev/null; then
        log_message "Error: VNC server is not running on port 5901. Trying to start VNC server again."
        start_vnc_server
    else
        log_message "VNC server is listening on port 5901."
    fi
}

# Main Script Execution

# Install pip3 if not already installed
install_pip3

# Install noVNC, websockify, and Python websockify module if not already installed
install_novnc

# Stop any existing VNC server and clean lock files
stop_vnc_server

# Ensure proper permissions
ensure_permissions

# Ensure noVNC utilities are correctly set up
setup_novnc

# Start the VNC server
start_vnc_server

# Check if VNC is running on port 5901
check_vnc_port

# Kill any process using port 8080
kill_process_on_port 8080

# Start noVNC server
log_message "Starting noVNC server..."
$WEBSOCKIFY_PATH --web /opt/novnc/ 8080 localhost:5901 &

# Check if the noVNC server can connect to the VNC server
log_message "Waiting for noVNC to connect..."
sleep 5
if ! netstat -an | grep 5901 &> /dev/null; then
    log_message "Error: noVNC could not connect to localhost:5901. Check if the VNC server is running on port 5901."
    exit 1
else
    log_message "noVNC successfully connected to VNC server at localhost:5901."
fi
