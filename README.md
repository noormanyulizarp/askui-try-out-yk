# Custom Gitpod Workspace with MEGA CMD and Zsh

This repository provides a custom Gitpod workspace setup designed to streamline cloud storage integration (via MEGA CMD) and enhance the development experience with a Zsh shell configured with Oh My Zsh.

## Key Features

- **Optimized Docker Image**: Based on Gitpod's `workspace-full-vnc` image with additional tools and customizations.
- **MEGA CMD Integration**: Interact with your MEGA cloud storage directly from the terminal.
- **Oh My Zsh**: Customized Zsh shell with useful plugins and themes pre-installed.
- **Additional Development Tools**: Includes various utilities like Geany, GNOME Calculator, and Nautilus file manager for enhanced productivity.

## What’s Included

- **MEGA CMD**: Command-line tools to manage MEGA cloud storage.
- **Zsh with Oh My Zsh**: Pre-configured Zsh shell for a better terminal experience.
- **Git**: Version control with additional useful aliases.
- **GNOME Utilities**: Includes GNOME Calculator and the Nautilus file manager.
- **Geany**: Lightweight text editor.
- **System Libraries**: Essential libraries like `libfuse2`, `fuse`, and other dependencies.

## Zsh Configuration

- **Theme**: `agnoster`, a sleek and minimalist theme.
- **Plugins**: Includes `git`, `zsh-syntax-highlighting`, and `zsh-autosuggestions` for improved productivity.
- **Custom Aliases**: Pre-configured Git aliases to simplify your workflow (`gst` for `git status`, etc.).
- **Custom Prompt**: Powered by `Powerlevel9k` for enhanced visual cues and information.

## Usage Instructions

1. **Create a Gitpod Workspace**:
   - Start by creating a new Gitpod workspace using this repository.

2. **Workspace Setup**:
   - Upon startup, the workspace will automatically configure itself.
   - MEGA CMD server will run in the background.
   - You’ll be dropped into a Zsh shell with the custom Oh My Zsh setup.

3. **Using MEGA CMD**:
   - Log in to your MEGA account using the command:
     ```bash
     mega-login your@email.com
     ```
   - Browse your MEGA cloud:
     ```bash
     mega-ls
     ```
   - Upload files to your MEGA storage:
     ```bash
     mega-put localfile.txt
     ```

   For more detailed usage, refer to the [MEGA CMD documentation](https://github.com/meganz/MEGAcmd/blob/master/README.md).

## Advanced Features

### Automatic MEGA CMD Configuration and Mounting

The setup includes a script (`mount-cloud-storage.sh`) that:
- **Automatically logs into MEGA CMD** using credentials stored as environment variables.
- **Mounts your MEGA cloud storage** to the `/workspace/mega` directory.
- **Syncs** the local workspace directory with your MEGA cloud folder (`GitPod-Workspace`).
- **Creates a desktop shortcut** to easily access your MEGA storage through Nautilus.

### MEGA CMD Auto-Update (Optional)

A built-in feature checks for newer versions of MEGA CMD during the setup process and updates it automatically if available.

## Git Aliases

Here are some pre-configured Git aliases included for convenience:

- `gst`: `git status`
- `gco`: `git checkout`
- `ga`: `git add`
- `gc`: `git commit`
- `gp`: `git push`

These aliases aim to streamline your Git workflow and reduce the amount of typing needed for common commands.

## Customization Options

You can further tailor the workspace to your needs:

1. **Dockerfile Customization**:
   - Modify the `.gitpod.Dockerfile` to add or remove software or tweak installation steps.

2. **Startup Behavior**:
   - Adjust the `start.sh` script to change what happens when the workspace is initialized. For example, you could add custom services or extend the MEGA CMD setup.

3. **Zsh Customization**:
   - Modify the `zsh_setup.sh` script or edit `.zshrc` directly to add additional Zsh plugins, change themes, or customize aliases.

## Error Handling & Troubleshooting

The workspace includes improved error handling and logging. If you encounter issues, here are some steps to resolve them:

1. **MEGA CMD Server**:
   - Ensure that the MEGA CMD server is running by checking the logs:
     ```bash
     pgrep mega-cmd-server
     ```

2. **Workspace Logs**:
   - Check the Gitpod logs for any errors that occurred during startup.

3. **Common Issues**:
   - If the MEGA mount fails, check the network connection or retry using the provided retry mechanism.

## Contributing

We welcome contributions! If you have suggestions or improvements, feel free to:

- **Fork** the repository.
- **Submit a pull request** with your changes.

## License

This project is licensed under the [MIT License](LICENSE).
