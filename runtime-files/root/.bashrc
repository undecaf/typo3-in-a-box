export PS1='\[\033[1;32m\]\u@\H\[\033[0m\]:\[\033[16m\]\w\[\033[0m\]# '
export HISTCONTROL=erasedups

alias ll='ls -lA'

# Load the current runtime environment
. /usr/local/lib/env.inc
load_env
