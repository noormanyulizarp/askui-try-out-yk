#!/bin/bash

# Logging function
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Retry mechanism with max attempts
retry() {
    local -r command=$1
    local -r max_attempts=$2
    local -r sleep_time=$3
    local attempt=1

    until $command; do
        if (( attempt == max_attempts )); then
            log_message "Error: Failed after $max_attempts attempts."
            return 1
        fi
        log_message "Retrying... (Attempt $attempt/$max_attempts)"
        ((attempt++))
        sleep "$sleep_time"
    done
    return 0
}

# Function to check if MEGA CMD is installed
is_mega_cmd_installed() {
    command -v mega-cmd-server &> /dev/null
}

# Function to setup MEGA CMD
setup_mega() {
    if ! is_mega_cmd_installed; then
        log_message "MEGA CMD not found. Installing..."
        wget https://mega.nz/linux/repo/xUbuntu_22.04/amd64/megacmd-xUbuntu_22.04_amd64.deb -O /tmp/megacmd.deb
        sudo dpkg -i /tmp/megacmd.deb
        sudo apt-get -f install -y
        rm /tmp/megacmd.deb

        if [ -n "$MEGA_EMAIL" ] && [ -n "$MEGA_PASSWORD" ]; then
            log_message "Configuring MEGA..."
            mega-login "$MEGA_EMAIL" "$MEGA_PASSWORD"
        else
            log_message "Error: MEGA credentials not set. Please set MEGA_EMAIL and MEGA_PASSWORD in environment variables."
            exit 1
        fi
    else
        log_message "MEGA CMD is already installed."
    fi
}

# Function to start MEGA CMD server
start_mega_server() {
    log_message "Starting MEGA CMD server..."
    mega-cmd-server &

    local max_wait=120
    local elapsed=0

    while ! mega-whoami &> /dev/null; do
        if (( elapsed >= max_wait )); then
            log_message "Error: MEGA CMD server failed to start within $max_wait seconds."
            exit 1
        fi
        log_message "Waiting for MEGA CMD server to start... ($elapsed seconds elapsed)"
        sleep 2
        elapsed=$((elapsed + 2))
    done

    log_message "MEGA CMD server started successfully."
}

# Function to mount MEGA
mount_mega() {
    if ! mountpoint -q /workspaces/${CODESPACE_REPO_NAME}/mega; then
        log_message "Mounting MEGA..."
        mkdir -p /workspaces/${CODESPACE_REPO_NAME}/mega

        local max_wait=120
        local elapsed=0

        until mega-mount /workspaces/${CODESPACE_REPO_NAME}/mega &> /dev/null; do
            if (( elapsed >= max_wait )); then
                log_message "Error: Failed to mount MEGA within $max_wait seconds."
                exit 1
            fi
            log_message "Retrying mount... ($elapsed seconds elapsed)"
            sleep 5
            elapsed=$((elapsed + 5))
        done

        log_message "MEGA mounted successfully."
    else
        log_message "MEGA is already mounted."
    fi
}

# Function to create a desktop shortcut for MEGA
create_desktop_shortcut() {
    log_message "Creating desktop shortcut for MEGA..."
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
    log_message "Desktop shortcut for MEGA created."
}

# Function to sync local folder with MEGA folder
sync_mega() {
    log_message "Syncing local folder with MEGA..."
    if command -v mega-sync &> /dev/null; then
        mega-sync /workspaces/${CODESPACE_REPO_NAME}/mega /GitPod-Workspace
    else
        mega-cmd sync start /workspaces/${CODESPACE_REPO_NAME}/mega /GitPod-Workspace
    fi
    log_message "Sync complete."
}

# Ensure MEGA CMD server is running and mount MEGA
retry setup_mega 3 10
retry start_mega_server 3 10
retry mount_mega 3 10
sync_mega
create_desktop_shortcut
