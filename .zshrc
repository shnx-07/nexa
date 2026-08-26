# ============================================================
# ZSH CONFIGURATION
# Arch Linux • Developer Focused • Single File
# ============================================================

# ============================================================
# USER CONFIGURATION
# ============================================================


# Locale
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

# XDG Base Directories
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

# ============================================================
# SHELL OPTIONS
# ============================================================

# Automatically change into a directory by typing its name
setopt AUTO_CD

# Correct small spelling mistakes in directory names
setopt CORRECT

# Use extended globbing patterns
setopt EXTENDED_GLOB

# Allow ** recursive globbing
setopt GLOB_STAR_SHORT

# Don't beep
setopt NO_BEEP

# Better job control
setopt AUTO_RESUME
setopt LONG_LIST_JOBS
setopt NOTIFY

# Better directory navigation
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt PUSHD_SILENT

# Allow comments in interactive shell
setopt INTERACTIVE_COMMENTS

# ============================================================
# HISTORY
# ============================================================

# 1. Create history directory FIRST before defining HISTFILE
[[ -d "$XDG_STATE_HOME/zsh" ]] || mkdir -p "$XDG_STATE_HOME/zsh"

# History file location
HISTFILE="$XDG_STATE_HOME/zsh/history"

# Keep lots of history
HISTSIZE=100000
SAVEHIST=100000

# History behaviour (INC_APPEND_HISTORY_TIME is MUCH safer than SHARE_HISTORY)
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY_TIME
setopt EXTENDED_HISTORY

# Remove duplicates
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_SAVE_NO_DUPS
setopt HIST_FIND_NO_DUPS

# Ignore duplicate consecutive commands
setopt HIST_IGNORE_DUPS

# Ignore commands starting with a space
setopt HIST_IGNORE_SPACE

# Expire duplicate entries first
setopt HIST_EXPIRE_DUPS_FIRST

# Reduce unnecessary blanks
setopt HIST_REDUCE_BLANKS

# Verify history expansion before execution
setopt HIST_VERIFY


# ============================================================
# KEYBINDINGS
# ============================================================

# Use Emacs keybindings (default)
bindkey -e

# Home / End
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line

# Delete
bindkey '^[[3~' delete-char

# Ctrl + Left / Right
bindkey '^[[1;5D' backward-word
bindkey '^[[1;5C' forward-word

# History search using Up / Down
autoload -Uz up-line-or-beginning-search
autoload -Uz down-line-or-beginning-search

zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search

bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search

# Ctrl + Backspace
bindkey '^H' backward-kill-word

# Ctrl + Delete
bindkey '^[^[[3~' kill-word

# ============================================================
# COMPLETION
# ============================================================

autoload -Uz compinit

# Cache completion dump
ZCOMPDUMP="$XDG_CACHE_HOME/zsh/.zcompdump"

mkdir -p "$XDG_CACHE_HOME/zsh"

compinit -d "$ZCOMPDUMP"

# Completion behaviour
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list \
    'm:{a-z}={A-Za-z}' \
    'r:|=*' \
    'l:|=*'

# Better completion descriptions
zstyle ':completion:*' verbose yes
zstyle ':completion:*:descriptions' format '%F{yellow}%d%f'
zstyle ':completion:*:messages' format '%F{green}%d%f'
zstyle ':completion:*:warnings' format '%F{red}No matches found%f'

# Process list
zstyle ':completion:*:*:*:*:processes' command \
    'ps -u $USER -o pid,comm'

# Completion colors
if [[ -n "$LS_COLORS" ]]; then
    zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
fi

# ============================================================
# DECORATION
# ============================================================

# Enable colors
autoload -Uz colors
colors

# Colored output
export CLICOLOR=1


# Colored man pages
export LESS_TERMCAP_mb=$'\E[1;31m'
export LESS_TERMCAP_md=$'\E[1;36m'
export LESS_TERMCAP_me=$'\E[0m'
export LESS_TERMCAP_se=$'\E[0m'
export LESS_TERMCAP_so=$'\E[1;44;33m'
export LESS_TERMCAP_ue=$'\E[0m'
export LESS_TERMCAP_us=$'\E[1;32m'

# Terminal title
autoload -Uz add-zsh-hook

function set-terminal-title() {
    print -Pn "\e]0;%n@%m: %~\a"
}

add-zsh-hook precmd set-terminal-title


# Enable 24-bit color support
export COLORTERM=truecolor

# Nerd Font detection
if [[ "$TERM_PROGRAM" == "WezTerm" ]] || \
   [[ "$TERM" == "xterm-kitty" ]]; then
    export USE_NERD_FONT=1
fi


# ============================================================
# ALIASES
# ============================================================

