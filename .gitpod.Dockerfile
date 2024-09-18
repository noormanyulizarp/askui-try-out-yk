FROM gitpod/workspace-full-vnc:latest

USER root

# Install necessary packages and dependencies
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -yq \
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
   wget \
   git \
   zsh \
 && rm -rf /var/lib/apt/lists/*

# Install MEGA CMD (latest version)
RUN wget https://mega.nz/linux/repo/xUbuntu_22.10/amd64/megacmd-xUbuntu_22.10_amd64.deb -O /tmp/megacmd.deb \
 && dpkg -i /tmp/megacmd.deb \
 && apt-get -f install -y \
 && rm /tmp/megacmd.deb \
 && mega-cmd --version

# Ensure /usr/local/bin is in PATH
ENV PATH="/usr/local/bin:${PATH}"

# Switch to gitpod user for Oh My Zsh installation
USER gitpod

# Install Oh My Zsh
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Install Zsh plugins
RUN git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting \
 && git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

# Configure Zsh
RUN sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="agnoster"/' ~/.zshrc \
 && sed -i 's/plugins=(git)/plugins=(git zsh-syntax-highlighting zsh-autosuggestions)/' ~/.zshrc \
 && echo 'alias gst="git status"' >> ~/.zshrc

# Create .p10k.zsh
RUN echo 'POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(user dir vcs)' > ~/.p10k.zsh \
 && echo 'POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(status root_indicator background_jobs)' >> ~/.p10k.zsh

# Switch back to root for final steps
USER root

# Add start.sh
COPY start.sh /home/gitpod/start.sh
RUN chmod +x /home/gitpod/start.sh

# Ensure MEGA CMD can run as gitpod user
RUN chown -R gitpod:gitpod /home/gitpod/.megaCmd

# Switch back to gitpod user
USER gitpod

ENTRYPOINT ["/home/gitpod/start.sh"]