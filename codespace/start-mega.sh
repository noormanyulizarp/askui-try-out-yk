#!/bin/bash

# Start MEGA CMD server
mega-cmd-server &

# Wait for the server to be ready
for i in {1..50}; do
    if mega-whoami &> /dev/null; then
        echo "MEGA CMD server started successfully."
        break
    else
        echo "Waiting for MEGA CMD server to start... (Attempt $i)"
        sleep 1
    fi
done

# Mount MEGA storage
mega-mount /workspaces/${CODESPACE_REPO_NAME}/mega

# Sync MEGA folder
mega-sync /workspaces/${CODESPACE_REPO_NAME}/mega /Codespace-Workspace

echo "MEGA setup complete."
