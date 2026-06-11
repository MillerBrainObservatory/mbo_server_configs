#!/usr/bin/env bash
# mbo_server_configs - Rockefeller HPC shell environment
# add to ~/.bashrc:  source /lustre/fs8/mbo/scratch/mbo_soft/repos/mbo_server_configs/config/hpc/mbo.sh
# defines locations, PATH, uv env, aliases, and data-transfer / slurm helpers.
# safe in non-interactive shells.

# locations + uv state (single source of truth: config/hpc/env.sh)
_mbo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_mbo_dir/env.sh"

# path: shared tools first, then user-local
for _d in "$MBO_BIN" "$MBO_NVIM/bin" "$HOME/.local/bin"; do
    [ -d "$_d" ] && case ":$PATH:" in *":$_d:"*) ;; *) PATH="$_d:$PATH";; esac
done
unset _d
export PATH

export EDITOR=nvim
export VISUAL=nvim

# terminfo fallback: kitty/wezterm/ghostty set a TERM the cluster may not know
if ! infocmp "$TERM" >/dev/null 2>&1; then
    export TERM=xterm-256color
fi

# location jumps
alias cdsoft='cd "$MBO_SOFT"'
alias cdrepos='cd "$MBO_REPOS"'
alias cddata='cd "$MBO_DATA"'
alias cdlbm='cd "$MBO_LBM"'
alias cdlsm='cd "$MBO_LSM"'
alias cdscratch='cd "$MBO_SCRATCH"'
alias cdme='cd "$MBO_USER"'

# mbo_utilities shared venv
alias mbo-activate='source "$MBO_ENV/bin/activate"'
mbo-run() {
    if [ -z "$1" ]; then echo "usage: mbo-run <command> [args...]"; return 1; fi
    local exe="$MBO_ENV/bin/$1"; shift
    if [ ! -x "$exe" ]; then echo "mbo-run: $exe not found in shared venv"; return 1; fi
    "$exe" "$@"
}

# data transfer (run large transfers from a DTN node: ssh <user>@dtn02-hpc)
mbo-stage() {
    if [ -z "$1" ]; then echo "usage: mbo-stage <path-under-mbo_data> [dest]"; return 1; fi
    rsync -aP "$MBO_DATA/$1" "${2:-$MBO_USER}/"
}
mbo-pull() {
    if [ -z "$1" ]; then echo "usage: mbo-pull <user@host:path> [dest]"; return 1; fi
    rsync -aP "$1" "${2:-$MBO_USER}/"
}
mbo-push() {
    if [ $# -lt 2 ]; then echo "usage: mbo-push <src> <user@host:path>"; return 1; fi
    rsync -aP "$1" "$2"
}

# slurm helpers
alias mbo-jobs='squeue --me'
mbo-gpus() {
    sinfo -N --Format=nodelist,partition,cpusstate,freemem,gres --sort=#P,N \
        | awk 'NR==1 || $2 ~ /^hpc/'
}
mbo-gpu() {   # interactive gpu shell: mbo-gpu [partition] [time] [ngpu]
    srun --partition="${1:-hpc_a10_a}" --gres="gpu:${3:-1}" \
        --cpus-per-task=8 --mem=64G --time="${2:-04:00:00}" --pty bash -l
}
mbo-cpu() {   # interactive cpu shell: mbo-cpu [partition] [time]
    srun --partition="${1:-test}" --cpus-per-task=8 --mem=32G \
        --time="${2:-04:00:00}" --pty bash -l
}

# general portable aliases from this repo
[ -f "$_mbo_dir/../aliases" ] && source "$_mbo_dir/../aliases"
unset _mbo_dir

# interactive-only below
case $- in *i*) ;; *) return 0;; esac

HISTCONTROL=ignoreboth
HISTSIZE=10000
HISTFILESIZE=20000
shopt -s histappend checkwinsize
bind '"\e[A": history-search-backward' 2>/dev/null
bind '"\e[B": history-search-forward' 2>/dev/null

export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'
command -v fd >/dev/null 2>&1 && export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'

command -v starship >/dev/null 2>&1 && eval "$(starship init bash)"
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init bash --cmd cd)"
