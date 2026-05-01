# HomeOS shell helpers
alias d='docker'
alias dc='docker compose'
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias l='eza -la --git --group-directories-first 2>/dev/null || ls -la'
alias ll='eza -l --git 2>/dev/null || ls -l'
alias cat='bat --paging=never 2>/dev/null || /usr/bin/cat'
alias g='git'
alias gs='git status -sb'
alias k='kubectl'
alias hs='homeos status'
alias hd='homeos doctor'
alias logs='journalctl -fu'

export EDITOR=nvim
export PATH="$HOME/.local/bin:$PATH"
