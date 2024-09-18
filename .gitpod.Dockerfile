# Base image from Gitpod's full VNC environment
FROM gitpod/workspace-full-vnc:latest

# Arguments for username, UID, and GID
ARG USERNAME=gitpod
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Install sudo, wget, and create a user with sudo privileges
USER root
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd -s /bin/bash --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && apt-get update \
    && apt-get install -y sudo wget \
    && echo "$USERNAME ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME \
    # Clean up
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# Switch to the gitpod user
USER $USERNAME

# Copy the Zsh setup script to /tmp
COPY zsh-in-docker.sh /tmp

# Install Zsh, Oh My Zsh, and additional plugins
RUN /tmp/zsh-in-docker.sh \
    -t https://github.com/denysdovhan/spaceship-prompt \
    -a 'SPACESHIP_PROMPT_ADD_NEWLINE="false"' \
    -a 'SPACESHIP_PROMPT_SEPARATE_LINE="false"' \
    -p git \
    -p https://github.com/zsh-users/zsh-autosuggestions \
    -p https://github.com/zsh-users/zsh-completions \
    -p https://github.com/zsh-users/zsh-history-substring-search \
    -p https://github.com/zsh-users/zsh-syntax-highlighting \
    -p 'history-substring-search' \
    -a 'bindkey "\$terminfo[kcuu1]" history-substring-search-up' \
    -a 'bindkey "\$terminfo[kcud1]" history-substring-search-down'

# Install MEGA CMD
RUN wget https://mega.nz/linux/repo/xUbuntu_22.10/amd64/megacmd-xUbuntu_22.10_amd64.deb -O /tmp/megacmd.deb \
 && sudo dpkg -i /tmp/megacmd.deb \
 && sudo apt-get -f install -y \
 && rm /tmp/megacmd.deb

# Set MEGA CMD server to start and Zsh to be the default shell
ENTRYPOINT ["mega-cmd-server"]
CMD ["/bin/zsh", "-l"]
