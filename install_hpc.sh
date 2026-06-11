#!/usr/bin/env bash
# mbo server configs - Rockefeller HPC installer (no root)
#
# usage (from a login node, e.g. login05-hpc.rockefeller.edu):
#   ./install_hpc.sh             user setup: configs, shell env, ~/scratch link, terminfo
#   ./install_hpc.sh --admin     also build the shared stack in mbo_soft (run as mbo_soft)
#   ./install_hpc.sh --admin --ref v3.2.0   pin a different mbo_utilities release tag
#   ./install_hpc.sh -y          non-interactive
#
# the shared stack (binaries, neovim, the mbo_utilities venv) lives once under
# /lustre/fs8/mbo/scratch/mbo_soft. user mode just points your shell at it.

set -euo pipefail

USER="${USER:-$(id -un)}"

# locations
MBO_ROOT="${MBO_ROOT:-/lustre/fs8/mbo/scratch}"
MBO_SOFT="$MBO_ROOT/mbo_soft"
MBO_BIN="$MBO_SOFT/bin"
MBO_REPOS="$MBO_SOFT/repos"
MBO_ENVS="$MBO_SOFT/envs"
MBO_ENV="$MBO_ENVS/mbo"
MBO_DATA="$MBO_ROOT/mbo_data"
MBO_SCRATCH="$MBO_ROOT/$USER"
MBO_UTILITIES_URL="https://github.com/millerbrainobservatory/mbo_utilities"
MBO_UTILITIES_REF="v3.2.0"

MODE="user"
ASSUME_YES=0
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; NC='\033[0m'
info() { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*"; }

usage() {
    cat <<'EOF'
mbo server configs - Rockefeller HPC installer (no root)

usage (from a login node):
  ./install_hpc.sh             user setup: configs, shell env, ~/scratch link, terminfo
  ./install_hpc.sh --admin     also build the shared stack in mbo_soft (run as mbo_soft)
  ./install_hpc.sh --admin --ref v3.2.0   pin a different mbo_utilities release tag
  ./install_hpc.sh -y          non-interactive
EOF
}

confirm() {
    [[ $ASSUME_YES -eq 1 ]] && return 0
    local a; read -rp "$1 [Y/n] " a </dev/tty 2>/dev/null || return 0
    [[ -z "$a" || "$a" =~ ^[Yy] ]]
}

banner() {
    echo ""
    echo -e "${BLUE}  __  __ ___  ___  ${NC}"
    echo -e "${BLUE} |  \\/  | _ )/ _ \\ ${NC}"
    echo -e "${BLUE} | |\\/| | _ \\ (_) |${NC}"
    echo -e "${BLUE} |_|  |_|___/\\___/ ${NC}"
    echo ""
    echo "Miller Brain Observatory - HPC Setup ($MODE)"
    echo ""
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --admin) MODE="admin" ;;
        --user)  MODE="user" ;;
        -y|--yes) ASSUME_YES=1 ;;
        --ref) shift; MBO_UTILITIES_REF="${1:-$MBO_UTILITIES_REF}" ;;
        -h|--help) usage; exit 0 ;;
        *) err "unknown option: $1"; usage; exit 1 ;;
    esac
    shift
done

ensure_submodules() {
    if [[ -d "$REPO_DIR/.git" ]] && command -v git >/dev/null 2>&1; then
        git -C "$REPO_DIR" submodule update --init --recursive 2>/dev/null \
            && ok "submodules ready (nvim config)" \
            || warn "could not update submodules"
    fi
}

# back up a real file/dir, replace symlinks, then link
link_file() {
    local source="$1" target="$2"
    [[ -e "$source" ]] || return 0
    mkdir -p "$(dirname "$target")"
    if [[ -L "$target" ]]; then
        rm -f "$target"
    elif [[ -e "$target" ]]; then
        mv "$target" "${target}.backup.$(date +%s)"
        warn "backed up existing $target"
    fi
    ln -s "$source" "$target"
    ok "linked $target"
}

ensure_uv() {
    if command -v uv >/dev/null 2>&1; then
        ok "uv present: $(uv --version)"
        return 0
    fi
    if [[ -x "$MBO_BIN/uv" ]]; then
        ok "uv present: $("$MBO_BIN/uv" --version)"
        return 0
    fi
    info "installing uv to $MBO_BIN..."
    curl -LsSf https://astral.sh/uv/install.sh \
        | env UV_INSTALL_DIR="$MBO_BIN" INSTALLER_NO_MODIFY_PATH=1 sh
    ok "uv installed"
}

