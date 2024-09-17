#!/bin/bash

# Function to configure MEGA
configure_mega() {
    if ! mega-whoami; then
        echo "Configuring MEGA..."
        read -p "Enter your MEGA email: " mega_email
        read -s -p "Enter your MEGA password: " mega_password
        mega-login $mega_email $mega_password
    fi
}

# Function to mount MEGA
mount_mega() {
    if ! mountpoint -q /workspace/mega; then
        echo "Mounting MEGA..."
        mkdir -p /workspace/mega
        mega-mount /workspace/mega
    fi
}

# Run MEGA configuration and mounting
configure_mega
mount_mega

echo "MEGA has been mounted and is ready to use."
