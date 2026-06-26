# mbo_server_configs

Dev environment setup for MBO machines: Windows workstations and the Rockefeller HPC.

## install — windows

Admin PowerShell:

```powershell
iex (irm https://raw.githubusercontent.com/MillerBrainObservatory/mbo_server_configs/master/install.ps1)
```

or:

```powershell
git clone https://github.com/MillerBrainObservatory/mbo_server_configs.git
cd mbo_server_configs
.\install.ps1
```

### what it does (windows)

- IDEs: VS Code, PyCharm Community, Neovim
- terminal: PowerShell Core (default), JetBrainsMono Nerd Font + FiraCode, Windows Terminal config
- tools: git, lazygit, fd, ripgrep, fzf, zoxide, starship, bat, delta, eza
- python (uv): uv, python 3.12, ruff, ty, pynvim
- configs symlinked from `config/`

post-install: close and reopen Windows Terminal, then run `nvim` (`:checkhealth` to verify).

requires Windows 10/11, admin privileges, winget.

### shell (powershell profile)

History prefix search: type a prefix (e.g. `uv run mbo`), press Up/Down to step through past commands that start with it. Inline grey suggestion comes from history; Right/End accepts it.

- aliases: `lg` lazygit, `vim`/`vi` nvim, `g` git
- listing: `ls` `lsv` `la` `lt` (eza); `cat` (bat)
- navigation: `..` `...`; `cd <name>` smart jump (zoxide); `mbospace` → `Y:`, `s1data` → `X:`
- git: `gs ga gc gp gl gd gco glog`
- `mbohelp` git / gpu / uv / pytorch cheatsheet
- starship prompt, fastfetch on startup

profile: `config/powershell/profile.ps1` (symlinked to `Documents/PowerShell/Microsoft.PowerShell_profile.ps1`).

pwsh as default SSH shell:

```powershell
New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value "C:\Program Files\PowerShell\7\pwsh.exe" -PropertyType String -Force
```

## hpc (rockefeller)

Shared software (CLI tools, neovim, `mbo_utilities` venv, repos) lives under `/lustre/fs8/mbo/scratch/mbo_soft`, installed separately. Nothing to install per user — just source it.

### new user

Run once (you must be in the `mbo` group — check with `groups`):

```bash
grep -q 'config/hpc/mbo.sh' ~/.bashrc || \
  echo 'source /lustre/fs8/mbo/scratch/mbo_soft/repos/mbo_server_configs/config/hpc/mbo.sh' >> ~/.bashrc
mkdir -p /lustre/fs8/mbo/scratch/$USER
exec bash
```

Keep that line at the end of `~/.bashrc` if you have a prompt framework (oh-my-bash, etc.).

### what it does (hpc)

- PATH: shared bin (`$MBO_BIN`) + neovim
- locations: `$MBO_ROOT` `$MBO_SCRATCH` `$MBO_SOFT` `$MBO_DATA` `$MBO_USER`; `cdsoft cddata cdlbm cdlsm cdscratch cdme cdrepos`
- python: `mbo`, `mbo-activate`, `mbo-run <cmd>` (venv at `$MBO_ENV`)
- transfer: `mbo-stage <path-under-mbo_data> [dest]`, `mbo-pull`, `mbo-push`
- slurm: `mbo-gpu [part] [time] [n]`, `mbo-cpu`, `mbo-jobs`, `mbo-gpus`; template `config/hpc/job.sbatch.template`
- uv cache/pythons on your scratch (`$MBO_USER/.uv`)

paths live in `config/hpc/env.sh` — change `MBO_ROOT` to move filesystems.

### environment reference

Sourcing `mbo.sh` exports (`config/hpc/env.sh`):

| Variable | Value | Points to |
|---|---|---|
| `MBO_ROOT` | `/lustre/fs8/mbo` | lab root — change this only to move filesystems |
| `MBO_SCRATCH` | `$MBO_ROOT/scratch` | scratch root |
| `MBO_STORE` | `$MBO_ROOT/store` | long-term store |
| `MBO_SOFT` | `$MBO_SCRATCH/mbo_soft` | shared software root |
| `MBO_BIN` | `$MBO_SOFT/bin` | shared bin (on `PATH`) |
| `MBO_REPOS` | `$MBO_SOFT/repos` | shared repos |
| `MBO_NVIM` | `$MBO_SOFT/neovim` | neovim install |
| `MBO_ENVS` | `$MBO_SOFT/envs` | shared venvs dir |
| `MBO_ENV` | `$MBO_ENVS/mbo` | default shared venv |
| `MBO_DATA` | `$MBO_SCRATCH/mbo_data` | data root |
| `MBO_LBM` | `$MBO_DATA/lbm` | LBM data |
| `MBO_LSM` | `$MBO_DATA/lsm` | LSM data |
| `MBO_USER` | `$MBO_SCRATCH/$USER` | your personal scratch (override: set `MBO_USER` first) |

Also sets `UV_LINK_MODE=hardlink`, `UV_CACHE_DIR=$MBO_USER/.uv/cache`, `UV_PYTHON_INSTALL_DIR=$MBO_USER/.uv/python`.

## structure

```
mbo_server_configs/
├── install.ps1         # windows
├── install.sh          # generic linux
├── config/
│   ├── nvim/
│   ├── tmux/
│   ├── lazygit/
│   ├── hpc/
│   │   ├── env.sh      # locations + uv env (single source of truth)
│   │   ├── mbo.sh      # shell setup, aliases, helpers (sources env.sh)
│   │   └── job.sbatch.template
│   ├── starship.toml
│   ├── vimrc
│   └── btop/
└── README.md
```
