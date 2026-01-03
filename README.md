# mbo_server_configs

minimal configs for linux servers and scientific computing environments.
no sudo required - everything installs to `~/.local`.

## quick install

```bash
curl -fsSL https://raw.githubusercontent.com/MillerBrainObservatory/mbo_server_configs/main/install.sh | bash
```

or clone and run:

```bash
git clone https://github.com/MillerBrainObservatory/mbo_server_configs.git ~/.mbo_server_configs
cd ~/.mbo_server_configs && ./install.sh
```

## what's included

### configs
- **neovim** - minimal kickstart-based config with lsp, telescope, treesitter
- **tmux** - sensible defaults, vim navigation, tpm plugin manager
- **bash** - portable bashrc with starship prompt fallback
- **lazygit** - terminal git ui config
- **starship** - cross-shell prompt (nerd font symbols)

### optional tools (prebuilt binaries)
installed to `~/.local/bin`, no package manager needed:

| tool | description |
|------|-------------|
| neovim | text editor |
| fzf | fuzzy finder |
| ripgrep | fast grep |
| fd | fast find |
| lazygit | git tui |
| starship | prompt |
| zoxide | smart cd |
| bat | cat with syntax highlighting |
| delta | git diff viewer |
| eza | modern ls |

## customization

machine-specific configs (not tracked):
- `~/.bashrc.local` - local shell customizations
- `~/.gitconfig.local` - local git config

## structure

```
mbo_server_configs/
├── install.sh          # main installer
├── config/
│   ├── bashrc          # shell config
│   ├── aliases         # shell aliases
│   ├── vimrc           # vim config
│   ├── starship.toml   # prompt config
│   ├── nvim/           # neovim config
│   │   └── init.lua
│   ├── tmux/           # tmux config
│   │   └── tmux.conf
│   ├── lazygit/        # lazygit config
│   │   └── config.yml
│   └── btop/           # btop themes
└── README.md
```

## post-install

1. restart shell or `source ~/.bashrc`
2. open `nvim` - plugins auto-install
3. run `:checkhealth` to verify

## requirements

- git
- curl
- bash
