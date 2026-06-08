#!/usr/bin/env bash
# mbo server configs installer
# installs configs + optional tools to ~/.local (no sudo required)
#
# usage:
#   curl -fsSL https://raw.githubusercontent.com/MillerBrainObservatory/mbo_server_configs/master/install.sh | bash
#   ./install.sh

set -e

# colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${BLUE}[INFO]${NC} $*"; }
ok() { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err() { echo -e "${RED}[ERROR]${NC} $*"; }

# detect architecture
ARCH=$(uname -m)
case "$ARCH" in
    x86_64) ARCH_SUFFIX="x86_64" ;;
    aarch64|arm64) ARCH_SUFFIX="aarch64" ;;
    *) err "unsupported architecture: $ARCH"; exit 1 ;;
esac

OS=$(uname -s | tr '[:upper:]' '[:lower:]')

# directories
DOTFILES_ROOT="${DOTFILES_ROOT:-$HOME/.mbo_server_configs}"
LOCAL_BIN="$HOME/.local/bin"
LOCAL_SHARE="$HOME/.local/share"

banner() {
    echo ""
    echo -e "${BLUE}  __  __ ___  ___  ${NC}"
    echo -e "${BLUE} |  \\/  | _ )/ _ \\ ${NC}"
    echo -e "${BLUE} | |\\/| | _ \\ (_) |${NC}"
    echo -e "${BLUE} |_|  |_|___/\\___/ ${NC}"
    echo ""
    echo "Miller Brain Observatory - Server Configs"
    echo ""
}

command_exists() {
    command -v "$1" &>/dev/null
}

ensure_dirs() {
    mkdir -p "$LOCAL_BIN"
    mkdir -p "$LOCAL_SHARE"
    mkdir -p "$HOME/.config"
}

clone_dotfiles() {
    if [[ -d "$DOTFILES_ROOT" && -f "$DOTFILES_ROOT/install.sh" ]]; then
        info "dotfiles already present at $DOTFILES_ROOT"
        cd "$DOTFILES_ROOT"
        git pull --ff-only 2>/dev/null || true
        return
    fi

    info "cloning configs to $DOTFILES_ROOT..."
    git clone --recursive https://github.com/MillerBrainObservatory/mbo_server_configs.git "$DOTFILES_ROOT"
    ok "configs cloned"
}

setup_path() {
    if [[ ":$PATH:" != *":$LOCAL_BIN:"* ]]; then
        export PATH="$LOCAL_BIN:$PATH"
    fi
}

# link config files
link_configs() {
    info "linking configurations..."

    local src="$DOTFILES_ROOT/config"

    # helper function
    link_file() {
        local source="$1"
        local target="$2"

        if [[ ! -e "$source" ]]; then
            return
        fi

        mkdir -p "$(dirname "$target")"

        if [[ -L "$target" ]]; then
            rm "$target"
        elif [[ -e "$target" ]]; then
            mv "$target" "${target}.backup.$(date +%s)"
            warn "backed up existing $target"
        fi

        ln -sf "$source" "$target"
        ok "linked $target"
    }

    # shell configs
    link_file "$src/bashrc" "$HOME/.bashrc"
    link_file "$src/aliases" "$HOME/.aliases"

    # neovim
    link_file "$src/nvim" "$HOME/.config/nvim"

    # vim
    link_file "$src/vimrc" "$HOME/.vimrc"

    # tmux
    link_file "$src/tmux" "$HOME/.config/tmux"

    # lazygit
    link_file "$src/lazygit" "$HOME/.config/lazygit"

    # starship prompt
    link_file "$src/starship.toml" "$HOME/.config/starship.toml"

    # btop
    link_file "$src/btop" "$HOME/.config/btop"

    # git config (if exists)
    if [[ -f "$src/gitconfig" ]]; then
        link_file "$src/gitconfig" "$HOME/.gitconfig"
    fi
}

