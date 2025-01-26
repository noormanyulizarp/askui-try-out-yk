#!/bin/bash

# Function to check if Node.js and npm are installed
check_node_npm_installed() {
  if ! command -v node &> /dev/null; then
    echo "Node.js is not installed. Please install Node.js and try again."
    exit 1
  fi

  if ! command -v npm &> /dev/null; then
    echo "npm is not installed. Please install npm and try again."
    exit 1
  fi

  echo "Node.js and npm are installed. Proceeding..."
}

# Function to handle CAPTCHA detection
handle_captcha() {
  echo "CAPTCHA detected! Please manually resolve the CAPTCHA in the Chrome window."
  echo "Once resolved, the script will continue automatically."
  read -p "Press Enter to continue after resolving CAPTCHA..."
}

# Function to set up Puppeteer and Chrome login
setup_puppeteer_and_login() {
  echo "Installing Puppeteer and dependencies..."
  npm install puppeteer

  # Delete the existing chrome-login.js file (if it exists)
  if [ -f "chrome-login.js" ]; then
    echo "Deleting existing chrome-login.js file..."
    rm chrome-login.js
  fi

  echo "Creating Puppeteer script..."
  cat <<EOL > chrome-login.js
const puppeteer = require('puppeteer');

(async () => {
  const browser = await puppeteer.launch({
    headless: false,
    args: ['--no-sandbox', '--disable-setuid-sandbox'],
    userDataDir: '/home/gitpod/.config/google-chrome'
  });
  const page = await browser.newPage();
  await page.goto('https://accounts.google.com');

  // Check for CAPTCHA
  const captchaSelector = '#captcha-form';
  if (await page.\$(captchaSelector) !== null) {
    console.log('CAPTCHA detected! Please manually resolve the CAPTCHA in the browser window.');
    await page.waitForNavigation({ timeout: 0 }); // Wait indefinitely for user to resolve CAPTCHA
  }

  console.log('Please log in to your Google account in the browser window...');
  await page.waitForNavigation({ timeout: 0 }); // Wait indefinitely for login

  await browser.close();
})();
EOL

  echo "Running Puppeteer script to open Chrome..."
  node chrome-login.js
}

# Function to configure Gitpod persistence
configure_persistence() {
  local gitpod_config_file="/workspace/.gitpod-config/.gitpod.yml"
  local chrome_data_dir="/home/gitpod/.config/google-chrome"

  if [ -f "$gitpod_config_file" ] && grep -q "$chrome_data_dir" "$gitpod_config_file"; then
    echo "Chrome user data persistence is already configured. Continuing..."
  else
    echo "Configuring Gitpod to persist Chrome user data across workspace restarts..."
    mkdir -p /workspace/.gitpod-config
    echo "persist:
  - $chrome_data_dir" >> "$gitpod_config_file"
    echo "Persistence configured! Chrome user data will be saved for future workspace restarts."
  fi
}

# Main script execution
echo "Starting Chrome login setup..."

# Step 1: Check if Node.js and npm are installed
check_node_npm_installed

# Step 2: Set up Puppeteer and automate Chrome login
setup_puppeteer_and_login

# Step 3: Configure Gitpod persistence for Chrome user data
configure_persistence

echo "Setup complete! You can now use Chrome with your Google account in Gitpod."