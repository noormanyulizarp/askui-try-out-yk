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

# Run the mount-cloud-storage.sh script
echo "Running mount-cloud-storage.sh..."
/home/vscode/mount-cloud-storage.sh

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
