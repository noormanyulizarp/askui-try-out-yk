#!/bin/bash

VERSION="1.0.0"

# Exit on error
set -e

# Cleanup handler
trap cleanup EXIT

# Global variables
BUILD_DIR="/tmp/pcloud-build"
BUILD_FROM_SOURCE=${BUILD_FROM_SOURCE:-true}

# Cleanup function
cleanup() {
    if [ -d "$BUILD_DIR" ]; then
        log_message "Cleaning up build directory..."
        rm -rf "$BUILD_DIR"
    fi
}

# Logging function
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
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
        "expect"  # Added expect for non-interactive authentication
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
    
    log_message "Dependencies installed successfully"
}

# Function to build pCloud from source
build_from_source() {
    log_message "Building pCloud console client from source..."
    
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

# Function to configure pCloud with non-interactive authentication
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

    # Use expect for non-interactive authentication
    /usr/bin/expect <<EOF
    spawn pcloudcc -u "$PCLOUD_EMAIL" -p
    expect "Password:"
    send "$PCLOUD_PASSWORD\r"
    expect eof
EOF

    # Verify sync status
    log_message "Checking pCloud sync status..."
    local sync_status=$(pcloudcc status | grep -oP 'status is \K\w+')
    log_message "Current sync status: $sync_status"

    if [ "$sync_status" == "ERROR" ]; then
        log_message "Error: Sync encountered an issue."
        exit 1
    fi

    log_message "pCloud configured successfully"
}

# Function to mount pCloud
mount_pcloud() {
    local mount_point="${1:-/workspace/pcloud}"

    # Check if user is in fuse group
    if ! groups $USER | grep -q '\bfuse\b'; then
        log_message "Warning: User is not in the fuse group. Adding user to fuse group..."
        sudo usermod -aG fuse $USER
        log_message "You need to log out and log back in for this change to take effect."
        exit 1
    fi

    if ! mountpoint -q "$mount_point"; then
        log_message "Creating mount point at $mount_point..."
        mkdir -p "$mount_point"
        
        log_message "Starting pCloud mount with FUSE..."

        # Mount pCloud using FUSE
        pcloudcc -m "$mount_point"
        if [ $? -ne 0 ]; then
            log_message "Error: Failed to mount pCloud."
            exit 1
        fi
        
        log_message "pCloud mounted successfully at $mount_point"
    else
        log_message "pCloud is already mounted at $mount_point"
    fi
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
mount_pcloud "/workspace/pcloud"

log_message "pCloud setup completed successfully"