# install neovim
install_neovim() {
    if command_exists nvim; then
        ok "neovim already installed: $(nvim --version | head -1)"
        return 0
    fi

    info "installing neovim..."

    if [[ "$OS" == "linux" ]]; then
        local nvim_url="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${ARCH_SUFFIX}.appimage"
        local nvim_file="$LOCAL_BIN/nvim"

        if curl -fsSL "$nvim_url" -o "$nvim_file" 2>/dev/null; then
            chmod +x "$nvim_file"

            # test if appimage works (some servers lack FUSE)
            if ! "$nvim_file" --version &>/dev/null; then
                warn "appimage requires FUSE, extracting..."
                cd "$LOCAL_SHARE"
                "$nvim_file" --appimage-extract &>/dev/null || true
                rm "$nvim_file"
                ln -sf "$LOCAL_SHARE/squashfs-root/usr/bin/nvim" "$nvim_file"
            fi
            ok "neovim installed"
            return 0
        fi

        # fallback: tarball
        local nvim_tar_url="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${ARCH_SUFFIX}.tar.gz"
        if curl -fsSL "$nvim_tar_url" | tar xz -C "$LOCAL_SHARE" 2>/dev/null; then
            ln -sf "$LOCAL_SHARE/nvim-linux-${ARCH_SUFFIX}/bin/nvim" "$nvim_file"
            ok "neovim installed (tarball)"
            return 0
        fi
    fi

    warn "could not install neovim automatically"
    return 1
}

# install fzf
install_fzf() {
    if command_exists fzf; then
        ok "fzf already installed"
        return 0
    fi

    info "installing fzf..."

    # try binary release first
    local fzf_version
    fzf_version=$(curl -fsSL "https://api.github.com/repos/junegunn/fzf/releases/latest" | grep '"tag_name"' | sed -E 's/.*"v?([^"]+)".*/\1/')

    local fzf_url="https://github.com/junegunn/fzf/releases/download/v${fzf_version}/fzf-${fzf_version}-${OS}_amd64.tar.gz"
    [[ "$ARCH_SUFFIX" == "aarch64" ]] && fzf_url="https://github.com/junegunn/fzf/releases/download/v${fzf_version}/fzf-${fzf_version}-${OS}_arm64.tar.gz"

    if curl -fsSL "$fzf_url" | tar xz -C "$LOCAL_BIN" 2>/dev/null; then
        ok "fzf installed"
        return 0
    fi

    # fallback: git install
    if [[ ! -d "$HOME/.fzf" ]]; then
        git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
        "$HOME/.fzf/install" --bin --no-update-rc
        ln -sf "$HOME/.fzf/bin/fzf" "$LOCAL_BIN/fzf"
        ok "fzf installed (git)"
        return 0
    fi

    warn "could not install fzf"
    return 1
}

