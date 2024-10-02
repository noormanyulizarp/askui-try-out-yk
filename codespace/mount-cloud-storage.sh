#!/bin/bash

# Logging function for consistent message format
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Retry mechanism with customizable attempts and sleep time
retry_command() {
    local command="$1"
    local max_attempts="$2"
    local sleep_time="$3"
    local attempt=1

    until $command; do
        if (( attempt >= max_attempts )); then
            log_message "Error: Command failed after $max_attempts attempts."
            return 1
        fi
        log_message "Retrying command... (Attempt $attempt/$max_attempts)"
        ((attempt++))
        sleep "$sleep_time"
    done
    return 0
}

# Check if MEGA CMD is installed
check_mega_installed() {
    command -v mega-cmd-server &> /dev/null
}

# Start the MEGA CMD server and ensure it runs successfully
start_mega_server() {
    log_message "Starting MEGA CMD server..."
    mega-cmd-server &

    local max_wait=120
    local elapsed=0

    until mega-whoami &> /dev/null; do
        if (( elapsed >= max_wait )); then
            log_message "Error: MEGA CMD server failed to start within $max_wait seconds."
            return 1
        fi
        log_message "Waiting for MEGA CMD server to start... ($elapsed seconds)"
        sleep 2
        elapsed=$((elapsed + 2))
    done
    log_message "MEGA CMD server started successfully."
}

# Mount the MEGA drive at a specified path
mount_mega_drive() {
    local mount_path="/workspaces/${CODESPACE_REPO_NAME}/mega"
    if ! mountpoint -q "$mount_path"; then
        log_message "Mounting MEGA to $mount_path..."
        mkdir -p "$mount_path"

        local max_wait=120
        local elapsed=0

        until mega-mount "$mount_path" &> /dev/null; do
            if (( elapsed >= max_wait )); then
                log_message "Error: Failed to mount MEGA within $max_wait seconds."
                exit 1
            fi
            log_message "Retrying MEGA mount... ($elapsed seconds)"
            sleep 5
            elapsed=$((elapsed + 5))
        done
        log_message "MEGA mounted successfully."
    else
        log_message "MEGA is already mounted at $mount_path."
    fi
}

# Create a desktop shortcut for easy MEGA access
create_mega_shortcut() {
    log_message "Creating MEGA desktop shortcut..."
    local desktop_dir="/home/vscode/Desktop"
    mkdir -p "$desktop_dir"
    
    cat <<EOF > "$desktop_dir/MEGA.desktop"
[Desktop Entry]
Name=MEGA
Comment=Access your MEGA cloud storage
Exec=nautilus /workspaces/${CODESPACE_REPO_NAME}/mega
Icon=folder
Terminal=false
Type=Application
Categories=Utility;
EOF

    chmod +x "$desktop_dir/MEGA.desktop"
    log_message "MEGA desktop shortcut created."
}

# Sync the local folder with the MEGA folder
sync_mega() {
    log_message "Starting MEGA sync..."
    if command -v mega-sync &> /dev/null; then
        mega-sync /workspaces/${CODESPACE_REPO_NAME}/mega /GitPod-Workspace
    else
        mega-cmd sync start /workspaces/${CODESPACE_REPO_NAME}/mega /GitPod-Workspace
    fi
    log_message "MEGA sync completed."
}

# Main execution starts here
main() {
    retry_command check_mega_installed 3 10
    retry_command start_mega_server 3 10
    retry_command mount_mega_drive 3 10
    sync_mega
    create_mega_shortcut
}

main "$@"
