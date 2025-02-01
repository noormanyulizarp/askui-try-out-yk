#!/bin/bash

VERSION="1.1.0"

set -e
trap cleanup EXIT

BUILD_DIR="/tmp/pcloud-build"
BUILD_FROM_SOURCE=${BUILD_FROM_SOURCE:-true}

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
        "zlib1g-dev"
        "libboost-system-dev"
        "libboost-program-options-dev"
        "libfuse-dev"
        "libudev-dev"
        "fuse"
        "build-essential"
        "git"
    )
    sudo apt-get update
    sudo apt-get install -y "${DEPS[@]}"
}

build_from_source() {
    log_message "Building pCloud console client..."
    mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR"
    git clone https://github.com/pcloudcom/console-client.git
    cd console-client/pCloudCC/
    make clean && make
    sudo make install && sudo ldconfig
    log_message "pCloud built successfully."
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
    local mount_point="/workspace/pcloud"
    mkdir -p "$mount_point"
    
    if ! mountpoint -q "$mount_point"; then
        log_message "Mounting pCloud..."
        pcloudfs "$mount_point"
        log_message "pCloud mounted at $mount_point"
    else
        log_message "pCloud already mounted."
    fi
}

sync_shared_folders() {
    log_message "Syncing shared folders..."
    local shared_dir="/workspace/pcloud/Shares"
    [ -d "$shared_dir" ] && pcloudcc -u "$PCLOUD_EMAIL" -p "$PCLOUD_PASSWORD" -c sync -s "$shared_dir" -d "/workspace/local_copy"
}

create_desktop_shortcut() {
    log_message "Creating desktop shortcut..."
    mkdir -p /home/gitpod/Desktop
    cat <<EOF > /home/gitpod/Desktop/pCloud.desktop
[Desktop Entry]
Name=pCloud
Comment=Access your pCloud storage
Exec=nautilus /workspace/pcloud
Icon=folder
Terminal=false
Type=Application
Categories=Utility;
EOF
    chmod +x /home/gitpod/Desktop/pCloud.desktop
}

log_message "Starting pCloud setup v$VERSION..."
install_dependencies
[ "$BUILD_FROM_SOURCE" = true ] && build_from_source
configure_pcloud
mount_pcloud
sync_shared_folders
create_desktop_shortcut
log_message "pCloud setup completed successfully."