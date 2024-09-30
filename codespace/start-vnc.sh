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
    
    VNC_PORT=$((5900 + DISPLAY_NUMBER))  # Dynamically assign port based on display number
    log_message "Starting VNC server on display :${DISPLAY_NUMBER} (port ${VNC_PORT})..."
    Xvfb :${DISPLAY_NUMBER} -screen 0 1280x800x24 &
    
    # Wait for a longer time for the VNC server to initialize
    sleep 15  # Increased sleep duration for better initialization
    
    # Check if the VNC server is listening on the correct port in a loop
    log_message "Verifying if VNC is listening on port $VNC_PORT..."
    for i in {1..5}; do  # Check for up to 5 times
        if netstat -tuln | grep ":$VNC_PORT" > /dev/null; then
            log_message "VNC is confirmed to be listening on $VNC_PORT."
            return  # Exit the function if it is listening
        else
            log_message "VNC is not yet listening on $VNC_PORT. Retrying..."
            sleep 3  # Wait before the next check
        fi
    done

    log_message "Error: VNC server failed to start properly on port $VNC_PORT."
    exit 1
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

# Function to check if VNC server is running on the correct port
check_vnc_port() {
    log_message "Checking if VNC server is running on port $VNC_PORT..."
    if ! netstat -tuln | grep ":$VNC_PORT" > /dev/null; then
        log_message "Error: VNC server is not running on port $VNC_PORT. Trying to start VNC server again."
        start_vnc_server
    else
        log_message "VNC server is listening on port $VNC_PORT."
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

# Check if VNC is running on the correct port
check_vnc_port

# Find a free port for noVNC dynamically
NOVNC_PORT=$(find_free_port)

# Start noVNC server on the dynamic VNC port
log_message "Starting noVNC server on port $NOVNC_PORT..."
$WEBSOCKIFY_PATH --web /opt/novnc/ $NOVNC_PORT localhost:$VNC_PORT &

# Check if the noVNC server can connect to the VNC server
log_message "Waiting for noVNC to connect..."
sleep 10  # Increased wait time for connection

if ! netstat -an | grep $VNC_PORT &> /dev/null; then
    log_message "Error: noVNC could not connect to localhost:$VNC_PORT. Check if the VNC server is running on port $VNC_PORT."
    exit 1
else
    log_message "noVNC successfully connected to VNC server at localhost:$VNC_PORT on port $NOVNC_PORT."
fi
