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

# Run mount-cloud-storage.sh if it exists
if [ -f "/home/vscode/mount-cloud-storage.sh" ]; then
    echo "Running mount-cloud-storage.sh..."
    /home/vscode/mount-cloud-storage.sh
else
    echo "mount-cloud-storage.sh not found, skipping MEGA setup."
fi

# Start the VNC server if start-vnc.sh exists, with error handling
if [ -f "/home/vscode/start-vnc.sh" ]; then
    echo "Starting VNC server..."
    if /home/vscode/start-vnc.sh; then
        echo "VNC server started successfully."
    else
        echo "Failed to start VNC server. You can try starting it manually later."
    fi
else
    echo "start-vnc.sh not found, skipping VNC server startup."
fi

# Start Zsh shell interactively with proper environment setup
echo "Starting Zsh shell..."
exec /bin/zsh -c "source ~/.zshrc && exec zsh -l"
