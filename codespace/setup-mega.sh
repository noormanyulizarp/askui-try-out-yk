#!/bin/bash

# Setup MEGA CMD
sudo apt-get update
sudo apt-get install -y libmediainfo0v5 libzen0v5
wget https://mega.nz/linux/repo/xUbuntu_22.04/amd64/megacmd-xUbuntu_22.04_amd64.deb
sudo dpkg -i megacmd-xUbuntu_22.04_amd64.deb
sudo apt-get -f install -y
rm megacmd-xUbuntu_22.04_amd64.deb

# Configure MEGA (using environment variables set in Codespace secrets)
if [ -n "$MEGA_EMAIL" ] && [ -n "$MEGA_PASSWORD" ]; then
    mega-login $MEGA_EMAIL $MEGA_PASSWORD
else
    echo "MEGA credentials not set. Please set MEGA_EMAIL and MEGA_PASSWORD in Codespace secrets."
fi

# Create mount point
mkdir -p /workspaces/${CODESPACE_REPO_NAME}/mega
