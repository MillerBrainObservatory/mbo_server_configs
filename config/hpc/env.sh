#!/usr/bin/env bash
# single source of truth for mbo HPC locations + uv state.
# sourced by config/hpc/mbo.sh.
#
# moving filesystems (e.g. /lustre/fs8 -> /lustre/fsN)? change MBO_ROOT only.

export MBO_ROOT="${MBO_ROOT:-/lustre/fs8/mbo}"
export MBO_SCRATCH="$MBO_ROOT/scratch"
export MBO_STORE="$MBO_ROOT/store"

export MBO_SOFT="$MBO_SCRATCH/mbo_soft"
export MBO_BIN="$MBO_SOFT/bin"
export MBO_REPOS="$MBO_SOFT/repos"
export MBO_NVIM="$MBO_SOFT/neovim"
export MBO_ENVS="$MBO_SOFT/envs"
export MBO_ENV="$MBO_ENVS/mbo"

export MBO_DATA="$MBO_SCRATCH/mbo_data"
export MBO_LBM="$MBO_DATA/lbm"
export MBO_LSM="$MBO_DATA/lsm"

# your scratch: honor an existing ~/scratch, resolved to its real path so old
# fs4 symlinks land on the current fs8; else scratch/$USER. override: set first.
if [ -z "${MBO_USER:-}" ]; then
    if [ -e "$HOME/scratch" ]; then
        MBO_USER="$(cd "$HOME/scratch" 2>/dev/null && pwd -P || echo "$HOME/scratch")"
    else
        MBO_USER="$MBO_SCRATCH/${USER:-$(id -un)}"
    fi
fi
export MBO_USER

# uv: home is 40 GB with strict inode limits, so cache + managed pythons live on
# your scratch. cache and target differ -> copy instead of hardlink.
export UV_LINK_MODE=copy
export UV_CACHE_DIR="${UV_CACHE_DIR:-$MBO_USER/.uv/cache}"
export UV_PYTHON_INSTALL_DIR="${UV_PYTHON_INSTALL_DIR:-$MBO_USER/.uv/python}"