# install ripgrep
install_ripgrep() {
    if command_exists rg; then
        ok "ripgrep already installed"
        return 0
    fi

    info "installing ripgrep..."

    local rg_version
    rg_version=$(curl -fsSL "https://api.github.com/repos/BurntSushi/ripgrep/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')

    local rg_url="https://github.com/BurntSushi/ripgrep/releases/download/${rg_version}/ripgrep-${rg_version}-${ARCH_SUFFIX}-unknown-linux-musl.tar.gz"

    if curl -fsSL "$rg_url" | tar xz -C "/tmp" 2>/dev/null; then
        cp "/tmp/ripgrep-${rg_version}-${ARCH_SUFFIX}-unknown-linux-musl/rg" "$LOCAL_BIN/"
        chmod +x "$LOCAL_BIN/rg"
        rm -rf "/tmp/ripgrep-${rg_version}-${ARCH_SUFFIX}-unknown-linux-musl"
        ok "ripgrep installed"
        return 0
    fi

    warn "could not install ripgrep"
    return 1
}

# install fd
install_fd() {
    if command_exists fd; then
        ok "fd already installed"
        return 0
    fi

    info "installing fd..."

    local fd_version
    fd_version=$(curl -fsSL "https://api.github.com/repos/sharkdp/fd/releases/latest" | grep '"tag_name"' | sed -E 's/.*"v?([^"]+)".*/\1/')

    local fd_url="https://github.com/sharkdp/fd/releases/download/v${fd_version}/fd-v${fd_version}-${ARCH_SUFFIX}-unknown-linux-musl.tar.gz"

    if curl -fsSL "$fd_url" | tar xz -C "/tmp" 2>/dev/null; then
        cp "/tmp/fd-v${fd_version}-${ARCH_SUFFIX}-unknown-linux-musl/fd" "$LOCAL_BIN/"
        chmod +x "$LOCAL_BIN/fd"
        rm -rf "/tmp/fd-v${fd_version}-${ARCH_SUFFIX}-unknown-linux-musl"
        ok "fd installed"
        return 0
    fi

    warn "could not install fd"
    return 1
}

# install lazygit
install_lazygit() {
    if command_exists lazygit; then
        ok "lazygit already installed"
        return 0
    fi

    info "installing lazygit..."

    local lg_version
    lg_version=$(curl -fsSL "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep '"tag_name"' | sed -E 's/.*"v?([^"]+)".*/\1/')

    local arch_name="$ARCH_SUFFIX"
    [[ "$arch_name" == "aarch64" ]] && arch_name="arm64"

    local lg_url="https://github.com/jesseduffield/lazygit/releases/download/v${lg_version}/lazygit_${lg_version}_Linux_${arch_name}.tar.gz"

    if curl -fsSL "$lg_url" | tar xz -C "$LOCAL_BIN" lazygit 2>/dev/null; then
        chmod +x "$LOCAL_BIN/lazygit"
        ok "lazygit installed"
        return 0
    fi

    warn "could not install lazygit"
    return 1
}

# install starship
install_starship() {
    if command_exists starship; then
        ok "starship already installed"
        return 0
    fi

    info "installing starship..."

    if curl -fsSL https://starship.rs/install.sh | sh -s -- --yes --bin-dir "$LOCAL_BIN" 2>/dev/null; then
        ok "starship installed"
        return 0
    fi

    warn "could not install starship"
    return 1
}

# install zoxide
install_zoxide() {
    if command_exists zoxide; then
        ok "zoxide already installed"
        return 0
    fi

    info "installing zoxide..."

    if curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh 2>/dev/null; then
        ok "zoxide installed"
        return 0
    fi

    warn "could not install zoxide"
    return 1
}

# install bat
install_bat() {
    if command_exists bat || command_exists batcat; then
        ok "bat already installed"
        return 0
    fi

    info "installing bat..."

    local bat_version
    bat_version=$(curl -fsSL "https://api.github.com/repos/sharkdp/bat/releases/latest" | grep '"tag_name"' | sed -E 's/.*"v?([^"]+)".*/\1/')

    local bat_url="https://github.com/sharkdp/bat/releases/download/v${bat_version}/bat-v${bat_version}-${ARCH_SUFFIX}-unknown-linux-musl.tar.gz"

    if curl -fsSL "$bat_url" | tar xz -C "/tmp" 2>/dev/null; then
        cp "/tmp/bat-v${bat_version}-${ARCH_SUFFIX}-unknown-linux-musl/bat" "$LOCAL_BIN/"
        chmod +x "$LOCAL_BIN/bat"
        rm -rf "/tmp/bat-v${bat_version}-${ARCH_SUFFIX}-unknown-linux-musl"
        ok "bat installed"
        return 0
    fi

    warn "could not install bat"
    return 1
}

# install delta
install_delta() {
    if command_exists delta; then
        ok "delta already installed"
        return 0
    fi

    info "installing delta..."

    local delta_version
    delta_version=$(curl -fsSL "https://api.github.com/repos/dandavison/delta/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')

    local delta_url="https://github.com/dandavison/delta/releases/download/${delta_version}/delta-${delta_version}-${ARCH_SUFFIX}-unknown-linux-musl.tar.gz"

    if curl -fsSL "$delta_url" | tar xz -C "/tmp" 2>/dev/null; then
        cp "/tmp/delta-${delta_version}-${ARCH_SUFFIX}-unknown-linux-musl/delta" "$LOCAL_BIN/"
        chmod +x "$LOCAL_BIN/delta"
        rm -rf "/tmp/delta-${delta_version}-${ARCH_SUFFIX}-unknown-linux-musl"
        ok "delta installed"
        return 0
    fi

    warn "could not install delta"
    return 1
}

# install eza
install_eza() {
    if command_exists eza; then
        ok "eza already installed"
        return 0
    fi

    info "installing eza..."

    local eza_version
    eza_version=$(curl -fsSL "https://api.github.com/repos/eza-community/eza/releases/latest" | grep '"tag_name"' | sed -E 's/.*"v?([^"]+)".*/\1/')

    local eza_url="https://github.com/eza-community/eza/releases/download/v${eza_version}/eza_${ARCH_SUFFIX}-unknown-linux-musl.tar.gz"

    if curl -fsSL "$eza_url" | tar xz -C "$LOCAL_BIN" 2>/dev/null; then
        chmod +x "$LOCAL_BIN/eza"
        ok "eza installed"
        return 0
    fi

    warn "could not install eza"
    return 1
}

# setup neovim python provider
setup_neovim_python() {
    if ! command_exists python3; then
        warn "python3 not found, skipping neovim python setup"
        return
    fi

    info "setting up neovim python provider..."

    local nvim_venv="$HOME/.local/share/nvim-python"

    if [[ ! -d "$nvim_venv" ]]; then
        python3 -m venv "$nvim_venv" 2>/dev/null || {
            warn "could not create venv, trying without venv module"
            return
        }
    fi

    "$nvim_venv/bin/pip" install --upgrade pip pynvim 2>/dev/null
    ok "neovim python provider ready"
}

# tool definitions: name, command, description
TOOLS=(
    "neovim:nvim:hyperextensible vim-based text editor"
    "fzf:fzf:command-line fuzzy finder"
    "ripgrep:rg:fast regex search tool (rg)"
    "fd:fd:fast find alternative"
    "lazygit:lazygit:terminal UI for git"
    "starship:starship:cross-shell prompt"
    "zoxide:zoxide:smarter cd command"
    "bat:bat:cat with syntax highlighting"
    "delta:delta:git diff viewer"
    "eza:eza:modern ls replacement"
)

ESSENTIALS=(1 2 3 4 5)

# check which tools are installed
check_tool_status() {
    local tool_def="$1"
    local cmd
    cmd=$(echo "$tool_def" | cut -d: -f2)

    # special case for bat (can be batcat on some systems)
    if [[ "$cmd" == "bat" ]]; then
        command_exists bat || command_exists batcat
    else
        command_exists "$cmd"
    fi
}

# get indices of tools to install based on selection
get_selected_indices() {
    local selection="$1"

    case "$selection" in
        N|NONE)
            echo ""
            ;;
        A|ALL)
            echo "1 2 3 4 5 6 7 8 9 10"
            ;;
        E|ESSENTIALS|"")
            echo "${ESSENTIALS[*]}"
            ;;
        *)
            echo "$selection" | tr ',' ' '
            ;;
    esac
}

show_menu() {
    {
        echo ""
        echo "Optional Tools (installed to ~/.local/bin)"
        echo ""

        local idx=1

        for tool_def in "${TOOLS[@]}"; do
            local name desc status_icon
            name=$(echo "$tool_def" | cut -d: -f1)
            desc=$(echo "$tool_def" | cut -d: -f3)

            if check_tool_status "$tool_def"; then
                status_icon="${GREEN}[installed]${NC}"
            else
                status_icon="${YELLOW}[not installed]${NC}"
            fi

            printf "  [%-2s] %-10s - %-40s %b\n" "$idx" "$name" "$desc" "$status_icon"
            ((idx++))
        done

        echo ""
        echo "  [A] All        - install everything"
        echo "  [E] Essentials - neovim, fzf, ripgrep, fd, lazygit"
        echo "  [N] None       - configs only, no tools"
        echo ""
    } >/dev/tty

    read -rp "Select (comma-separated numbers, A/E/N) [E]: " selection </dev/tty
    selection="${selection:-E}"
    selection=$(echo "$selection" | tr '[:lower:]' '[:upper:]')

    echo "$selection"
}

# check selected tools and prompt appropriately
check_and_prompt_install() {
    local selection="$1"
    local indices
    indices=$(get_selected_indices "$selection")

    [[ -z "$indices" ]] && { echo "SKIP"; return; }

    local installed_names=()
    local missing_names=()
    local missing_indices=()

    for idx in $indices; do
        local tool_def="${TOOLS[$((idx-1))]}"
        local name
        name=$(echo "$tool_def" | cut -d: -f1)

        if check_tool_status "$tool_def"; then
            installed_names+=("$name")
        else
            missing_names+=("$name")
            missing_indices+=("$idx")
        fi
    done

    # all installed
    if [[ ${#missing_names[@]} -eq 0 ]]; then
        {
            echo ""
            echo -e "${GREEN}Installed:${NC} ${installed_names[*]}"
            echo ""
        } >/dev/tty
        read -rp "All selected tools are already installed. Reinstall? [y/N]: " answer </dev/tty
        answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]')
        if [[ "$answer" == "y" || "$answer" == "yes" ]]; then
            echo "REINSTALL:$selection"
        else
            echo "SKIP"
        fi
        return
    fi

    # none installed
    if [[ ${#installed_names[@]} -eq 0 ]]; then
        echo "INSTALL:$selection"
        return
    fi

    # some installed, some missing
    {
        echo ""
        echo -e "${GREEN}Installed:${NC} ${installed_names[*]}"
        echo -e "${YELLOW}Not installed:${NC} ${missing_names[*]}"
        echo ""
    } >/dev/tty
    read -rp "Install missing tools? [Y/n]: " answer </dev/tty
    answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]')
    if [[ "$answer" == "n" || "$answer" == "no" ]]; then
        echo "SKIP"
    else
        echo "INSTALL_MISSING:${missing_indices[*]}"
    fi
}

# install tool by index (1-10)
install_tool_by_index() {
    local idx="$1"

    case "$idx" in
        1) install_neovim ;;
        2) install_fzf ;;
        3) install_ripgrep ;;
        4) install_fd ;;
        5) install_lazygit ;;
        6) install_starship ;;
        7) install_zoxide ;;
        8) install_bat ;;
        9) install_delta ;;
        10) install_eza ;;
    esac
}

