#!/bin/bash

# Function to check if Google Chrome is installed
is_chrome_installed() {
    command -v google-chrome >/dev/null 2>&1
}

# Function to install Google Chrome
install_google_chrome() {
    echo "Google Chrome is not installed. Installing..."
    sudo apt-get update && sudo apt-get install -y wget gnupg2 && \
    wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo apt-key add - && \
    echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list && \
    sudo apt-get update && sudo apt-get install -y google-chrome-stable
}

# Main logic
if ! is_chrome_installed; then
    install_google_chrome
fi

# Launch Google Chrome with specified flags
google-chrome --no-sandbox --disable-dev-shm-usage &

# Create a desktop entry if it doesn't exist
if [ ! -f ~/.local/share/applications/google-chrome.desktop ]; then
    cat <<EOF > ~/.local/share/applications/google-chrome.desktop
[Desktop Entry]
Version=1.0
Name=Google Chrome
Exec=/usr/bin/google-chrome --no-sandbox --disable-dev-shm-usage
Icon=/usr/share/icons/hicolor/48x48/apps/google-chrome.png
Type=Application
Categories=Network;WebBrowser;
EOF
    echo "Desktop entry for Google Chrome created."
fi

echo "Google Chrome is now running."
