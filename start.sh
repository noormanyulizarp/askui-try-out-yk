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

# Start Zsh shell interactively, ensure graceful exit
echo "Starting Zsh shell..."
exec /bin/zsh -l
