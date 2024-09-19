#!/bin/bash

# Function to handle cleanup on script exit
cleanup() {
    echo "Shutting down MEGA CMD server..."
    mega-quit
    echo "MEGA CMD server stopped."
    exit 0
}

# Trap signals to clean up MEGA CMD server on exit
trap cleanup SIGINT SIGTERM EXIT

# Check if mount-cloud-storage.sh exists
if [ -f "/home/vscode/mount-cloud-storage.sh" ]; then
    echo "Running mount-cloud-storage.sh..."
    /home/vscode/mount-cloud-storage.sh
else
    echo "mount-cloud-storage.sh not found, skipping MEGA setup."
fi

# Start the VNC server
if [ -f "/home/vscode/start-vnc.sh" ]; then
    echo "Starting VNC server..."
    /home/vscode/start-vnc.sh
else
    echo "start-vnc.sh not found, skipping VNC server startup."
fi

# Start Zsh shell interactively, ensure graceful exit
echo "Starting Zsh shell..."
exec /bin/zsh -l
