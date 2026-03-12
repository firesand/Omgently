# ╔══════════════════════════════════════════════════════════╗
# ║            OMGENTLY — Bash Configuration                ║
# ╚══════════════════════════════════════════════════════════╝

# Jika bukan interactive shell, jangan lanjutkan
[[ $- != *i* ]] && return

# ── Path ──────────────────────────────────────────────────
export PATH="$HOME/.local/bin:$PATH"

# ── Environment ───────────────────────────────────────────
export EDITOR="nvim"
export VISUAL="nvim"
export TERMINAL="ghostty"
export BROWSER="brave"
export MANPAGER="sh -c 'col -bx | bat -l man -p'"

# ── History ───────────────────────────────────────────────
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoreboth:erasedups
shopt -s histappend

# ── Shell Options ─────────────────────────────────────────
shopt -s checkwinsize
shopt -s cdspell
shopt -s dirspell
shopt -s autocd
shopt -s globstar

# ── Modern CLI Replacements ───────────────────────────────
if command -v eza &>/dev/null; then
    alias ls='eza --icons --group-directories-first'
    alias ll='eza -la --icons --group-directories-first'
    alias la='eza -a --icons --group-directories-first'
    alias lt='eza --tree --icons --level=2'
    alias tree='eza --tree --icons'
fi

if command -v bat &>/dev/null; then
    alias cat='bat --style=auto --paging=never'
    alias less='bat --style=auto'
fi

if command -v rg &>/dev/null; then
    alias grep='rg'
fi

if command -v fd &>/dev/null; then
    alias find='fd'
fi

# ── FZF Integration ───────────────────────────────────────
if command -v fzf &>/dev/null; then
    # Fuzzy file finder
    ff() {
        local file
        file=$(fzf --preview 'bat --color=always --style=numbers --line-range=:300 {} 2>/dev/null || cat {}' \
               --preview-window=right:60% \
               --bind 'ctrl-/:toggle-preview')
        [ -n "$file" ] && ${EDITOR:-nvim} "$file"
    }

    # Fuzzy directory changer
    fd_cd() {
        local dir
        dir=$(find "${1:-.}" -type d 2>/dev/null | fzf --preview 'eza --tree --icons --level=1 --color=always {}' +m)
        [ -n "$dir" ] && cd "$dir"
    }
    alias fcd='fd_cd'

    # Ctrl+R: fuzzy history search
    eval "$(fzf --bash 2>/dev/null)" || true
fi

# ── Navigation ────────────────────────────────────────────
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias -- -='cd -'

# ── Safety ────────────────────────────────────────────────
alias rm='rm -i'
alias mv='mv -i'
alias cp='cp -i'

# ── Omgently Shortcuts ───────────────────────────────────
alias hc='nvim ~/.config/hypr/hyprland.conf'
alias hb='nvim ~/.config/hypr/bindings.conf'
alias hi='nvim ~/.config/hypr/input.conf'
alias hr='hyprctl reload && echo "Hyprland reloaded"'
alias wbr='killall waybar; waybar & disown; echo "Waybar restarted"'

# ── Gentoo ────────────────────────────────────────────────
if command -v emerge &>/dev/null; then
    alias eS='doas emerge --ask'
    alias eR='doas emerge --deselect --ask'
    alias eU='doas emerge --update --deep --newuse @world'
    alias eQ='equery list'
    alias esync='doas emaint sync -a'
fi

# ── Git ───────────────────────────────────────────────────
alias g='git'
alias gs='git status -sb'
alias ga='git add'
alias gc='git commit'
alias gcm='git commit -m'
alias gp='git push'
alias gl='git log --oneline --graph --decorate -15'
alias gd='git diff'
alias gco='git checkout'

# ── Prompt (Minimalis Tokyo Night) ────────────────────────
_prompt_git() {
    local branch
    branch=$(git symbolic-ref --short HEAD 2>/dev/null) || return
    local status=""
    git diff --quiet 2>/dev/null || status="*"
    git diff --cached --quiet 2>/dev/null || status="${status}+"
    echo " \[\e[35m\]${branch}${status}\[\e[0m\]"
}

_set_prompt() {
    local exit_code=$?
    local blue='\[\e[34m\]'
    local cyan='\[\e[36m\]'
    local red='\[\e[31m\]'
    local reset='\[\e[0m\]'
    local muted='\[\e[90m\]'

    local indicator="${blue}❯${reset}"
    [ $exit_code -ne 0 ] && indicator="${red}❯${reset}"

    PS1="${cyan}\w${reset}$(_prompt_git) ${indicator} "
}

PROMPT_COMMAND='_set_prompt'

# ── Greeting ──────────────────────────────────────────────
echo -e "\e[34m  🎌 Omgently\e[0m — \e[90m$(uname -sr) | $(date '+%a %d %b %H:%M')\e[0m"