build_shared_venv() {
    local uv; uv="$(command -v uv || echo "$MBO_BIN/uv")"
    mkdir -p "$MBO_ENVS"

    if [[ ! -x "$MBO_ENV/bin/python" ]]; then
        info "creating shared venv at $MBO_ENV (python 3.12)..."
        UV_LINK_MODE=copy "$uv" venv "$MBO_ENV" --python 3.12
    else
        ok "shared venv exists: $MBO_ENV"
    fi

    confirm "install mbo_utilities @ $MBO_UTILITIES_REF into $MBO_ENV (downloads several GB)?" || {
        warn "skipped mbo_utilities install"; return 0
    }
    info "installing mbo_utilities @ $MBO_UTILITIES_REF (downloads torch/cuda, several minutes)..."
    UV_LINK_MODE=copy "$uv" pip install --python "$MBO_ENV/bin/python" \
        "mbo_utilities @ git+$MBO_UTILITIES_URL@$MBO_UTILITIES_REF"

    # expose console scripts on the shared PATH (avoids shadowing python/pip)
    for s in mbo pollen; do
        [[ -x "$MBO_ENV/bin/$s" ]] && ln -sf "$MBO_ENV/bin/$s" "$MBO_BIN/$s" && ok "linked $s -> shared venv"
    done
}

setup_shared() {
    info "building shared stack in $MBO_SOFT (run this as mbo_soft)..."
    mkdir -p "$MBO_BIN" "$MBO_SOFT/local"

    # reuse the linux tool installers from install.sh, retargeted to the shared bin
    export LOCAL_BIN="$MBO_BIN"
    export LOCAL_SHARE="$MBO_SOFT/local"
    # shellcheck source=install.sh
    source "$REPO_DIR/install.sh"
    for t in install_neovim install_fzf install_ripgrep install_fd install_lazygit \
             install_starship install_zoxide install_bat install_delta install_eza; do
        "$t" || warn "$t failed"
    done

    ensure_uv
    build_shared_venv

    # group-readable so all mbo users can use the shared stack
    chmod -R g+rX "$MBO_BIN" "$MBO_ENVS" 2>/dev/null || true
    ok "shared stack ready"
}

install_kitty_terminfo() {
    if infocmp xterm-kitty >/dev/null 2>&1; then
        ok "kitty terminfo already available"
        return 0
    fi
    command -v tic >/dev/null 2>&1 || { warn "tic not found, skipping kitty terminfo"; return 0; }
    local tmp="/tmp/kitty.$$.terminfo"
    if curl -fsSL https://raw.githubusercontent.com/kovidgoyal/kitty/master/terminfo/kitty.terminfo -o "$tmp" 2>/dev/null; then
        tic -x -o "$HOME/.terminfo" "$tmp" 2>/dev/null && ok "kitty terminfo installed (~/.terminfo)"
        rm -f "$tmp"
    else
        warn "could not fetch kitty terminfo"
    fi
}

add_bashrc_block() {
    local rc="$HOME/.bashrc" marker="# >>> mbo_server_configs >>>"
    if [[ -f "$rc" ]] && grep -qF "$marker" "$rc"; then
        ok "~/.bashrc already sources mbo.sh"
        return 0
    fi
    {
        echo ""
        echo "$marker"
        echo "[ -f \"$REPO_DIR/config/hpc/mbo.sh\" ] && source \"$REPO_DIR/config/hpc/mbo.sh\""
        echo "# <<< mbo_server_configs <<<"
    } >> "$rc"
    ok "added mbo.sh source block to ~/.bashrc"
}

setup_user() {
    info "setting up shell environment for $USER..."

    # personal scratch dir + ~/scratch symlink (per HPC convention)
    mkdir -p "$MBO_SCRATCH" 2>/dev/null || true
    if [[ -d "$MBO_SCRATCH" && ! -e "$HOME/scratch" ]]; then
        ln -s "$MBO_SCRATCH" "$HOME/scratch" && ok "linked ~/scratch -> $MBO_SCRATCH"
    fi

    local src="$REPO_DIR/config"
    link_file "$src/nvim"          "$HOME/.config/nvim"
    link_file "$src/vimrc"         "$HOME/.vimrc"
    link_file "$src/lazygit"       "$HOME/.config/lazygit"
    link_file "$src/starship.toml" "$HOME/.config/starship.toml"
    link_file "$src/tmux"          "$HOME/.config/tmux"
    link_file "$src/btop"          "$HOME/.config/btop"
    link_file "$src/aliases"       "$HOME/.aliases"

    add_bashrc_block
    install_kitty_terminfo
}

summary() {
    echo ""
    echo -e "${GREEN}Done.${NC} source ~/.bashrc (or reconnect)."
    echo ""
    echo "  locations:   cdsoft  cddata  cdlbm  cdlsm  cdscratch  cdrepos"
    echo "  python:      mbo-activate   |   mbo-run <cmd>   |   mbo (cli)"
    echo "  transfer:    mbo-stage <path-under-mbo_data> [dest]   mbo-pull   mbo-push"
    echo "  slurm:       gpu [part] [time] [n]   cpu   mbo-jobs   mbo-gpus"
    echo ""
    if [[ "$MODE" != "admin" && ! -x "$MBO_ENV/bin/python" ]]; then
        warn "shared venv not found at $MBO_ENV — an admin must run: ./install_hpc.sh --admin"
    fi
}

main() {
    banner
    ensure_submodules
    [[ "$MODE" == "admin" ]] && setup_shared
    setup_user
    summary
}

main
