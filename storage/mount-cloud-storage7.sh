#!/bin/bash

VERSION="1.4.1"
set -e
trap cleanup EXIT

# Logging setup
LOG_FILE="/tmp/pcloud_setup.log"

BUILD_DIR="/tmp/pcloud-build"
BUILD_FROM_SOURCE=${BUILD_FROM_SOURCE:-true}
MOUNT_POINT="/workspace/pcloud"
SYNCRO_FOLDER="SYNCRO"
LOCAL_SYNC_DIR="/workspace/local_${SYNCRO_FOLDER}"
PCLOUD_REPO="https://github.com/pcloudcom/console-client.git"
PCLOUD_DIR="$HOME/console-client"

cleanup() {
    [ -d "$BUILD_DIR" ] && rm -rf "$BUILD_DIR"
}

log_message() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1" | tee -a "$LOG_FILE"
}

check_sync_status() {
    local status_output
    status_output=$(pcloudcc status 2>&1)
    echo "$status_output" | tee -a "$LOG_FILE"
    if echo "$status_output" | grep -q "Everything Downloaded.*Everything Uploaded"; then
        return 0
    else
        return 1
    fi
}

install_dependencies() {
    log_message "Installing required dependencies..."
    {
        sudo apt-get update
        sudo apt-get install -y cmake libfuse-dev libcurl4-openssl-dev libsqlite3-dev \
                               build-essential git zlib1g-dev libboost-system-dev \
                               libboost-program-options-dev libpthread-stubs0-dev libudev-dev fuse
        log_message "Dependencies installed successfully"
    } 2>&1 | tee -a "$LOG_FILE"
}

check_and_clone_pcloudcc_repo() {
    log_message "Checking pCloud console client repository..."
    if [ ! -d "$PCLOUD_DIR" ]; then
        log_message "Cloning pCloud console client repository..."
        git clone "$PCLOUD_REPO" "$PCLOUD_DIR" 2>&1 | tee -a "$LOG_FILE"
    else
        log_message "Repository exists. Pulling latest changes..."
        (cd "$PCLOUD_DIR" && git pull) 2>&1 | tee -a "$LOG_FILE"
    fi
    cd "$PCLOUD_DIR/pCloudCC/"
}

build_pcloudcc() {
    log_message "Building pCloud console client..."
    {
        cd lib/pclsync/
        make clean && make fs
        
        cd ../mbedtls/
        cmake . && make clean && make
        
        cd ../..
        cmake .
        make -j$(nproc)
        sudo make install
        sudo ldconfig

        log_message "pCloud built and installed successfully"
    } 2>&1 | tee -a "$LOG_FILE"
}

verify_pcloud_binaries() {
    if command -v pcloudcc >/dev/null; then
        log_message "pcloudcc installed successfully"
        pcloudcc -h 2>&1 | head -n 1 | tee -a "$LOG_FILE"
    else
        log_message "Error: pcloudcc not found! Build may have failed"
        exit 1
    fi
}

configure_pcloud() {
    if [ -z "$PCLOUD_EMAIL" ] || [ -z "$PCLOUD_PASSWORD" ]; then
        log_message "Error: Please set PCLOUD_EMAIL and PCLOUD_PASSWORD"
        exit 1
    fi

    log_message "Configuring pCloud..."
    {
        echo "$PCLOUD_PASSWORD" | pcloudcc -u "$PCLOUD_EMAIL" -p -s
        log_message "pCloud configured successfully"
    } 2>&1 | tee -a "$LOG_FILE"
}

wait_for_sync_ready() {
    log_message "Waiting for sync to be ready..."
    local timeout=60 elapsed=0
    while ! check_sync_status; do
        log_message "Still waiting for sync... (${elapsed}s/${timeout}s)"
        sleep 5
        elapsed=$((elapsed+5))
        if [ "$elapsed" -ge "$timeout" ]; then
            log_message "Error: Timeout waiting for sync readiness"
            exit 1
        fi
    done
    log_message "Sync system is ready"
}

