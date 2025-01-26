#!/bin/bash

VERSION="1.1.0"

# Exit on error
set -e

# Cleanup handler
trap cleanup EXIT SIGINT SIGTERM

# Global variables
BUILD_DIR="/tmp/pcloud-build"
BUILD_FROM_SOURCE=${BUILD_FROM_SOURCE:-true}
MOUNT_POINT="/workspace/pcloud"  # Local mount point
LOG_FILE="/var/log/pcloud-setup.log"
SERVICE_NAME="pcloudcc.service"

# Cleanup function
cleanup() {
    log_message "Cleaning up..."
    if [ -d "$BUILD_DIR" ]; then
        log_message "Removing build directory: $BUILD_DIR"
        rm -rf "$BUILD_DIR"
    fi
    log_message "Cleanup completed."
}

# Logging function
log_message() {
    local message="$(date '+%Y-%m-%d %H:%M:%S') - $1"
    echo "$message" | tee -a "$LOG_FILE"
}

# Function to verify pCloud credentials
verify_credentials() {
    if [ -z "$PCLOUD_EMAIL" ]; then
        log_message "Error: PCLOUD_EMAIL is not set. Please set the PCLOUD_EMAIL environment variable."
        exit 1
    fi

    if [ -z "$PCLOUD_PASSWORD" ]; then
        log_message "Error: PCLOUD_PASSWORD is not set. Please set the PCLOUD_PASSWORD environment variable."
        exit 1
    fi

    log_message "pCloud credentials verified successfully."
}

# Function to check disk space
check_disk_space() {
    local required_space=1000000  # 1GB in KB
    local available_space=$(df /tmp -k | awk 'NR==2 {print $4}')
    if [ "$available_space" -lt "$required_space" ]; then
        log_message "Error: Insufficient disk space. Required: 1GB, Available: $((available_space/1024))MB"
        exit 1
    fi
    log_message "Disk space check passed."
}

# Function to install dependencies
install_dependencies() {
    log_message "Installing required dependencies..."

    DEPS=(
        "cmake"
        "zlib1g-dev"
        "libboost-system-dev"
        "libboost-program-options-dev"
        "libpthread-stubs0-dev"
        "libfuse-dev"
        "libudev-dev"
        "fuse"
        "build-essential"
        "git"
    )

    if grep -q "Ubuntu 22.04" /etc/os-release; then
        log_message "Ubuntu 22.04 detected, adding libfuse2 to dependencies..."
        DEPS+=("libfuse2")
        sudo add-apt-repository universe -y
    fi

    sudo apt-get update
    sudo apt-get install -y "${DEPS[@]}"
    log_message "Dependencies installed successfully."
}

# Function to build pCloud from source
build_from_source() {
    log_message "Building pCloud console client from source..."

    check_disk_space
    mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR"

    log_message "Cloning pCloud console client repository..."
    git clone https://github.com/pcloudcom/console-client.git
    cd console-client/pCloudCC/

    log_message "Building pCloud sync library..."
    cd lib/pclsync/ && make clean && make fs || { log_message "Error: Failed to build pCloud sync library"; exit 1; }

    log_message "Building mbedtls..."
    cd ../mbedtls/ && cmake . && make clean && make || { log_message "Error: Failed to build mbedtls"; exit 1; }

    log_message "Building main application..."
    cd ../.. && cmake . && make || { log_message "Error: Failed to build pCloud console client"; exit 1; }

    log_message "Installing pCloud console client..."
    sudo make install && sudo ldconfig
    log_message "pCloud console client built and installed successfully."
}

# Function to configure pCloud
configure_pcloud() {
    if ! command -v pcloudcc &> /dev/null; then
        log_message "Error: pcloudcc not found. Installation failed."
        exit 1
    fi

    log_message "Configuring pCloud..."

    # Login to pCloud
    echo "$PCLOUD_PASSWORD" | pcloudcc -u "$PCLOUD_EMAIL" -p -s
    if [ $? -ne 0 ]; then
        log_message "Error: Failed to configure pCloud. Please check your credentials."
        exit 1
    fi

    log_message "pCloud configured successfully."

    # Wait for sync to complete with a timeout
    local timeout=300  # 5 minutes
    local start_time=$(date +%s)
    log_message "Waiting for pCloud sync to complete (timeout: $timeout seconds)..."
    local sync_status="SCANNING"
    while [ "$sync_status" != "READY" ]; do
        sleep 5
        sync_status=$(pcloudcc status | grep -oP 'status is \K\w+')
        log_message "Current sync status: $sync_status"
        if [ "$sync_status" == "ERROR" ]; then
            log_message "Error: Sync encountered an issue."
            exit 1
        fi
        # Check if timeout has been reached
        if [ $(($(date +%s) - start_time)) -ge $timeout ]; then
            log_message "Error: Sync timed out after $timeout seconds."
            exit 1
        fi
    done

    log_message "pCloud sync completed successfully. Status is READY."
}

# Function to mount pCloud
mount_pcloud() {
    # Check if user is in fuse group
    if ! groups $USER | grep -q '\bfuse\b'; then
        log_message "Warning: User is not in the fuse group. Adding user to fuse group..."
        sudo usermod -aG fuse $USER
        log_message "You need to log out and log back in for this change to take effect."
        exit 1
    fi

    # Create mount point if it doesn't exist
    if [ ! -d "$MOUNT_POINT" ]; then
        log_message "Creating mount point at $MOUNT_POINT..."
        mkdir -p "$MOUNT_POINT"
    fi

    # Check mount point permissions
    if ! ls -ld "$MOUNT_POINT" | grep -q "drwxr-xr-x"; then
        log_message "Fixing mount point permissions..."
        sudo chown $USER:$USER "$MOUNT_POINT"
        chmod 755 "$MOUNT_POINT"
    fi

    # Unmount any stale mounts
    if mount | grep -q "$MOUNT_POINT"; then
        log_message "Unmounting stale mount..."
        sudo fusermount -u "$MOUNT_POINT" || sudo umount -l "$MOUNT_POINT"
    fi

    # Start the pCloud client
    log_message "Mounting pCloud to $MOUNT_POINT..."
    echo "$PCLOUD_PASSWORD" | sudo -E pcloudcc --username "$PCLOUD_EMAIL" --password --mountpoint "$MOUNT_POINT"

    # Check if the drive is mounted
    if mount | grep -q "$MOUNT_POINT"; then
        log_message "pCloud is mounted successfully at $MOUNT_POINT."
    else
        log_message "Failed to mount pCloud. Check the logs for errors."
        exit 1
    fi
}

# Function to create desktop shortcut
create_desktop_shortcut() {
    log_message "Creating desktop shortcut..."
    mkdir -p /home/$USER/Desktop
    cat <<EOF > /home/$USER/Desktop/pCloud.desktop
[Desktop Entry]
Name=pCloud
Comment=Access your pCloud storage
Exec=nautilus $MOUNT_POINT
Icon=folder
Terminal=false
Type=Application
Categories=Utility;
EOF
    chmod +x /home/$USER/Desktop/pCloud.desktop
    log_message "Desktop shortcut created successfully."
}

# Main execution
log_message "Starting pCloud setup script v$VERSION..."

# Verify pCloud credentials
verify_credentials

# Run setup steps
install_dependencies

if [ "$BUILD_FROM_SOURCE" = true ]; then
    build_from_source
else
    log_message "Skipping source build (BUILD_FROM_SOURCE=false)."
fi

configure_pcloud
mount_pcloud
create_desktop_shortcut

log_message "pCloud setup completed successfully."