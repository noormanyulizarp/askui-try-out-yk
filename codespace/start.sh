#!/bin/zsh

# Enable debugging if DEBUG environment variable is set
if [[ $DEBUG == "true" ]]; then
    set -xv
fi

# Starting Zsh shell interactively with proper environment setup
echo "Starting Zsh shell..."
exec zsh -l

# Disable debugging if enabled
if [[ $DEBUG == "true" ]]; then
    set +xv
fi
