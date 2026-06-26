#!/usr/bin/env bash
# one-time per-user HPC setup. idempotent, safe to re-run if your shell or nvim drifts.
# installs nothing: CLI tools, neovim, and venvs are shared under $MBO_SOFT.
#   1. source mbo.sh from ~/.bashrc on every login
#   2. check out the neovim config submodule and link it to ~/.config/nvim
#   3. create your personal scratch dir
set -eu

_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"   # .../config/hpc
_repo="$(cd "$_dir/../.." && pwd)"

# 1. auto-source on login. if a prior install.sh symlinked ~/.bashrc into the repo,
#    turn it back into a real file first so we don't append into a tracked file.
if [ -L "$HOME/.bashrc" ]; then
    cp --remove-destination "$(readlink -f "$HOME/.bashrc")" "$HOME/.bashrc"
fi
if grep -q 'config/hpc/mbo.sh' "$HOME/.bashrc" 2>/dev/null; then
    echo "ok: ~/.bashrc already sources mbo.sh"
else
    printf '\nsource %s/mbo.sh\n' "$_dir" >> "$HOME/.bashrc"
    echo "added: source $_dir/mbo.sh -> ~/.bashrc"
fi

# 2. neovim config (submodule -> ~/.config/nvim)
git -C "$_repo" submodule update --init --recursive
mkdir -p "$HOME/.config"
_nvim="$HOME/.config/nvim"
if [ -L "$_nvim" ] || [ ! -e "$_nvim" ]; then
    ln -sfn "$_repo/config/nvim" "$_nvim"
elif [ -d "$_nvim" ]; then
    mv "$_nvim" "$_nvim.backup.$$"
    ln -s "$_repo/config/nvim" "$_nvim"
    echo "backed up existing ~/.config/nvim -> $_nvim.backup.$$"
fi
echo "linked: ~/.config/nvim -> $_repo/config/nvim"

# 3. personal scratch (MBO_USER from env.sh)
. "$_dir/env.sh"
mkdir -p "$MBO_USER"
echo "scratch: $MBO_USER"

echo
echo "done. start a fresh shell:  exec bash"
