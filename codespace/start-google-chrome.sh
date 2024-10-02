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

# Function to create a desktop entry for Google Chrome
create_desktop_entry() {
    local desktop_entry_path="$HOME/.local/share/applications/google-chrome.desktop"
    if [ ! -f "$desktop_entry_path" ]; then
        cat <<EOF > "$desktop_entry_path"
[Desktop Entry]
Version=1.0
Name=Google Chrome
Exec=/usr/bin/google-chrome --no-sandbox --disable-dev-shm-usage --disable-gpu
Icon=/usr/share/icons/hicolor/48x48/apps/google-chrome.png
Type=Application
Categories=Network;WebBrowser;
EOF
        echo "Desktop entry for Google Chrome created."
    else
        echo "Desktop entry for Google Chrome already exists."
    fi
}

# Function to start or restart Xvfb
start_xvfb() {
    if pgrep -f "Xvfb :99" > /dev/null; then
        echo "Xvfb is already running for display :99. Stopping it..."
        kill $(pgrep -f "Xvfb :99")
        sleep 1
    fi
    
    echo "Starting Xvfb..."
    Xvfb :99 -screen 0 1920x1080x24 &
    export DISPLAY=:99
    sleep 2  # Wait for Xvfb to start
}

# Function to start Google Chrome
start_google_chrome() {
    if pgrep -f "google-chrome" > /dev/null; then
        echo "Google Chrome is already running. Stopping it..."
        kill $(pgrep -f "google-chrome")
        sleep 1
    fi
    
    echo "Launching Google Chrome..."
    google-chrome --no-sandbox --disable-dev-shm-usage --disable-gpu &

    # Check if Google Chrome started successfully
    sleep 2  # Give it a moment to start
    if ! pgrep -f "google-chrome" > /dev/null; then
        echo "Failed to start Google Chrome. Check for errors."
    else
        echo "Google Chrome is now running."
    fi
}

# Main logic
if ! is_chrome_installed; then
    install_google_chrome
fi

# Create desktop entry for Google Chrome
create_desktop_entry

# Start Xvfb
start_xvfb

# Launch Google Chrome
start_google_chrome