# Safer file operations
alias cp='cp -iv'
alias mv='mv -iv'
alias rm='rm -Iv'

# Better ls
alias ls='ls --color=auto --group-directories-first'
alias ll='ls -lh'
alias la='ls -lah'
alias l='ls -CF'

# Better tools
command -v eza >/dev/null && alias ls='eza --group-directories-first --icons'
command -v bat >/dev/null && alias cat='bat --paging=never'
command -v btop >/dev/null && alias top='btop'

# Grep
alias grep='grep --color=auto'
alias egrep='grep -E --color=auto'
alias fgrep='grep -F --color=auto'

# Disk usage
alias df='df -h'
alias du='du -h'

# Quick navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Git
alias g='git'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'
alias lg='lazygit'

# Editor
alias v='nvim'
alias vim='nvim'

# Misc
alias c='clear'
alias h='history'
alias reload='exec zsh'

# ============================================================
# ENVIRONMENT
# ============================================================

# Default pager
export PAGER="less"

# Use Neovim for man pages
export MANPAGER='nvim +Man!'

# Better less
export LESS='-R -F -X'

# ============================================================
# PATH
# ============================================================

# Helper: add to PATH only if directory exists
path_prepend() {
    [[ -d "$1" ]] && PATH="$1:$PATH"
}

path_append() {
    [[ -d "$1" ]] && PATH="$PATH:$1"
}

# User binaries
path_prepend "$HOME/.local/bin"

# User scripts
path_prepend "$HOME/bin"

# Cargo
path_append "$HOME/.cargo/bin"

# Go
path_append "$HOME/go/bin"

# pnpm
path_append "$HOME/.local/share/pnpm"

# Android Studio (if installed)
path_append "$HOME/Android/Sdk/platform-tools"

# Export PATH
export PATH

# ============================================================
# QUALITY OF LIFE
# ============================================================

# Use modern completion cache
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$XDG_CACHE_HOME/zsh"


# Automatically remove duplicate PATH entries
typeset -U PATH path

# ============================================================
# PLUGIN LOADING
# ============================================================

# Helper to source files safely
source_if_exists() {
    [[ -f "$1" ]] && source "$1"
}

# ============================================================
# FZF
# ============================================================

if command -v fzf >/dev/null; then
    [[ -f /usr/share/fzf/key-bindings.zsh ]] && source /usr/share/fzf/key-bindings.zsh
    [[ -f /usr/share/fzf/completion.zsh ]] && source /usr/share/fzf/completion.zsh

    export FZF_DEFAULT_OPTS="
        --height=40%
        --layout=reverse
        --border
        --info=inline
    "
fi

# ============================================================
# ZOXIDE
# ============================================================

if command -v zoxide >/dev/null; then
    eval "$(zoxide init zsh)"
fi

# ============================================================
# STARSHIP
# ============================================================

if command -v starship >/dev/null; then
    eval "$(starship init zsh)"
fi

# ============================================================
# ZSH AUTOSUGGESTIONS
# ============================================================

source_if_exists /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source_if_exists /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh

ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
ZSH_AUTOSUGGEST_STRATEGY=(history completion)

# ============================================================
# ZSH SYNTAX HIGHLIGHTING
# ============================================================

source_if_exists /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source_if_exists /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# ============================================================
# UTILITY FUNCTIONS
# ============================================================

# Create directory and enter it
mkcd() {
    mkdir -p "$1" && cd "$1"
}

# Print PATH one entry per line
path() {
    printf "%s\n" "${path[@]}"
}

# Backup a file
backup() {
    cp -a "$1" "$1.$(date +%Y%m%d_%H%M%S).bak"
}

# Extract common archive formats
extract() {
    if [[ ! -f "$1" ]]; then
        echo "File not found."
        return 1
    fi

    case "$1" in
        *.tar.bz2) tar xjf "$1" ;;
        *.tar.gz)  tar xzf "$1" ;;
        *.tar.xz)  tar xJf "$1" ;;
        *.tar)     tar xf "$1" ;;
        *.bz2)     bunzip2 "$1" ;;
        *.gz)      gunzip "$1" ;;
        *.xz)      unxz "$1" ;;
        *.zip)     unzip "$1" ;;
        *.rar)     unrar x "$1" ;;
        *.7z)      7z x "$1" ;;
        *) echo "Unsupported archive format." ;;
    esac
}

# Show current weather (requires curl)
weather() {
    curl wttr.in
}

# ============================================================
# STARTUP
# ============================================================

# Welcome only in interactive shells
if [[ $- == *i* ]]; then


fi

# ============================================================
# END
# ============================================================
export PATH="$HOME/.local/bin:$PATH"
