#!/bin/bash

VERSION="1.4.1"
set -e
trap cleanup EXIT

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
        log_message "Warning: pcloudfs not found! Falling back to pcloudcc-only mode."
    fi
}

configure_pcloud() {
    if [ -z "$PCLOUD_EMAIL" ] || [ -z "$PCLOUD_PASSWORD" ]; then
        log_message "Error: Please set PCLOUD_EMAIL and PCLOUD_PASSWORD"
        exit 1
    fi

    log_message "Configuring pCloud..."
    pcloudcc -u "$PCLOUD_EMAIL" -p "$PCLOUD_PASSWORD" -s
    log_message "pCloud configured."
}

sync_syncro_folder() {
    log_message "Ensuring local SYNCRO directory exists: $LOCAL_SYNC_DIR"
    mkdir -p "$LOCAL_SYNC_DIR"

    log_message "Syncing SYNCRO folder from pCloud to $LOCAL_SYNC_DIR..."
    pcloudcc -u "$PCLOUD_EMAIL" -p "$PCLOUD_PASSWORD" -c sync -s "/$SYNCRO_FOLDER" -d "$LOCAL_SYNC_DIR"
    log_message "Sync completed for SYNCRO folder."
}

mount_pcloud() {
    log_message "Attempting to mount pCloud with FUSE..."
    mkdir -p "$MOUNT_POINT"

    if mountpoint -q "$MOUNT_POINT"; then
        log_message "pCloud already mounted."
        return 0
    fi

    if command -v pcloudfs >/dev/null; then
        log_message "Mounting pCloud using pcloudfs..."
        nohup pcloudfs "$MOUNT_POINT" > /dev/null 2>&1 &
        sleep 5  

        if mountpoint -q "$MOUNT_POINT"; then
            log_message "pCloud mounted at $MOUNT_POINT"
            return 0
        else
            log_message "Warning: pCloud FUSE mount failed. Skipping..."
            return 1
        fi
    else
        log_message "pcloudfs not found. Skipping mount."
        return 1
    fi
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
}

log_message "Starting pCloud setup v$VERSION..."
install_dependencies

if [ "$BUILD_FROM_SOURCE" = true ]; then
    check_and_clone_pcloudcc_repo
    build_pcloudcc
    verify_pcloud_binaries
fi

configure_pcloud

# **Step 1: Sync SYNCRO Folder (Blocking)**
sync_syncro_folder

# **Step 2: Parallel Mounting FUSE (Background)**
mount_pcloud &

create_desktop_shortcut
log_message "pCloud setup completed successfully."

log_message "You can now access the SYNCRO folder at: $LOCAL_SYNC_DIR"
log_message "If FUSE is successful, cloud drive is mounted at: $MOUNT_POINT"