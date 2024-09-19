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

# Function to setup MEGA CMD
setup_mega() {
    log_message "Setting up MEGA CMD..."
    sudo apt-get update
    sudo apt-get install -y libmediainfo0v5 libzen0v5
    wget https://mega.nz/linux/repo/xUbuntu_22.04/amd64/megacmd-xUbuntu_22.04_amd64.deb -O /tmp/megacmd.deb
    sudo dpkg -i /tmp/megacmd.deb
    sudo apt-get -f install -y
    rm /tmp/megacmd.deb

    if [ -n "$MEGA_EMAIL" ] && [ -n "$MEGA_PASSWORD" ]; then
        log_message "Configuring MEGA..."
        mega-login "$MEGA_EMAIL" "$MEGA_PASSWORD"
    else
        log_message "Error: MEGA credentials not set. Please set MEGA_EMAIL and MEGA_PASSWORD in Codespace secrets."
        exit 1
    fi
}

# Function to start MEGA CMD server
start_mega_server() {
    log_message "Starting MEGA CMD server..."
    mega-cmd-server &

    for i in {1..50}; do
        if mega-whoami &> /dev/null; then
            log_message "MEGA CMD server started successfully."
            break
        else
            log_message "Waiting for MEGA CMD server to start... (Attempt $i)"
            sleep 1
        fi
    done
}

# Function to mount MEGA
mount_mega() {
    if ! mountpoint -q /workspaces/${CODESPACE_REPO_NAME}/mega; then
        log_message "Mounting MEGA..."
        mkdir -p /workspaces/${CODESPACE_REPO_NAME}/mega
        if retry "mega-mount /workspaces/${CODESPACE_REPO_NAME}/mega" 5 2; then
            log_message "MEGA mounted successfully."
        else
            log_message "Error: Failed to mount MEGA."
            exit 1
        fi
    else
        log_message "MEGA is already mounted."
    fi
}

# Function to create a desktop shortcut for MEGA
create_desktop_shortcut() {
    log_message "Creating desktop shortcut for MEGA..."
    mkdir -p /home/codespace/Desktop
    cat <<EOF > /home/codespace/Desktop/MEGA.desktop
[Desktop Entry]
Name=MEGA
Comment=Access your MEGA cloud storage
Exec=nautilus /workspaces/${CODESPACE_REPO_NAME}/mega
Icon=folder
Terminal=false
Type=Application
Categories=Utility;
EOF
    chmod +x /home/codespace/Desktop/MEGA.desktop
    log_message "Desktop shortcut for MEGA created."
}

# Function to sync local folder with MEGA folder
sync_mega() {
    log_message "Syncing local folder with MEGA..."
    if command -v mega-sync &> /dev/null; then
        mega-sync /workspaces/${CODESPACE_REPO_NAME}/mega /Codespace-Workspace
    else
        mega-cmd sync /workspaces/${CODESPACE_REPO_NAME}/mega /Codespace-Workspace
    fi
    log_message "Sync complete."
}

# Automatic MEGA CMD update check (optional)
check_for_mega_update() {
    log_message "Checking for MEGA CMD updates..."
    local current_version
    current_version=$(mega-cmd --version | grep 'MEGA CMD version')

    local latest_version
    latest_version=$(curl -s https://mega.nz/linux/repo/xUbuntu_22.10/amd64/Packages | grep 'Version:' | awk '{print $2}' | head -1)

    if [ "$current_version" != "$latest_version" ]; then
        log_message "Updating MEGA CMD to latest version..."
        wget https://mega.nz/linux/repo/xUbuntu_22.10/amd64/megacmd-xUbuntu_22.10_amd64.deb -O /tmp/megacmd.deb
        sudo dpkg -i /tmp/megacmd.deb
        sudo apt-get -f install -y
        rm /tmp/megacmd.deb
        log_message "MEGA CMD updated to version $latest_version."
    else
        log_message "MEGA CMD is already up to date."
    fi
}

# Run setup, start, mount, sync, and create desktop shortcut
setup_mega
start_mega_server
mount_mega
sync_mega
create_desktop_shortcut
check_for_mega_update

log_message "MEGA setup complete. The desktop shortcut is ready to use."
