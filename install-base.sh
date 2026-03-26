#!/bin/bash
set -eu

# Install Homebrew if missing
if ! hash brew 2>/dev/null; then
  echo "Homebrew not found, installing..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Install all packages declaratively
brew bundle --file="$(dirname "$0")/Brewfile"

# safe-rm needs to shadow the system rm
ln -fs /opt/homebrew/opt/safe-rm/bin/safe-rm /opt/homebrew/bin/rm

# Stow dotfiles
mkdir -p $HOME/.ssh
stow --target $HOME/.ssh .ssh
stow --target $HOME git
stow --target $HOME zsh
stow --target $HOME vim
stow --target $HOME psql
mkdir -p $HOME/.config
stow --target $HOME/.config starship
stow --target $HOME/.config ghostty

echo "Finished successfully."

