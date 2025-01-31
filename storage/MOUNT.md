# Cloud Storage Mounting Setup: MEGA and pCloud

This document explains how to mount **MEGA** and **pCloud** cloud storage services on a Gitpod workspace and sync local folders. It includes setup instructions, mounting, and syncing procedures.

## Prerequisites

Before proceeding, make sure the following are set:

- **MEGA** account and credentials (`MEGA_EMAIL` and `MEGA_PASSWORD`)
- **pCloud** account configured and authenticated

## 1. MEGA Configuration and Mounting

### Step 1: Set Up MEGA

The script first checks if you are logged into MEGA. If not, it will prompt you to log in with your `MEGA_EMAIL` and `MEGA_PASSWORD`. If the login credentials are missing, it will display an error and stop execution.

- **MEGA Login**: The script uses `mega-login` to authenticate your MEGA account.
- **Fetching MEGA Nodes**: After logging in, the script waits until the MEGA nodes are fetched. If the fetching process takes too long (over 60 seconds), the script will terminate.

### Step 2: Mount MEGA

Once authenticated, the script will attempt to mount MEGA to `/workspace/mega` using `mega-mount`. It retries up to 5 times, with a 2-second interval between each attempt. If the mount operation fails, the script will display an error message and exit.

- **Mount Point**: `/workspace/mega`

If MEGA is already mounted, the script will skip the mounting process and display a message.

### Step 3: Sync with MEGA

The script uses `mega-sync` to sync a local folder (`/GitPod-Workspace`) with the MEGA folder (`/workspace/mega`). The sync operation is retried up to 3 times, with a 5-second interval between each attempt. If it fails after multiple retries, an error message will be displayed.

- **Sync Command**: `mega-sync /workspace/mega /GitPod-Workspace`

## 2. pCloud Configuration and Mounting

### Step 1: Set Up pCloud

The script checks if pCloud is configured by running the `pcloudcc -v` command. If pCloud is not configured, it will display an error message and stop execution.

- **pCloud Configuration**: Ensure that you have authenticated with pCloud before running the script.

### Step 2: Mount pCloud

The script will attempt to mount pCloud to `/workspace/pcloud` using `pcloudcc mount`. The mount operation is retried up to 5 times, with a 2-second interval between each attempt. If the mount fails, an error message will be displayed and the script will exit.

- **Mount Point**: `/workspace/pcloud`

If pCloud is already mounted, the script will skip the mounting process and display a message.

### Step 3: Sync with pCloud

The script uses `pcloudcc sync` to sync the local folder (`/GitPod-Workspace`) with the pCloud folder (`/workspace/pcloud`). The sync operation is retried up to 3 times, with a 5-second interval between each attempt. If it fails after multiple retries, an error message will be displayed.

- **Sync Command**: `pcloudcc sync /workspace/pcloud /GitPod-Workspace`

## 3. Desktop Shortcut Creation

The script creates a desktop shortcut for accessing MEGA storage. The shortcut is placed in the `/home/gitpod/Desktop` directory with the name `MEGA.desktop`. You can launch MEGA from the desktop shortcut directly.

### Shortcut Content:

```plaintext
[Desktop Entry]
Name=MEGA
Comment=Access your MEGA cloud storage
Exec=nautilus /workspace/mega
Icon=folder
Terminal=false
Type=Application
Categories=Utility;

## 4. Optional: MEGA CMD Update Check

The script also checks for updates to the **MEGA CMD** tool. If a newer version is available, it will automatically download and install the latest version.

- **Update Process**: The script checks the current MEGA CMD version, compares it to the latest version, and updates it if necessary.
- **Current Version Check**: The script uses the `mega-cmd --version` command to retrieve the current installed version.
- **Latest Version Fetch**: The script uses `curl` to fetch the latest available version from the MEGA repository.

### Update Command Flow:

1. **Get the current version** of MEGA CMD.
2. **Fetch the latest version** from the official MEGA repository.
3. **Download the latest package** and install it.
4. If the version doesn't match, it proceeds with the update and installs dependencies.
5. **Post-update**: After the installation, the script confirms that the tool has been updated to the latest version.

## 5. Error Handling and Logging

### Logging

Each major action and retry attempt in the script is logged using the `log_message` function. This allows you to track the process and diagnose issues. Logs include timestamps to help you identify the sequence of events.

- **Log Format**: Each log entry is prefixed with a timestamp in the format `YYYY-MM-DD HH:MM:SS`, followed by the action or error description.
  
### Error Handling

The script is designed to handle errors effectively. If any step fails (login, mount, sync), the script will terminate immediately and print an error message indicating the failure. If retries are involved (e.g., during mounting or syncing), the script will attempt the action up to a maximum number of times before giving up.

- **Error Messages**: Detailed error messages are displayed, describing the step where the failure occurred.
- **Retry Logic**: The script automatically retries failed actions, such as syncing and mounting, with a delay between each attempt.

## 6. Running the Script

### Setting Environment Variables

Before running the script, ensure that the required environment variables are set for **MEGA** and **pCloud**. For **MEGA**, you need to define `MEGA_EMAIL` and `MEGA_PASSWORD`. For **pCloud**, make sure that your pCloud credentials are configured.

- **Example for MEGA**:
  ```bash
  export MEGA_EMAIL="your_mega_email@example.com"
  export MEGA_PASSWORD="your_mega_password"

## 7. Running the Script

### Setting Environment Variables

Before running the script, ensure that the required environment variables are set for **MEGA** and **pCloud**. For **MEGA**, you need to define `MEGA_EMAIL` and `MEGA_PASSWORD`. For **pCloud**, make sure that your pCloud credentials are configured.

- **Example for MEGA**:
  ```bash
  export MEGA_EMAIL="your_mega_email@example.com"
  export MEGA_PASSWORD="your_mega_password"