install_selected_tools() {
    local action="$1"

    case "$action" in
        SKIP)
            info "skipping tool installation"
            return
            ;;
        INSTALL:*|REINSTALL:*)
            local selection="${action#*:}"
            local indices
            indices=$(get_selected_indices "$selection")

            for idx in $indices; do
                install_tool_by_index "$idx"
            done
            ;;
        INSTALL_MISSING:*)
            local indices="${action#INSTALL_MISSING:}"
            for idx in $indices; do
                install_tool_by_index "$idx"
            done
            ;;
    esac
}

show_summary() {
    echo ""
    echo -e "${GREEN}Installation Complete${NC}"
    echo ""
    echo "  Configs linked from: $DOTFILES_ROOT/config"
    echo "    ~/.config/nvim      ~/.bashrc"
    echo "    ~/.config/tmux      ~/.aliases"
    echo "    ~/.config/lazygit   ~/.config/starship.toml"
    echo ""
    echo "  Tools: ~/.local/bin"
    echo ""
    echo "  Local overrides (not tracked):"
    echo "    ~/.bashrc.local     - machine-specific shell config"
    echo "    ~/.gitconfig.local  - machine-specific git config"
    echo ""
    echo -e "  ${YELLOW}NEXT STEPS:${NC}"
    echo "    1. source ~/.bashrc   (or restart shell)"
    echo "    2. nvim               (plugins auto-install on first run)"
    echo "    3. :checkhealth       (verify setup)"
    echo ""
}

main() {
    banner

    ensure_dirs
    setup_path

    # determine dotfiles location
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    if [[ -f "$script_dir/install.sh" && -d "$script_dir/config" ]]; then
        DOTFILES_ROOT="$script_dir"
        info "using local dotfiles at $DOTFILES_ROOT"
    else
        clone_dotfiles
    fi

    cd "$DOTFILES_ROOT"

    # link configs
    link_configs

    # tool selection
    selection=$(show_menu)
    action=$(check_and_prompt_install "$selection")
    install_selected_tools "$action"

    # python provider
    setup_neovim_python

    show_summary
}

main "$@"
