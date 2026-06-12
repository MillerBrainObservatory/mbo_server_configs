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