sync_syncro_folder() {
    log_message "Creating local SYNCRO directory: $LOCAL_SYNC_DIR"
    mkdir -p "$LOCAL_SYNC_DIR"

    log_message "Starting SYNCRO folder sync..."
    {
        pcloudcc -u "$PCLOUD_EMAIL" -p "$PCLOUD_PASSWORD" -c sync -s "/$SYNCRO_FOLDER" -d "$LOCAL_SYNC_DIR"
        if [ $? -eq 0 ] && [ -d "$LOCAL_SYNC_DIR" ]; then
            if [ -n "$(ls -A "$LOCAL_SYNC_DIR" 2>/dev/null)" ]; then
                log_message "SYNCRO folder sync completed successfully - files present"
            else
                log_message "SYNCRO folder sync completed but directory is empty - this might be normal if the remote folder is empty"
            fi
            return 0
        else
            log_message "Error: SYNCRO folder sync failed"
            return 1
        fi
    } 2>&1 | tee -a "$LOG_FILE"
}

try_mount_pcloud() {
    log_message "Attempting optional FUSE mount..."
    if ! command -v pcloudfs >/dev/null; then
        log_message "Note: pcloudfs not found - skipping FUSE mount"
        return 1
    fi

    mkdir -p "$MOUNT_POINT"
    if mountpoint -q "$MOUNT_POINT"; then
        log_message "Note: pCloud already mounted at $MOUNT_POINT"
        return 0
    fi

    {
        pcloudfs "$MOUNT_POINT" &
        local pid=$!
        sleep 5
        if kill -0 $pid 2>/dev/null; then
            log_message "FUSE mount process started successfully"
            return 0
        else
            log_message "Note: FUSE mount process failed to start - this won't affect sync functionality"
            return 1
        fi
    } 2>&1 | tee -a "$LOG_FILE"
}

create_desktop_shortcut() {
    log_message "Creating desktop shortcut for local SYNCRO folder..."
    mkdir -p /home/gitpod/Desktop
    cat <<EOF > /home/gitpod/Desktop/pCloud_SYNCRO.desktop
[Desktop Entry]
Name=pCloud SYNCRO
Comment=Access your local SYNCRO folder
Exec=nautilus $LOCAL_SYNC_DIR
Icon=folder
Terminal=false
Type=Application
Categories=Utility;
EOF
    chmod +x /home/gitpod/Desktop/pCloud_SYNCRO.desktop
    log_message "Desktop shortcut created successfully"
}

# Main execution
log_message "Starting pCloud setup v$VERSION (Sync-focused)..."
log_message "Full logs will be available at: $LOG_FILE"

# Ensure log file exists and is empty
> "$LOG_FILE"

# Phase 1: Installation and basic setup
install_dependencies

if [ "$BUILD_FROM_SOURCE" = true ]; then
    check_and_clone_pcloudcc_repo
    build_pcloudcc
    verify_pcloud_binaries
fi

# Phase 2: Core sync functionality
configure_pcloud
wait_for_sync_ready

log_message "Starting SYNCRO folder sync..."
if sync_syncro_folder; then
    log_message "✓ SYNCRO folder sync completed successfully"
    create_desktop_shortcut
    
    # Phase 3: Optional FUSE mount (only if sync succeeded)
    log_message "Sync successful - attempting optional FUSE mount..."
    if try_mount_pcloud; then
        log_message "✓ FUSE mount completed successfully"
    else
        log_message "Note: FUSE mount not available (this is expected and won't affect sync)"
    fi
else
    log_message "Error: SYNCRO folder sync failed - check the logs at $LOG_FILE"
    exit 1
fi

log_message "Setup completed"
log_message "SYNCRO folder location: $LOCAL_SYNC_DIR"
[ -d "$MOUNT_POINT" ] && log_message "FUSE mount point (if working): $MOUNT_POINT"
log_message "For detailed logs, check: $LOG_FILE"