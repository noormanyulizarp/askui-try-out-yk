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

    # Check sync status and wait for it to be READY
    log_message "Waiting for pCloud sync to complete..."
    local sync_status="SCANNING"
    while [ "$sync_status" != "READY" ]; do
        sleep 5
        # Get the current sync status
        sync_status=$(pcloudcc status | grep -oP 'status is \K\w+')
        log_message "Current sync status: $sync_status"
        if [ "$sync_status" == "ERROR" ]; then
            log_message "Error: Sync encountered an issue."
            exit 1
        fi
    done

    log_message "pCloud sync completed successfully. Status is READY."
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

        # Mount pCloud using FUSE and capture verbose output
        sudo mount -t fuse pcloud "$mount_point" -o allow_other,default_permissions,debug
        if [ $? -ne 0 ]; then
            log_message "Error: Failed to mount pCloud. Check logs for FUSE errors."
            exit 1
        fi
        
        # Wait for mount to complete and check status
        local max_wait=30
        local wait_time=0
        while ! mountpoint -q "$mount_point"; do
            sleep 1
            ((wait_time++))
            if [ $wait_time -ge $max_wait ]; then
                log_message "Error: Mount timeout after ${max_wait} seconds"
                exit 1
            fi
            log_message "Waiting for mount... ($wait_time/$max_wait seconds)"
        done
        
        log_message "pCloud mounted successfully at $mount_point"
    else
        log_message "pCloud is already mounted at $mount_point"
    fi
}

# Function to create desktop shortcut
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
    log_message "Desktop shortcut created successfully"
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
create_desktop_shortcut

log_message "pCloud setup completed successfully"
