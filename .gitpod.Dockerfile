FROM gitpod/workspace-full-vnc:latest

USER gitpod

# Install Cypress dependencies and other necessary packages
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
 && sudo rm -rf /var/lib/apt/lists/*

# Install pCloud console client
RUN wget https://github.com/pcloud/console-client/releases/download/v1.7.1/pcloud_linux_amd64 -O /tmp/pcloud \
 && sudo mv /tmp/pcloud /usr/local/bin/pcloud \
 && sudo chmod +x /usr/local/bin/pcloud \
 && /usr/local/bin/pcloud --version

# Install MEGA CMD
RUN wget https://mega.nz/linux/repo/xUbuntu_20.04/amd64/megacmd-xUbuntu_20.04_amd64.deb -O /tmp/megacmd.deb \
 && sudo dpkg -i /tmp/megacmd.deb \
 && sudo apt-get -f install -y \
 && rm /tmp/megacmd.deb \
 && mega-cmd --version

# Ensure /usr/local/bin is in PATH
ENV PATH="/usr/local/bin:${PATH}"
