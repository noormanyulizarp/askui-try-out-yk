#!/bin/bash

# Logging function
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Retry mechanism with max attempts
retry() {
    local -r command="$1"
    local -r max_attempts="$2"
    local -r sleep_time="$3"
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

# Function to ensure MEGA CMD server is running
start_mega_cmd_server() {
    if ! pgrep -x "mega-cmd-server" > /dev/null; then
        log_message "Starting mega-cmd-server..."
        mega-cmd-server &
        sleep 3  # Give the server some time to start
    fi
}

# Function to wait for MEGA nodes to be fetched
wait_for_nodes() {
    log_message "Waiting for MEGA to finish fetching nodes..."
    local max_wait=300  # Maximum wait time in seconds
    local elapsed=0
    local sleep_time=5  # Base sleep time

    while true; do
        # Check if nodes are accessible
        if mega-ls &> /dev/null; then
            log_message "MEGA nodes fetched successfully."
            return
        fi
        
        # Check for timeout
        if (( elapsed >= max_wait )); then
            log_message "Error: MEGA node fetching took too long."
            exit 1
        fi

        log_message "Still waiting... ($elapsed seconds elapsed)"
        sleep "$sleep_time"
        elapsed=$((elapsed + sleep_time))
        sleep_time=$((sleep_time + 2))  # Increase wait time if needed
    done
}

# Function to configure MEGA
configure_mega() {
    if ! mega-whoami &> /dev/null; then
        if [ -z "$MEGA_EMAIL" ] || [ -z "$MEGA_PASSWORD" ]; then
            log_message "Error: MEGA credentials not set. Please set MEGA_EMAIL and MEGA_PASSWORD."
            exit 1
        fi
        
        log_message "Configuring MEGA..."
        
        # Login to MEGA
        if output=$(mega-login "$MEGA_EMAIL" "$MEGA_PASSWORD"); then
            if [[ "$output" == *"Fetching nodes"* ]]; then
                log_message "Logged into MEGA successfully. Fetching nodes..."
                wait_for_nodes
            else
                log_message "Error: Failed to login to MEGA. Output: $output"
                exit 1
            fi
        else
            log_message "Error: Failed to login to MEGA."
            exit 1
        fi
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

# Function to sync local folder with MEGA folder
sync_mega() {
    log_message "Syncing local folder with MEGA..."
    
    local attempts=3
    for ((i = 1; i <= attempts; i++)); do
        if mega-sync /workspace/mega /GitPod-Workspace; then
            log_message "Sync complete."
            return
        else
            log_message "Error: Sync failed. Attempting to re-login..."
            configure_mega  # Re-login if sync fails
        fi
    done
    
    log_message "Error: Sync failed after $attempts attempts."
    exit 1
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

# Run the script
log_message "Starting MEGA configuration..."
start_mega_cmd_server  # Start MEGA CMD server
configure_mega          # Configure MEGA
mount_mega             # Mount MEGA
sync_mega              # Sync local folder with MEGA
create_desktop_shortcut # Create desktop shortcut

log_message "MEGA has been mounted and synced. The desktop shortcut is ready to use."
