#!/bin/bash

# Logging function with log level
log_message() {
    local level="$1"
    shift
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $*"
}

# Retry mechanism with max attempts
retry() {
    local command="$1"
    shift
    local max_attempts="$1"
    local sleep_time="$2"
    shift 2
    local attempt=1
    until eval "$command" "$@"; do
        if (( attempt == max_attempts )); then
            log_message "ERROR" "Failed after $max_attempts attempts."
            return 1
        fi
        log_message "INFO" "Retrying... (Attempt $attempt/$max_attempts)"
        ((attempt++))
        sleep "$sleep_time"
    done
    return 0
}

# Validate required dependencies
validate_dependencies() {
    local dependencies=("mega-whoami" "mega-login" "wget" "curl")
    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log_message "ERROR" "Required dependency '$dep' is not installed."
            exit 1
        fi
    done
    log_message "INFO" "All required dependencies are installed."
}

# Configure MEGA
configure_mega() {
    log_message "INFO" "Configuring MEGA..."
    if ! mega-whoami &> /dev/null; then
        if [[ -z "$MEGA_EMAIL" || -z "$MEGA_PASSWORD" ]]; then
            log_message "ERROR" "MEGA_EMAIL and MEGA_PASSWORD environment variables are not set."
            exit 1
        fi
        if ! mega-login "$MEGA_EMAIL" "$MEGA_PASSWORD"; then
            log_message "ERROR" "Login to MEGA failed. Please verify your credentials."
            exit 1
        fi
        log_message "INFO" "Logged into MEGA successfully."
    else
        log_message "INFO" "Already logged into MEGA."
    fi
}

# Mount MEGA
mount_mega() {
    local mount_point="/workspace/mega"
    if ! mountpoint -q "$mount_point"; then
        log_message "INFO" "Mounting MEGA to $mount_point..."
        mkdir -p "$mount_point"
        retry "mega-mount $mount_point" 5 2 || {
            log_message "ERROR" "Failed to mount MEGA."
            exit 1
        }
        log_message "INFO" "MEGA mounted successfully at $mount_point."
    else
        log_message "INFO" "MEGA is already mounted at $mount_point."
    fi
}

# Sync local folder with MEGA folder
sync_mega() {
    log_message "INFO" "Syncing local folder with MEGA..."
    local_mega_dir="/workspace/mega"
    remote_mega_dir="/GitPod-Workspace"
    retry "mega-sync $local_mega_dir $remote_mega_dir" 3 5 || {
        log_message "ERROR" "Sync failed after multiple attempts."
        exit 1
    }
    log_message "INFO" "Sync completed successfully."
}

# Create a desktop shortcut for MEGA
create_desktop_shortcut() {
    log_message "INFO" "Creating desktop shortcut for MEGA..."
    local shortcut_path="/home/gitpod/Desktop/MEGA.desktop"
    mkdir -p "$(dirname "$shortcut_path")"
    cat <<EOF > "$shortcut_path"
[Desktop Entry]
Name=MEGA
Comment=Access your MEGA cloud storage
Exec=nautilus /workspace/mega
Icon=folder
Terminal=false
Type=Application
Categories=Utility;
EOF
    chmod +x "$shortcut_path"
    log_message "INFO" "Desktop shortcut created at $shortcut_path."
}

# Check network connectivity
check_network() {
    if ! ping -c 1 google.com &> /dev/null; then
        log_message "ERROR" "No internet connection. Please check your network."
        exit 1
    fi
    log_message "INFO" "Network connectivity verified."
}

# Cleanup: Unmount MEGA if necessary
cleanup() {
    if mountpoint -q /workspace/mega; then
        log_message "INFO" "Unmounting MEGA..."
        fusermount -u /workspace/mega || log_message "WARNING" "Failed to unmount MEGA."
    fi
}

# Trap cleanup on exit
trap cleanup EXIT

# Main execution flow
log_message "INFO" "Starting MEGA setup..."
validate_dependencies
check_network
configure_mega
mount_mega
sync_mega
create_desktop_shortcut
log_message "INFO" "MEGA setup completed successfully."
