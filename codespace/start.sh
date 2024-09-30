#!/bin/zsh

# Enable debugging
set -xv

# Function to handle cleanup on script exit
cleanup() {
    echo "Cleanup tasks..."
    exit 0
}

# Trap signals to clean up on exit
trap cleanup SIGINT SIGTERM EXIT

# Start Zsh shell interactively with proper environment setup
echo "Starting Zsh shell..."
exec zsh -l

# Disable debugging
set +xv
