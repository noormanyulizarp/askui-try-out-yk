FROM local/base_image:latest

# Install Oh My Zsh, plugins, and set theme
RUN if [ ! -d "$HOME/.oh-my-zsh" ]; then \
        # Install Oh My Zsh unattended
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended; \
    fi && \
    # Clone the zsh-syntax-highlighting plugin
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git \
    ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting && \
    # Clone the zsh-autosuggestions plugin
    git clone https://github.com/zsh-users/zsh-autosuggestions \
    ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions && \
    # Set theme to agnoster or fino (change here if needed)
    sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="agnoster"/' ~/.zshrc && \
    # Enable plugins: git, zsh-syntax-highlighting, and zsh-autosuggestions
    sed -i 's/plugins=(git)/plugins=(git zsh-syntax-highlighting zsh-autosuggestions)/' ~/.zshrc && \
    # Add custom aliases
    echo 'alias gst="git status"' >> ~/.zshrc && \
    echo 'alias ll="ls -la"' >> ~/.zshrc

# Start zsh shell
CMD ["/bin/zsh"]
