# mbo_server_configs

admin setup script for configuring windows machines for lab users.
run once on a new user's machine to set up their dev environment.

## quick install

**requires admin powershell:**

```powershell
iex (irm https://raw.githubusercontent.com/MillerBrainObservatory/mbo_server_configs/master/install.ps1)
```

or clone and run:

```powershell
git clone https://github.com/MillerBrainObservatory/mbo_server_configs.git
cd mbo_server_configs
.\install.ps1
```

## what it does

### IDEs
- **VS Code** - primary editor
- **PyCharm Community** - python IDE
- **Neovim** - terminal editor with LSP, Telescope, Treesitter

### terminal setup
- installs **PowerShell Core** (pwsh.exe) and sets as default
- **hides legacy Windows PowerShell** from terminal
- installs **JetBrainsMono Nerd Font** and sets as terminal font
- installs **FiraCode** font
- configures Windows Terminal settings automatically

### dev tools (via winget)
- git, lazygit
- fd, ripgrep, fzf, zoxide
- starship (prompt), bat, delta, eza

### python (via uv)
- **uv** - fast python package manager
- **python 3.12** - managed by uv (not system python)
- **ruff** - fast linter
- **ty** - type checker
- neovim python provider (pynvim)
- disables Windows Store python aliases

### configs
symlinked to `~/.mbo_server_configs/config/`:
- neovim (`%LOCALAPPDATA%\nvim`)
- lazygit (`~/.config/lazygit`)
- starship (`~/.config/starship.toml`)
- vim (`~/.vimrc`)

### powershell profile
creates profile with:
- aliases: `lg`, `vim`, `vi`, `g`, `ll`, `la`
- git shortcuts: `gs`, `ga`, `gc`, `gp`, `gl`, `gd`, `gco`, `gb`, `glog`
- starship prompt
- zoxide (smart cd)


### Set powershell as default SSH prompt
New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value "C:\Program Files\PowerShell\7\pwsh.exe" -PropertyType String -Force

DefaultShell : C:\Program Files\PowerShell\7\pwsh.exe
PSPath       : Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\SOFTWARE\OpenSSH
PSParentPath : Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\SOFTWARE
PSChildName  : OpenSSH
PSDrive      : HKLM
PSProvider   : Microsoft.PowerShell.Core\Registry

## structure

```
mbo_server_configs/
├── install.ps1         # windows admin setup script
├── install.sh          # linux server script (optional)
├── config/
│   ├── nvim/           # neovim config
│   │   └── init.lua
│   ├── tmux/           # tmux config (linux)
│   │   └── tmux.conf
│   ├── lazygit/
│   │   └── config.yml
│   ├── starship.toml
│   ├── vimrc
│   └── btop/
└── README.md
```

## post-install

1. **close and reopen Windows Terminal** (required)
2. terminal should now open pwsh with nerd font
3. legacy Windows PowerShell is hidden
4. run `nvim` - plugins auto-install on first launch
5. run `:checkhealth` in nvim to verify

## requirements

- windows 10/11
- **admin privileges** (required for symlinks, fonts, terminal config)
- winget (App Installer from Microsoft Store)
