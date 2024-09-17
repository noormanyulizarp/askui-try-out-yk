#!/bin/bash

# Function to configure MEGA
configure_mega() {
    if ! mega-whoami; then
        if [ -z "$MEGA_EMAIL" ] || [ -z "$MEGA_PASSWORD" ]; then
            echo "MEGA credentials not set. Please set MEGA_EMAIL and MEGA_PASSWORD."
            exit 1
        fi
        echo "Configuring MEGA..."
        mega-login "$MEGA_EMAIL" "$MEGA_PASSWORD"
    else
        echo "Already logged into MEGA."
    fi
}

# Function to mount MEGA
mount_mega() {
    if ! mountpoint -q /workspace/mega; then
        echo "Mounting MEGA..."
        mkdir -p /workspace/mega
        if mega-mount /workspace/mega; then
            echo "MEGA mounted successfully."
        else
            echo "Failed to mount MEGA."
            exit 1
        fi
    else
        echo "MEGA is already mounted."
    fi
}

# Function to create a desktop shortcut for MEGA
create_desktop_shortcut() {
    echo "Creating desktop shortcut for MEGA..."
    
    # Ensure the Desktop directory exists
    mkdir -p /home/gitpod/Desktop

    # Create .desktop file
    cat <<EOF > /home/gitpod/Desktop/MEGA.desktop
[Desktop Entry]
Name=MEGA
Comment=Access your MEGA cloud storage
Exec=nautilus /workspace/mega
Icon=folder
Terminal=false
Type=Application
Categories=Utility;
EOF

    # Make it executable
    chmod +x /home/gitpod/Desktop/MEGA.desktop
}

# Run MEGA configuration and mounting
configure_mega
mount_mega

# Create the desktop shortcut
create_desktop_shortcut

echo "MEGA has been mounted, and the desktop shortcut is ready to use."
