# Caelaris Linux .bashrc
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias ll='ls -lah'
alias grep='grep --color=auto'
alias install-app='caelaris-install'
alias update='yay -Syu'
alias sysinfo='inxi -Fxz 2>/dev/null || fastfetch 2>/dev/null'

PS1='\[\e[1;34m\]caelaris\[\e[0m\]:\[\e[1;32m\]\w\[\e[0m\]\$ '
