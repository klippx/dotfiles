# dotfiles

My dotfiles and install script in stow structure, inspired by https://github.com/fsrc/stowedots

## Installation

    git clone https://github.com/klippx/dotfiles.git
    cd dotfiles
    ./install-base.sh
    ./setup-osx.sh

## Copilot app worktree initialization

`install-base.sh` installs [init-worktree](worktree/.local/bin/init-worktree) and one
personal [`sessionStart` hook](worktree/.copilot/hooks/init-worktree.json) in
`~/.copilot/hooks/`. Verified in the Copilot app; it also applies to CLI sessions
using the same user hook directory. No Git or per-repository configuration.
To install separately, from this repo (requires Git 2.31+, jq, and Stow):

```bash
mkdir -p "$HOME/.local/bin" "$HOME/.copilot/hooks"
stow --target "$HOME" worktree
```

Copying happens on agent startup, including existing linked worktrees; behavior,
safety, and unsupported layouts are documented in the script.
Tests: `bash tests/init-worktree.test.sh` uses temporary Git repositories and dummy files.
Remove with `stow --target "$HOME" --delete worktree`; other user hooks and
previously copied files remain.

## Customize PS1

> cat nerdfont.txt | grep lambda | awk '{print $1}' | tr -d '\n' | pbcopy
