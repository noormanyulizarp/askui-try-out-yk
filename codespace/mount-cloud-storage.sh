#!/bin/bash

# Logging function for consistent message format
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Check for superuser privileges
check_superuser() {
    if [[ "$EUID" -ne 0 ]]; then
        log_message "This script requires superuser privileges. Please run as root or use sudo."
        exit 1
    fi
}

# Retry mechanism with customizable attempts and sleep time
retry_command() {
    local command="$1"
    local max_attempts="$2"
    local sleep_time="$2"
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

# Install MEGA CMD if not already installed
install_mega_cmd() {
    log_message "Installing MEGA CMD..."
    
    OS_VERSION=$(lsb_release -rs) && \
    MEGA_REPO_URL="https://mega.nz/linux/repo/xUbuntu_${OS_VERSION}/amd64/" && \
    if wget --spider "${MEGA_REPO_URL}" 2>/dev/null; then \
        MEGA_CMD_PKG="megacmd-xUbuntu_${OS_VERSION}_amd64.deb" && \
        wget "${MEGA_REPO_URL}${MEGA_CMD_PKG}" -O /tmp/megacmd.deb && \
        dpkg -i /tmp/megacmd.deb || { \
            apt-get update && apt-get install -f -y && \
            dpkg -i /tmp/megacmd.deb; \
        } && \
        rm /tmp/megacmd.deb && \
        mega-cmd --version || { echo "MEGA CMD installation failed"; exit 1; }; \
    else \
        log_message "MEGA CMD is not available for this OS version: ${OS_VERSION}" && \
        log_message "Continuing without MEGA CMD installation"; \
    fi
}

# Start the MEGA CMD server and ensure it runs successfully
# start_mega_server() {
#     log_message "Starting MEGA CMD server..."
#     mega-cmd-server &

#     local max_wait=120
#     local elapsed=0

#     until mega-whoami &> /dev/null; do
#         if (( elapsed >= max_wait )); then
#             log_message "Error: MEGA CMD server failed to start within $max_wait seconds."
#             return 1
#         fi
#         log_message "Waiting for MEGA CMD server to start... ($elapsed seconds)"
#         sleep 2
#         elapsed=$((elapsed + 2))
#     done
#     log_message "MEGA CMD server started successfully."
# }

# Start the MEGA CMD server and ensure it runs successfully
start_mega_server() {
    log_message "Starting MEGA CMD server..."
    
    # Check if the server is already running
    if pgrep -x "mega-cmd-server" > /dev/null; then
        log_message "MEGA CMD server is already running."
        return 0
    fi

    mega-cmd-server &

    local max_attempts=3
    local attempt=1
    local max_wait=4  # 4 seconds per attempt

    until mega-whoami &> /dev/null; do
        if (( attempt >= max_attempts )); then
            log_message "Error: MEGA CMD server failed to start after $((attempt - 1)) attempts."
            return 1
        fi
        log_message "Waiting for MEGA CMD server to start... (Attempt $attempt/$max_attempts)"
        ((attempt++))
        sleep "$max_wait"
    done

    log_message "MEGA CMD server started successfully."
}


# Function to log MEGA credentials
log_mega_credentials() {
    log_message "Logging MEGA credentials for debugging."
    
    # Ensure these variables are set (adapt as necessary for your environment)
    local MEGA_EMAIL="${MEGA_EMAIL:-not_set}"
    local MEGA_PASSWORD="${MEGA_PASSWORD:-not_set}"
    
    # Log email and password (adjust if required for security, ideally log just email)
    log_message "MEGA Email: $MEGA_EMAIL"
    log_message "MEGA Password: $MEGA_PASSWORD"
}

# Mount the MEGA drive at a specified path
# mount_mega_drive() {
#     local mount_path="/workspaces/${CODESPACE_REPO_NAME}/mega"
#     if ! mountpoint -q "$mount_path"; then
#         log_message "Mounting MEGA to $mount_path..."
#         mkdir -p "$mount_path"

#         local max_wait=120
#         local elapsed=0

#         until mega-mount "$mount_path" &> /dev/null; do
#             if (( elapsed >= max_wait )); then
#                 log_message "Error: Failed to mount MEGA within $max_wait seconds."
#                 exit 1
#             fi
#             log_message "Retrying MEGA mount... ($elapsed seconds)"
#             sleep 5
#             elapsed=$((elapsed + 5))
#         done
#         log_message "MEGA mounted successfully."
#     else
#         log_message "MEGA is already mounted at $mount_path."
#     fi
# }

# Mount MEGA CMD to a specified directory
mount_mega_storage() {
    local mount_point="/workspaces/mega"
    local max_attempts=6  # 6 attempts with 5 seconds each = 30 seconds total
    local attempt=0
    local wait_time=5      # 5 seconds wait time between attempts

    log_message "Mounting MEGA to ${mount_point}..."

    # Create the mount point if it doesn't exist
    mkdir -p "${mount_point}"

    until mega-mount "${mount_point}" &> /dev/null; do
        if (( attempt >= max_attempts )); then
            log_message "Error: Failed to mount MEGA after $attempt attempts."
            return 1
        fi
        log_message "Retrying MEGA mount... ($((attempt * wait_time)) seconds)"
        ((attempt++))
        sleep "$wait_time"
    done

    log_message "MEGA successfully mounted to ${mount_point}."
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
    check_superuser
    retry_command check_mega_installed 3 10 || install_mega_cmd
    retry_command start_mega_server 3 10
    retry_command mount_mega_drive 3 10
    sync_mega
    create_mega_shortcut
}

main "$@"
