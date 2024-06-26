# Path to your oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh

# Set name of the theme to load.
# Look in ~/.oh-my-zsh/themes/
# Optionally, if you set this to "random", it'll load a random theme each
# time that oh-my-zsh is loaded.
#ZSH_THEME="ys"
#ZSH_THEME="robbyrusselll"
#ZSH_THEME="adben"          # NA: ps1_fortune
#ZSH_THEME="agnoster"       # Lite småsnygga färger/grafik men svårläst path
#ZSH_THEME="bureau"         # Average. Git repot för lång till höger
#ZSH_THEME="candy-kingdom"  # NA: battery_time_remaining / battery_pct_prompt
#ZSH_THEME="dieter"         # Meh
#ZSH_THEME="fino-time"      # Pretty good! <--- disabled due to trialing Powerline Shell
#ZSH_THEME="fino"           # Funkar inte riktigt
#ZSH_THEME="flazz"          # Meh
#ZSH_THEME="gallois"        # Intressant - git repo / ruby version till höger (behöver inte se dem jämt) men prompten bygger horisontellt
#ZSH_THEME="kardan"         # ALLT till höger - även path. Känns minimalistisk utan att egentligen vara det.
#ZSH_THEME="mortalscumbag"  # Bleh
#ZSH_THEME="steeef"         # ys-klon
#ZSH_THEME="sunrise"        # Bleh
#ZSH_THEME=""

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# The optional three formats: "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git asdf zoxide)

source $ZSH/oh-my-zsh.sh

# User settings
#
# export MANPATH="/usr/local/man:$MANPATH"

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

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"
#
alias wt="curl http://wttr.in/"
alias gw="git wut"
alias 'gcam!'="git commit --amend"

export GNUTERM="qt"
export GOROOT=$(brew --prefix go)/libexec
export GOBIN=/Users/MKLIPPIN/go/bin
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
# NOTE: This line screws p yarn completions, and need to come before sourcing it.
autoload -Uz compinit && compinit
export KEYTIMEOUT=1
export LC_ALL=en_US.utf-8
export LANG="$LC_ALL"

# Fuzzy finder - https://github.com/junegunn/fzf
source <(fzf --zsh)

# NOTE:
# git clone https://github.com/chrisands/zsh-yarn-completions.git ~/.zsh-yarn-completions
# source ~/.zsh-yarn-completions/zsh-yarn-completions.plugin.zsh

### Fix for catalina: https://stackoverflow.com/questions/58272830/python-crashing-on-macos-10-15-beta-19a582a-with-usr-lib-libcrypto-dylib
# export DYLD_FALLBACK_LIBRARY_PATH=/usr/local/opt/openssl/lib
# export DYLD_LIBRARY_PATH=/usr/local/opt/openssl/lib:$DYLD_LIBRARY_PATH

### Aliases
#
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
alias code='/Applications/code'

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

kdiff () {
	service=${1} env=${2}
	helm template $service ./helm-base -f ./helm-envs/euwest1-$env.yaml -f ./helm-releases/$service/$service.yaml -f ./helm-releases/$service/euwest1-$env.yaml | kubectl --context $env diff -f -
}

# export VOLTA_HOME="$HOME/.volta"
# export PATH="$VOLTA_HOME/bin:$PATH"
export HOMEBREW_NO_AUTO_UPDATE=1
export PATH="/opt/homebrew/opt/libpq/bin:$PATH"
export APOLLO_TELEMETRY_DISABLED=true

# pnpm
export PNPM_HOME="/Users/MKLIPPIN/Library/pnpm"
export PATH="$PNPM_HOME:$PATH"
# pnpm end

# bun completions
[ -s "/Users/MKLIPPIN/.oh-my-zsh/completions/_bun" ] && source "/Users/MKLIPPIN/.oh-my-zsh/completions/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# PS1
eval "$(starship init zsh)"
