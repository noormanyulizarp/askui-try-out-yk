#!/bin/zsh

# Enable debugging if DEBUG environment variable is set
if [[ $DEBUG == "true" ]]; then
    set -xv
fi

# Function to handle cleanup on script exit
cleanup() {
    echo "Performing cleanup tasks..."
    # Add any cleanup tasks here, e.g., stopping services, killing processes, etc.
    pkill -f websockify  # Example: Stopping noVNC if it's running
    pkill -f Xvfb        # Example: Stopping VNC server if it's running
    echo "Cleanup complete."
    exit 0
}

# Trap signals to clean up on exit
trap cleanup SIGINT SIGTERM EXIT

# Start any services needed before Zsh starts
echo "Starting services..."
# Add service start commands here if necessary, e.g., starting VNC, noVNC

# Start Zsh shell interactively with proper environment setup
echo "Starting Zsh shell..."
exec zsh -l

# Disable debugging if enabled
if [[ $DEBUG == "true" ]]; then
    set +xv
fi
