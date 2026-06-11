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
- configs symlinked from `config/`; powershell profile with aliases + git shortcuts

post-install: close and reopen Windows Terminal, then run `nvim` (`:checkhealth` to verify).

requires Windows 10/11, admin privileges, winget.

pwsh as default SSH shell:

```powershell
New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value "C:\Program Files\PowerShell\7\pwsh.exe" -PropertyType String -Force
```

## install — hpc (rockefeller)

Shared stack lives under `/lustre/fs8/mbo/scratch/mbo_soft`.

user (lab member):

```bash
/lustre/fs8/mbo/scratch/mbo_soft/repos/mbo_server_configs/install_hpc.sh
source ~/.bashrc
```

admin (as mbo_soft):

```bash
cd /lustre/fs8/mbo/scratch/mbo_soft/repos/mbo_server_configs
./install_hpc.sh --admin               # pins mbo_utilities v3.2.0
./install_hpc.sh --admin --ref v3.2.0  # other tag
```

### what it does (hpc)

- admin: CLI tools + neovim to `mbo_soft/bin`, shared `mbo_utilities` venv at `mbo_soft/envs/mbo`, `mbo` cli on PATH
- user: config symlinks, `~/scratch` link, kitty terminfo, `config/hpc/mbo.sh` sourced from `~/.bashrc`
- locations: `cdsoft cddata cdlbm cdlsm cdscratch cdrepos`, `$MBO_*` vars
- python: `mbo`, `mbo-activate`, `mbo-run <cmd>`
- transfer: `mbo-stage <path-under-mbo_data> [dest]`, `mbo-pull`, `mbo-push`
- slurm: `gpu [part] [time] [n]`, `cpu`, `mbo-jobs`, `mbo-gpus`; template `config/hpc/job.sbatch.template`

paths live in `config/hpc/env.sh` — change `MBO_ROOT` to move filesystems.

## structure

```
mbo_server_configs/
├── install.ps1         # windows
├── install.sh          # generic linux
├── install_hpc.sh      # rockefeller hpc (user + admin)
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
