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
 && sudo rm -rf /var/lib/apt/lists/*

# Install MEGA CMD (latest version)
RUN wget https://mega.nz/linux/repo/xUbuntu_22.10/amd64/megacmd-xUbuntu_22.10_amd64.deb -O /tmp/megacmd.deb \
 && sudo dpkg -i /tmp/megacmd.deb \
 && sudo apt-get -f install -y \
 && rm /tmp/megacmd.deb \
 && mega-cmd --version

# Ensure /usr/local/bin is in PATH
ENV PATH="/usr/local/bin:${PATH}"

# Start MEGA CMD server on container startup
ENTRYPOINT ["megacmd-server"]
