#!/bin/bash

VERSION="1.0.0"

# Exit on error
set -e

# Cleanup handler
trap cleanup EXIT

# Global variables
BUILD_DIR="/tmp/pcloud-build"
BUILD_FROM_SOURCE=${BUILD_FROM_SOURCE:-true}
RCLONE_REMOTE="pcloud"  # Name of the rclone remote
MOUNT_POINT="/workspace/pcloud"

# Cleanup function
cleanup() {
    if [ -d "$BUILD_DIR" ]; then
        log_message "Cleaning up build directory..."
        rm -rf "$BUILD_DIR"
    fi
    if mountpoint -q "$MOUNT_POINT"; then
        log_message "Unmounting pCloud..."
        fusermount -u "$MOUNT_POINT"
    fi
}

# Logging function
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Function to check disk space
check_disk_space() {
    local required_space=1000000  # 1GB in KB
    local available_space=$(df /tmp -k | awk 'NR==2 {print $4}')
    if [ "$available_space" -lt "$required_space" ]; then
        log_message "Error: Insufficient disk space. Required: 1GB, Available: $((available_space/1024))MB"
        exit 1
    fi
    log_message "Disk space check passed"
}

# Function to check and install dependencies
install_dependencies() {
    log_message "Installing required dependencies..."
    
    # List of required packages
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

    # Include libfuse2 if running on Ubuntu 22.04
    if grep -q "Ubuntu 22.04" /etc/os-release; then
        log_message "Ubuntu 22.04 detected, adding libfuse2 to dependencies..."
        DEPS+=("libfuse2")
        sudo add-apt-repository universe -y
    fi

    # Update package list and install dependencies
    log_message "Updating package list..."
    sudo apt-get update

    log_message "Installing ${#DEPS[@]} packages..."
    sudo apt-get install -y "${DEPS[@]}"
    
    if [ $? -ne 0 ]; then
        log_message "Error: Failed to install dependencies"
        exit 1
    fi

    # Install rclone
    log_message "Installing rclone..."
    curl https://rclone.org/install.sh | sudo bash
    if [ $? -ne 0 ]; then
        log_message "Error: Failed to install rclone"
        exit 1
    fi
    
    log_message "Dependencies installed successfully"
}

# Function to build pCloud from source
build_from_source() {
    log_message "Building pCloud console client from source..."
    
    # Check disk space before building
    check_disk_space
    
    # Set up build directory
    mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR"
    
    # Clone the repository
    log_message "Cloning pCloud console client repository..."
    git clone https://github.com/pcloudcom/console-client.git
    cd console-client/pCloudCC/
    
    # Build pCloud sync library
    log_message "Building pCloud sync library..."
    cd lib/pclsync/ && make clean && make fs
    if [ $? -ne 0 ]; then
        log_message "Error: Failed to build pCloud sync library"
        exit 1
    fi

    # Build mbedtls
    log_message "Building mbedtls..."
    cd ../mbedtls/ && cmake . && make clean && make
    if [ $? -ne 0 ]; then
        log_message "Error: Failed to build mbedtls"
        exit 1
    fi

    # Build main application
    log_message "Building main application..."
    cd ../.. && cmake . && make
    if [ $? -ne 0 ]; then
        log_message "Error: Failed to build pCloud console client"
        exit 1
    fi

    # Install the built application
    log_message "Installing pCloud console client..."
    sudo make install && sudo ldconfig
    
    log_message "pCloud console client built and installed successfully"
}

# Function to configure pCloud
configure_pcloud() {
    if ! command -v pcloudcc &> /dev/null; then
        log_message "Error: pcloudcc not found. Installation failed."
        exit 1
    fi
    
    if [ -z "$PCLOUD_EMAIL" ] || [ -z "$PCLOUD_PASSWORD" ]; then
        log_message "Error: pCloud credentials not set. Please set PCLOUD_EMAIL and PCLOUD_PASSWORD"
        exit 1
    fi

    log_message "Configuring pCloud..."

    # Login and save password
    echo "$PCLOUD_PASSWORD" | pcloudcc -u "$PCLOUD_EMAIL" -p -s
    if [ $? -ne 0 ]; then
        log_message "Error: Failed to configure pCloud"
        exit 1
    fi
    
    log_message "pCloud configured successfully"
}

# Function to sync pCloud using rclone
sync_pcloud() {
    log_message "Syncing pCloud using rclone..."
    rclone sync "$RCLONE_REMOTE":/ "$MOUNT_POINT" --vfs-cache-mode full
    if [ $? -ne 0 ]; then
        log_message "Error: Failed to sync pCloud using rclone"
        exit 1
    fi
    log_message "pCloud sync completed successfully."
}

# Main execution
log_message "Starting pCloud setup script v$VERSION..."

# Ensure environment variables are set
if [ -z "$PCLOUD_EMAIL" ] || [ -z "$PCLOUD_PASSWORD" ]; then
    log_message "Error: Please set PCLOUD_EMAIL and PCLOUD_PASSWORD environment variables"
    exit 1
fi

# Run setup steps
install_dependencies

if [ "$BUILD_FROM_SOURCE" = true ]; then
    build_from_source
else
    log_message "Skipping source build (BUILD_FROM_SOURCE=false)"
fi

configure_pcloud
sync_pcloud

log_message "pCloud setup completed successfully"