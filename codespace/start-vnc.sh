#!/bin/bash

# Logging function with levels (INFO, ERROR)
log_message() {
    local LEVEL=$1
    local MESSAGE=$2
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$LEVEL] - $MESSAGE"
}

# Install required packages with error handling
install_package() {
    local PACKAGE=$1
    if ! dpkg -l | grep -q "^ii.*$PACKAGE"; then
        log_message "INFO" "$PACKAGE not found, installing..."
        sudo apt update && sudo apt install -y $PACKAGE || {
            log_message "ERROR" "Failed to install $PACKAGE"
            exit 1
        }
        log_message "INFO" "$PACKAGE installed successfully."
    else
        log_message "INFO" "$PACKAGE already installed."
    fi
}

# Install pip3 if not installed
install_pip3() {
    if ! command -v pip3 &> /dev/null; then
        log_message "INFO" "pip3 not found, installing..."
        sudo apt update && sudo apt install -y python3-pip || {
            log_message "ERROR" "Failed to install pip3"
            exit 1
        }
        log_message "INFO" "pip3 installed successfully."
    else
        log_message "INFO" "pip3 already installed."
    fi
}

# Install noVNC and websockify if not installed
install_novnc() {
    install_package "novnc"
    install_package "websockify"

    if ! python3 -c "import websockify" &> /dev/null; then
        log_message "INFO" "Python websockify module not found, installing..."
        sudo pip3 install websockify || {
            log_message "ERROR" "Failed to install Python websockify module"
            exit 1
        }
        log_message "INFO" "Python websockify module installed successfully."
    else
        log_message "INFO" "Python websockify module already installed."
    fi
}

# Stop VNC server and clean lock files
stop_vnc_server() {
    if pgrep Xvfb > /dev/null; then
        log_message "INFO" "Stopping running VNC server..."
        pkill Xvfb || log_message "ERROR" "Failed to stop VNC server."
        sleep 2
    fi

    # Clean lock and socket files
    for LOCK_FILE in /tmp/.X*-lock /tmp/.X11-unix/X*; do
        if [ -f "$LOCK_FILE" ]; then
            log_message "INFO" "Removing stale file: $LOCK_FILE"
            rm -f "$LOCK_FILE" || log_message "ERROR" "Could not remove $LOCK_FILE"
        fi
    done

    log_message "INFO" "VNC server stopped and cleaned up."
}

# Ensure proper permissions on X11 files
ensure_permissions() {
    if [ -d /tmp/.X11-unix ]; then
        if [ "$(stat -c '%U' /tmp/.X11-unix)" != "root" ]; then
            sudo chown root:root /tmp/.X11-unix || log_message "ERROR" "Failed to change ownership of /tmp/.X11-unix"
        fi
        sudo chmod 1777 /tmp/.X11-unix || log_message "ERROR" "Failed to set permissions on /tmp/.X11-unix"
    fi
}

# Setup noVNC utilities
setup_novnc() {
    WEBSOCKIFY_PATH=$(command -v websockify)
    if [ -z "$WEBSOCKIFY_PATH" ]; then
        log_message "ERROR" "websockify not found after installation. Exiting..."
        exit 1
    fi

    log_message "INFO" "Found websockify at $WEBSOCKIFY_PATH"
    sudo chmod +x "$WEBSOCKIFY_PATH" || log_message "ERROR" "Could not make websockify executable"
    sudo chown -R vscode:vscode "$(dirname "$WEBSOCKIFY_PATH")" || log_message "ERROR" "Could not set ownership on noVNC utilities"
}

# Start VNC server on a free display with retries
start_vnc_server() {
    DISPLAY_NUMBER=1
    MAX_RETRIES=5
    for (( i=0; i<MAX_RETRIES; i++ )); do
        while [ -f /tmp/.X${DISPLAY_NUMBER}-lock ]; do
            log_message "INFO" "Display :${DISPLAY_NUMBER} is in use. Trying next display..."
            ((DISPLAY_NUMBER++))
        done

        VNC_PORT=$((5900 + DISPLAY_NUMBER))
        log_message "INFO" "Starting VNC server on display :${DISPLAY_NUMBER} (port ${VNC_PORT})..."
        Xvfb :${DISPLAY_NUMBER} -screen 0 1280x800x24 &

        sleep 5  # Allow time for VNC server to start

        if pgrep Xvfb > /dev/null; then
            log_message "INFO" "VNC server started successfully on display :${DISPLAY_NUMBER} (port ${VNC_PORT})."
            return 0
        else
            log_message "ERROR" "VNC server failed to start. Retry $((i+1))/$MAX_RETRIES."
        fi
    done

    log_message "ERROR" "VNC server failed to start after $MAX_RETRIES attempts."
    exit 1
}

# Kill process running on a specified port
kill_process_on_port() {
    local PORT=$1
    if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null ; then
        log_message "INFO" "Port $PORT is in use, killing the process..."
        fuser -k $PORT/tcp || log_message "ERROR" "Failed to kill process on port $PORT"
    else
        log_message "INFO" "Port $PORT is free."
    fi
}

# Find an available port
find_free_port() {
    PORT=8080
    while lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null; do
        log_message "INFO" "Port $PORT is in use, trying next port..."
        ((PORT++))
    done
    log_message "INFO" "Found available port: $PORT"
    echo "$PORT"
}

# Check if VNC server is running on the correct port
check_vnc_port() {
    log_message "INFO" "Checking if VNC server is running on port $VNC_PORT..."
    if ! netstat -tuln | grep ":$VNC_PORT" > /dev/null; then
        log_message "ERROR" "VNC server is not running on port $VNC_PORT. Restarting..."
        start_vnc_server
    else
        log_message "INFO" "VNC server is listening on port $VNC_PORT."
    fi
}

# Main Script Execution

install_pip3
install_novnc
stop_vnc_server
ensure_permissions
setup_novnc

start_vnc_server
check_vnc_port

NOVNC_PORT=$(find_free_port)
log_message "INFO" "Starting noVNC server on port $NOVNC_PORT..."
$WEBSOCKIFY_PATH --web /opt/novnc/ $NOVNC_PORT localhost:$VNC_PORT &

log_message "INFO" "Waiting for noVNC to connect..."
sleep 10

if ! netstat -an | grep $VNC_PORT &> /dev/null; then
    log_message "ERROR" "noVNC could not connect to localhost:$VNC_PORT."
    exit 1
else
    log_message "INFO" "noVNC connected to VNC server on port $NOVNC_PORT."
fi
