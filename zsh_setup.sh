#!/bin/bash

# Install Oh My Zsh and set Zsh as default shell
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Enable useful Zsh plugins
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

# Modify .zshrc to activate the plugins and change the theme
sed -i 's/plugins=(git)/plugins=(git zsh-syntax-highlighting zsh-autosuggestions)/' ~/.zshrc
sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="agnoster"/' ~/.zshrc

# Add git alias 'gst'
echo "alias gst='git status'" >> ~/.zshrc

# Ensure .zshrc is sourced correctly
echo "source ~/.zshrc" >> ~/.zshenv

# Reload Zsh settings and set it as the default shell
chsh -s $(which zsh)

# Confirm Zsh setup
echo "Zsh has been set up successfully."
