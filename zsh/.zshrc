### ZSH History
#
HISTSIZE=50000
SAVEHIST=50000
HISTFILE=~/.zsh_history
setopt HIST_IGNORE_DUPS HIST_IGNORE_SPACE SHARE_HISTORY

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export EDITOR='vim'
fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# ssh
# export SSH_KEY_PATH="~/.ssh/dsa_id"

### Aliases (early — before keybinds)
#
alias wt="curl http://wttr.in/"
alias gw="git wut"
alias 'gcam!'="git commit --amend"

export GNUTERM="qt"
export PATH=$PATH:$GOBIN

### Keybinds
#
bindkey -v

## scripts
#
# <nothing here yet>

# direnv
eval "$(direnv hook $SHELL)"

### zsh settings
#
# NOTE: fpath additions (e.g. Docker completions) must come before compinit.
fpath=($HOME/.docker/completions $fpath)
# Only re-run compaudit once a day; use cached dump otherwise.
autoload -Uz compinit
if [[ -n ~/.zcompdump(#qN.mh+24) ]]; then
  compinit
else
  compinit -C
fi
export KEYTIMEOUT=1
export LC_ALL=en_US.utf-8
export LANG="$LC_ALL"

# Fuzzy finder - https://github.com/junegunn/fzf
source <(fzf --zsh)

# zoxide
eval "$(zoxide init zsh)"

# NOTE:
# git clone https://github.com/chrisands/zsh-yarn-completions.git ~/.zsh-yarn-completions
# source ~/.zsh-yarn-completions/zsh-yarn-completions.plugin.zsh

### Fix for catalina: https://stackoverflow.com/questions/58272830/python-crashing-on-macos-10-15-beta-19a582a-with-usr-lib-libcrypto-dylib
# export DYLD_FALLBACK_LIBRARY_PATH=/usr/local/opt/openssl/lib
# export DYLD_LIBRARY_PATH=/usr/local/opt/openssl/lib:$DYLD_LIBRARY_PATH

### Aliases
#
# -- git (common OMZ git plugin aliases)
alias g='git'
alias ga='git add'
alias gaa='git add --all'
alias gb='git branch'
alias gba='git branch -a'
alias gc='git commit --verbose'
alias gcmsg='git commit --message'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gd='git diff'
alias gds='git diff --staged'
alias gf='git fetch'
alias gl='git pull'
alias glog='git log --oneline --decorate --graph'
alias gp='git push'
alias gpf='git push --force-with-lease'
alias gst='git status'
alias gsw='git switch'
alias gswc='git switch --create'
alias grh='git reset HEAD'
alias grhh='git reset --hard HEAD'
alias grb='git rebase'
alias grbi='git rebase --interactive'

# -- normal
alias l="ls -lrt"
alias ll="ls -la"
alias lf="ls -lartFh"
alias dir="ls -lrtFh | grep '/$'"
alias pg_start="pg_ctl -D /usr/local/var/postgres -l /usr/local/var/postgres/server.log start"
alias pg_stop="pg_ctl -D /usr/local/var/postgres stop -s -m fast"
alias mysql_start="/usr/local/bin/mysql.server start"
alias mysql_stop="/usr/local/bin/mysql.server stop"
alias psql='psql -eL /tmp/psql.log'
alias cat='bat --style=header,grid,snip'
alias ping='prettyping --nolegend'
alias du="ncdu --color dark -rr -x --exclude .git --exclude node_modules"
alias terraform='tofu'
# https://code.visualstudio.com/sha/download?build=stable&os=cli-darwin-arm64
alias code='/Applications/Visual\ Studio\ Code.app/Contents/Resources/app/bin/code'
# Copilot with allowed shell tools:
alias copilot='copilot --allow-tool "shell(gh:*), shell(python3), shell(mkdir), shell(git:*), shell(pnpm:*), shell(sed), shell(awk), shell(xargs), shell(grep)"'

# -- global
#
alias -g gi='| grep -i'      # usage: ps aux gi ruby => ps aux | grep -i ruby

# -- suffix
#
alias -s rb=vim              # usage: user.rb => vim user.rb

# Read local secrets
[ -f ~/.zsh.local ] && source ~/.zsh.local

# https://gist.github.com/phette23/5270658#gistcomment-1265682
precmd() {
  # sets the tab title to current dir
  echo -ne "\e]1;${PWD##*/}\a"
}

ktc () {
  stern $1 -c $1 -e "kube-probe|Checking status...|health check|Accepted connection from /100" ${@:2}
}

# Kubernetes template functions for FedGraph GitOps
function ktempl() {
  service=${1}
  env=${2}
  region=${3:-weu}
  context="${region}-${env}"

  extra_file="./helm-releases/$service/$service-ecp.yaml"

  helm template --debug --kube-context $context $service ./helm-base \
    --set debugDiff=true \
    -n federated-graph \
    -f ./helm-envs/${region}-$env.yaml \
    -f $extra_file \
    -f ./helm-releases/$service/${region}-$env.yaml
}

function kdiff() {
  service=${1}
  env=${2}
  region=${3:-weu}

  if [[ $region == "weu" ]]; then
    context="${region}-${env}"
  else
    context="gf-${env}"
  fi

  ktempl $service $env $region
}

# Function to show process tree by port
ptree() {
  if [ -z "$1" ]; then
    echo "Shows the process tree of the process listening on the given port."
    echo "Usage: ptree <port-number>"
    return 1
  fi
  lsof -i :"$1" | tail -1 | awk '{print $2}' | xargs -r pstree -g 3 -p
}

export HOMEBREW_NO_AUTO_UPDATE=1
export PATH="/opt/homebrew/opt/libpq/bin:$PATH"
export APOLLO_TELEMETRY_DISABLED=true

# pnpm
export PNPM_HOME="$HOME/Library/pnpm"
export PATH="$PNPM_HOME:$PATH"
# pnpm end

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# PS1
eval "$(starship init zsh)"

# Generated for envman. Do not edit.
[ -s "$HOME/.config/envman/load.sh" ] && source "$HOME/.config/envman/load.sh"
export GOTOOLCHAIN=local

# vscode shell integration
[[ "$TERM_PROGRAM" == "vscode" ]] && . "$(code --locate-shell-integration-path zsh)"

# mise
eval "$(~/.local/bin/mise activate zsh)"

# fgctl
export PATH=$PATH:$HOME/.fgctl/bin
