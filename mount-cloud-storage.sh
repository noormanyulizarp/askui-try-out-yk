#!/bin/bash

# Function to configure MEGA
configure_mega() {
    if ! mega-whoami; then
        echo "Configuring MEGA..."
        # Use environment variables for MEGA credentials
        mega_email="${MEGA_EMAIL}"
        mega_password="${MEGA_PASSWORD}"
        mega-login "$mega_email" "$mega_password"
    else
        echo "Already logged into MEGA."
    fi
}

# Function to mount MEGA
mount_mega() {
    if ! mountpoint -q /workspace/mega; then
        echo "Mounting MEGA..."
        mkdir -p /workspace/mega
        mega-mount /workspace/mega
    else
        echo "MEGA is already mounted."
    fi
}

# Function to create a desktop shortcut for MEGA
create_desktop_shortcut() {
    echo "Creating desktop shortcut for MEGA..."

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
