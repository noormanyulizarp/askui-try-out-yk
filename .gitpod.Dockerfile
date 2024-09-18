FROM gitpod/workspace-full-vnc:latest

USER gitpod

# Install necessary packages and dependencies
RUN sudo apt-get update \
 && sudo DEBIAN_FRONTEND=noninteractive apt-get install -yq \
   libfuse2 \
   fuse \
   libatk-bridge2.0-0 \
   libcups2 \
   libdrm2 \
   libgtk-3-0 \
   libgbm1 \
   gnome-calculator \
   geany \
   libc-ares2 \
   libmediainfo0v5 \
   libzen0v5 \
   nautilus \
   dbus-x11 \
 && sudo rm -rf /var/lib/apt/lists/*

# Install MEGA CMD (latest version)
RUN wget https://mega.nz/linux/repo/xUbuntu_22.10/amd64/megacmd-xUbuntu_22.10_amd64.deb -O /tmp/megacmd.deb \
 && sudo dpkg -i /tmp/megacmd.deb \
 && sudo apt-get -f install -y \
 && rm /tmp/megacmd.deb \
 && mega-cmd --version

# Install dependencies for Zsh setup
RUN sudo apt-get update \
 && sudo DEBIAN_FRONTEND=noninteractive apt-get install -yq \
   wget \
   git \
   zsh \
 && sudo rm -rf /var/lib/apt/lists/*

# Ensure /usr/local/bin is in PATH
ENV PATH="/usr/local/bin:${PATH}"

# Copy Zsh setup script and configuration files
COPY --chown=gitpod:gitpod ./zsh_setup.sh /home/gitpod/zsh_setup.sh
COPY --chown=gitpod:gitpod ./config/.zshrc /home/gitpod/.zshrc
COPY --chown=gitpod:gitpod ./config/.p10k.zsh /home/gitpod/.p10k.zsh
COPY --chown=gitpod:gitpod ./config/aliases.zsh /home/gitpod/.oh-my-zsh/custom/

# Install Oh My Zsh and configure it
RUN /home/gitpod/zsh_setup.sh

# Start MEGA CMD server on container startup
ENTRYPOINT ["mega-cmd-server"]
