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

# Function to configure MEGA
configure_mega() {
    if ! mega-whoami; then
        if [ -z "$MEGA_EMAIL" ] || [ -z "$MEGA_PASSWORD" ]; then
            log_message "Error: MEGA credentials not set. Please set MEGA_EMAIL and MEGA_PASSWORD."
            exit 1
        fi
        log_message "Configuring MEGA..."
        retry "mega-login \"$MEGA_EMAIL\" \"$MEGA_PASSWORD\"" 5 2 || exit 1
    else
        log_message "Already logged into MEGA."
    fi
}

# Function to mount MEGA
mount_mega() {
    if ! mountpoint -q /workspace/mega; then
        log_message "Mounting MEGA..."
        mkdir -p /workspace/mega
        if retry "mega-mount /workspace/mega" 5 2; then
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
    mkdir -p /home/gitpod/Desktop
    cat <<EOF > /home/gitpod/Desktop/MEGA.desktop
[Desktop Entry]
Name=MEGA
Comment=Access your MEGA cloud storage
Exec=nautilus /workspace/mega
Icon=folder
Terminal=false
Type=Application
Categories=Utility;
EOF
    chmod +x /home/gitpod/Desktop/MEGA.desktop
    log_message "Desktop shortcut for MEGA created."
}

# Function to sync local folder with MEGA folder
sync_mega() {
    log_message "Syncing local folder with MEGA..."
    if command -v mega-sync &> /dev/null; then
        mega-sync /workspace/mega /GitPod-Workspace
    else
        mega-cmd sync /workspace/mega /GitPod-Workspace
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
        dpkg -i /tmp/megacmd.deb
        apt-get -f install -y
        rm /tmp/megacmd.deb
        log_message "MEGA CMD updated to version $latest_version."
    else
        log_message "MEGA CMD is already up to date."
    fi
}

# Run MEGA configuration, mounting, and syncing
configure_mega
mount_mega
sync_mega

# Create the desktop shortcut
create_desktop_shortcut

# Check for MEGA CMD updates
check_for_mega_update

log_message "MEGA has been mounted and synced. The desktop shortcut is ready to use."
