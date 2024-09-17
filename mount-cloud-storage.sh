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
