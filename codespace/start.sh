#!/bin/bash

# Function to start MEGA CMD server with health check
start_mega_cmd_server() {
    echo "Starting MEGA CMD server..."
    mega-cmd-server &
    
    # Wait for the server to be ready with a health check
    for i in {1..50}; do
        if mega-whoami &> /dev/null; then
            echo "MEGA CMD server started successfully."
            return 0
        else
            echo "Waiting for MEGA CMD server to start... (Attempt $i)"
            sleep 1
        fi
    done
    
    # If the server doesn't start after 50 attempts, log an error and exit
    echo "Error: MEGA CMD server failed to start after multiple attempts."
    exit 1
}

# Function to handle cleanup on script exit
cleanup() {
    echo "Shutting down MEGA CMD server..."
    mega-quit
    echo "MEGA CMD server stopped."
    exit 0
}

# Trap signals to clean up MEGA CMD server on exit
trap cleanup SIGINT SIGTERM EXIT

# Start MEGA CMD server and perform health check
start_mega_cmd_server

# Run the setup script for MEGA if needed
if [ -f "/home/vscode/setup-mega.sh" ]; then
    echo "Running setup-mega.sh..."
    /home/vscode/setup-mega.sh
else
    echo "setup-mega.sh not found, skipping setup."
fi

# Mount MEGA storage if the script exists
if [ -f "/workspaces/your-repo-name/codespace/mount-cloud-storage.sh" ]; then
    echo "Mounting MEGA storage..."
    /workspaces/your-repo-name/codespace/mount-cloud-storage.sh
else
    echo "mount-cloud-storage.sh not found, skipping cloud storage mounting."
fi

# Start the VNC server if the script exists
if [ -f "/home/vscode/start-vnc.sh" ]; then
    echo "Starting VNC server..."
    /home/vscode/start-vnc.sh
else
    echo "start-vnc.sh not found, skipping VNC server startup."
fi

# Start Zsh shell interactively, ensure graceful exit
echo "Starting Zsh shell..."
exec /bin/zsh -l
