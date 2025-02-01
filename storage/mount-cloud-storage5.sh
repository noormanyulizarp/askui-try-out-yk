#!/bin/bash

VERSION="1.1.0"
set -e
trap cleanup EXIT

BUILD_DIR="/tmp/pcloud-build"
BUILD_FROM_SOURCE=${BUILD_FROM_SOURCE:-true}
MOUNT_POINT="/workspace/pcloud"
SHARED_DIR="/workspace/pcloud/Shares"
LOCAL_COPY_DIR="/workspace/local_copy"

cleanup() {
    [ -d "$BUILD_DIR" ] && rm -rf "$BUILD_DIR"
}

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

install_dependencies() {
    log_message "Installing required dependencies..."
    DEPS=(
        "cmake"
        "libfuse-dev"
        "libcurl4-openssl-dev"
        "libsqlite3-dev"
        "build-essential"
        "git"
        "zlib1g-dev"
        "libboost-system-dev"
        "libboost-program-options-dev"
        "libpthread-stubs0-dev"
        "libudev-dev"
    )
    sudo apt-get update
    sudo apt-get install -y "${DEPS[@]}"
}

check_and_clone_pcloudcc_repo() {
    log_message "Checking if pCloud console client repository exists..."

    # Check if the console-client directory already exists
    if [ -d "$HOME/console-client" ]; then
        log_message "console-client directory already exists. Skipping clone."
    else
        log_message "Cloning pCloud console client repository..."
        git clone https://github.com/pcloudcom/console-client.git ~/console-client
    fi
    cd ~/console-client/pCloudCC/
}

build_pcloudcc() {
    log_message "Building pCloud console client..."

    # Clean and build pclsync
    cd lib/pclsync/
    make clean
    make fs

    # Build mbedtls
    cd ../mbedtls/
    cmake .
    make clean
    make

    # Go back to root and build the entire project
    cd ../..
    cmake .
    make
    sudo make install
    sudo ldconfig

    log_message "pCloud built and installed successfully."
}

configure_pcloud() {
    [ -z "$PCLOUD_EMAIL" ] || [ -z "$PCLOUD_PASSWORD" ] && \
        { log_message "Error: Please set PCLOUD_EMAIL and PCLOUD_PASSWORD"; exit 1; }

    log_message "Configuring pCloud..."
    echo "$PCLOUD_PASSWORD" | pcloudcc -u "$PCLOUD_EMAIL" -p -s
    log_message "pCloud configured."

    log_message "Checking sync status..."
    local timeout=60
    local elapsed=0
    while [ "$(pcloudcc status | grep -oP 'status is \K\w+')" != "READY" ]; do
        sleep 5
        elapsed=$((elapsed+5))
        [ "$elapsed" -ge "$timeout" ] && \
            { log_message "Timeout waiting for sync"; exit 1; }
    done
    log_message "Sync is READY."
}

mount_pcloud() {
    mkdir -p "$MOUNT_POINT"
    
    if ! mountpoint -q "$MOUNT_POINT"; then
        log_message "Mounting pCloud..."
        pcloudfs "$MOUNT_POINT"
        log_message "pCloud mounted at $MOUNT_POINT"
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
[ "$BUILD_FROM_SOURCE" = true ] && { check_and_clone_pcloudcc_repo; build_pcloudcc; }
configure_pcloud
mount_pcloud
sync_shared_folders
create_desktop_shortcut
log_message "pCloud setup completed successfully."