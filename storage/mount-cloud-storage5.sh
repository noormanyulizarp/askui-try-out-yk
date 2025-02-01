#!/bin/bash

VERSION="1.2.0"
set -e
trap cleanup EXIT

BUILD_DIR="/tmp/pcloud-build"
BUILD_FROM_SOURCE=${BUILD_FROM_SOURCE:-true}
MOUNT_POINT="/workspace/pcloud"
SHARED_DIR="/workspace/pcloud/Shares"
LOCAL_COPY_DIR="/workspace/local_copy"
PCLOUD_REPO="https://github.com/pcloudcom/console-client.git"
PCLOUD_DIR="$HOME/console-client"

cleanup() {
    [ -d "$BUILD_DIR" ] && rm -rf "$BUILD_DIR"
}

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

install_dependencies() {
    log_message "Installing required dependencies..."
    sudo apt-get update
    sudo apt-get install -y cmake libfuse-dev libcurl4-openssl-dev libsqlite3-dev \
                            build-essential git zlib1g-dev libboost-system-dev \
                            libboost-program-options-dev libpthread-stubs0-dev libudev-dev fuse
}

check_and_clone_pcloudcc_repo() {
    log_message "Checking pCloud console client repository..."
    if [ ! -d "$PCLOUD_DIR" ]; then
        log_message "Cloning pCloud console client repository..."
        git clone "$PCLOUD_REPO" "$PCLOUD_DIR"
    else
        log_message "Repository already exists. Pulling latest changes..."
        cd "$PCLOUD_DIR" && git pull
    fi
    cd "$PCLOUD_DIR/pCloudCC/"
}

build_pcloudcc() {
    log_message "Building pCloud console client..."
    cd lib/pclsync/
    make clean && make fs
    
    cd ../mbedtls/
    cmake . && make clean && make
    
    cd ../..
    cmake .
    make -j$(nproc)
    sudo make install
    sudo ldconfig

    log_message "pCloud built and installed successfully."
}

verify_pcloud_binaries() {
    if command -v pcloudcc >/dev/null; then
        log_message "pcloudcc installed successfully."
    else
        log_message "Error: pcloudcc not found! Build may have failed."
        exit 1
    fi

    if command -v pcloudfs >/dev/null; then
        log_message "pcloudfs installed successfully."
    else
        log_message "Warning: pcloudfs not found! Ensure FUSE is installed."
    fi
}

configure_pcloud() {
    if [ -z "$PCLOUD_EMAIL" ] || [ -z "$PCLOUD_PASSWORD" ]; then
        log_message "Error: Please set PCLOUD_EMAIL and PCLOUD_PASSWORD"
        exit 1
    fi

    log_message "Configuring pCloud..."
    echo "$PCLOUD_PASSWORD" | pcloudcc -u "$PCLOUD_EMAIL" -p -s
    log_message "pCloud configured."
}

wait_for_sync_ready() {
    log_message "Checking sync status..."
    local timeout=60 elapsed=0
    while [ "$(pcloudcc status | grep -oP 'status is \K\w+')" != "READY" ]; do
        sleep 5
        elapsed=$((elapsed+5))
        [ "$elapsed" -ge "$timeout" ] && {
            log_message "Timeout waiting for sync"; exit 1;
        }
    done
    log_message "Sync is READY."
}

mount_pcloud() {
    mkdir -p "$MOUNT_POINT"
    if ! mountpoint -q "$MOUNT_POINT"; then
        if command -v pcloudfs >/dev/null; then
            log_message "Mounting pCloud using pcloudfs..."
            pcloudfs "$MOUNT_POINT"
            log_message "pCloud mounted at $MOUNT_POINT"
        else
            log_message "pcloudfs not found. Skipping mount."
        fi
    else
        log_message "pCloud already mounted."
    fi
}

sync_shared_folders() {
    if [ -d "$SHARED_DIR" ]; then
        log_message "Syncing shared folders..."
        pcloudcc -u "$PCLOUD_EMAIL" -p "$PCLOUD_PASSWORD" -c sync -s "$SHARED_DIR" -d "$LOCAL_COPY_DIR"
    else
        log_message "Shared directory not found. Skipping sync."
    fi
}

create_desktop_shortcut() {
    log_message "Creating desktop shortcut..."
    mkdir -p /home/gitpod/Desktop
    cat <<EOF > /home/gitpod/Desktop/pCloud.desktop
[Desktop Entry]
Name=pCloud
Comment=Access your pCloud storage
Exec=nautilus $MOUNT_POINT
Icon=folder
Terminal=false
Type=Application
Categories=Utility;
EOF
    chmod +x /home/gitpod/Desktop/pCloud.desktop
}

log_message "Starting pCloud setup v$VERSION..."
install_dependencies
if [ "$BUILD_FROM_SOURCE" = true ]; then
    check_and_clone_pcloudcc_repo
    build_pcloudcc
    verify_pcloud_binaries
fi
configure_pcloud
wait_for_sync_ready
mount_pcloud
sync_shared_folders
create_desktop_shortcut
log_message "pCloud setup completed successfully."