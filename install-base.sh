#!/bin/bash
set -eu

install_command() {
  if hash pacman 2>/dev/null; then
    sudo pacman -S $1
  elif hash apt-get 2>/dev/null; then
    sudo apt-get install $1
  elif hash brew 2>/dev/null; then
    brew install $1
  fi
}

ensure_command() {
  if hash $1 2>/dev/null; then
    echo "$1 found, skipping..."
  else
    echo "$1 not found, installing.."
    install_command $1
  fi
}

install_oh-my-zsh() {
  if [ -e ~/.oh-my-zsh ]
    then
      echo "Oh my zsh already installed, skipping..."
    else
      echo "Oh my zsh not found, installing..."
      curl -L https://github.com/robbyrussell/oh-my-zsh/raw/master/tools/install.sh | sh
      rm -f ~/.zshrc
  fi
}

ensure_command stow
ensure_command git
ensure_command zsh
ensure_command vim
ensure_command fzf
ensure_command direnv
ensure_command zoxide
ensure_command safe-rm
ln -fs /opt/homebrew/opt/safe-rm/bin/safe-rm /opt/homebrew/bin/rm
ensure_command diff-so-fancy
ensure_command curl
ensure_command fd
ensure_command bat
ensure_command prettyping
ensure_command ncdu
ensure_command starship
ensure_command gh

install_oh-my-zsh

mkdir -p $HOME/.ssh
stow --target $HOME/.ssh .ssh
stow --target $HOME git
stow --target $HOME zsh
stow --target $HOME vim
stow --target $HOME psql
stow --target $HOME asdf
mkdir -p $HOME/.config
stow --target $HOME/.config starship

# Cannot detect these as they are not "commands"
brew install git-interactive-rebase-tool
brew install font-hack-nerd-font
brew install font-iosevka-ss12
brew install font-monaspace
brew install font-droid-sans-mono-nerd-font


echo "Finished successfully."
