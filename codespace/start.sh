#!/bin/zsh

# Enable debugging if DEBUG environment variable is set
if [[ $DEBUG == "true" ]]; then
    set -xv
fi

# Run the VNC setup script in the background
echo "Starting noVNC..."
./start-novnc.sh &  # Run noVNC in the background

# Mount cloud storage
echo "Mounting cloud storage..."
./mount-cloud-storage.sh

# Starting Zsh shell interactively with proper environment setup
echo "Starting Zsh shell..."
exec zsh -l

# Disable debugging if enabled
if [[ $DEBUG == "true" ]]; then
    set +xv
fi
