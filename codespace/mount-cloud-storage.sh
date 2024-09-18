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
            log_message "Error: MEGA credentials not set. Please set MEGA_EMAIL and MEGA_PASSWORD in Codespace secrets."
            exit 1
        fi
        log_message "Configuring MEGA..."
        if ! mega-login "$MEGA_EMAIL" "$MEGA_PASSWORD"; then
            log_message "Error: Failed to login to MEGA."
            exit 1
        fi
        log_message "Logged into MEGA successfully."
    else
        log_message "Already logged into MEGA."
    fi
}

# Function to mount MEGA
mount_mega() {
    if ! mountpoint -q /workspaces/your-repo-name/mega; then
        log_message "Mounting MEGA..."
        mkdir -p /workspaces/your-repo-name/mega
        if retry "mega-mount /workspaces/your-repo-name/mega" 5 2; then
            log_message "MEGA mounted successfully."
        else
            log_message "Error: Failed to mount MEGA."
            exit 1
        fi
    else
        log_message "MEGA is already mounted."
    fi
}

# Function to sync local folder with MEGA folder
sync_mega() {
    log_message "Syncing local folder with MEGA..."
    if command -v mega-sync &> /dev/null; then
        mega-sync /workspaces/your-repo-name/mega /Codespace-Workspace
    else
        mega-cmd sync /workspaces/your-repo-name/mega /Codespace-Workspace
    fi
    log_message "Sync complete."
}

# Run MEGA configuration, mounting, and syncing
configure_mega
mount_mega
sync_mega

log_message "MEGA has been mounted and synced."