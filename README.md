# Custom Gitpod Workspace with MEGA CMD and Zsh

This repository contains a custom Gitpod workspace configuration that includes MEGA CMD, Oh My Zsh, and various useful tools for development.

## Features

- Based on Gitpod's `workspace-full-vnc` image
- MEGA CMD for interacting with MEGA cloud storage
- Zsh shell with Oh My Zsh framework
- Custom Zsh theme (agnoster) and plugins
- Various development tools and utilities

## Included Software

- MEGA CMD
- Zsh with Oh My Zsh
- Git
- Various system libraries and tools (libfuse2, fuse, etc.)
- GNOME Calculator
- Geany text editor
- Nautilus file manager

## Zsh Configuration

- Theme: agnoster
- Plugins: git, zsh-syntax-highlighting, zsh-autosuggestions
- Custom aliases (e.g., `gst` for `git status`)
- Powerlevel9k prompt configuration

## Usage

1. Create a new Gitpod workspace using this repository.
2. The workspace will automatically set up with the custom environment.
3. MEGA CMD server will start automatically in the background.
4. You'll be dropped into a Zsh shell with the custom configuration.

### MEGA CMD

To use MEGA CMD, simply type `mega-` and press Tab to see available commands. For example:

```
mega-login your@email.com
mega-ls
mega-put localfile.txt
```

Refer to the [MEGA CMD documentation](https://github.com/meganz/MEGAcmd/blob/master/README.md) for more information.

### Git Aliases

Some useful Git aliases are pre-configured:

- `gst`: git status
- `gco`: git checkout
- `ga`: git add
- `gc`: git commit
- `gp`: git push

## Customization

To further customize the workspace:

1. Modify the `.gitpod.Dockerfile` to add or remove software.
2. Edit the `start.sh` script to change startup behavior.
3. Adjust Zsh configuration by modifying the relevant RUN commands in the Dockerfile.

## Troubleshooting

If you encounter any issues:

1. Ensure your Gitpod account has the necessary permissions.
2. Check the Gitpod logs for any error messages during startup.
3. Verify that the MEGA CMD server is running with `pgrep mega-cmd-server`.

For persistent issues, please open an issue in this repository.

## Contributing

Contributions to improve this workspace configuration are welcome. Please submit a pull request with your proposed changes.

## License

This project is open-source and available under the [MIT License](LICENSE).

