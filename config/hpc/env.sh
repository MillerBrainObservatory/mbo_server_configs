#!/usr/bin/env bash
# single source of truth for mbo HPC locations + uv state.
# sourced by install_hpc.sh and by config/hpc/mbo.sh (no PATH/aliases here).
#
# moving filesystems (e.g. /lustre/fs8 -> /lustre/fsN)? change MBO_ROOT only;
# everything else derives from it.

export MBO_ROOT="${MBO_ROOT:-/lustre/fs8/mbo/scratch}"

export MBO_SOFT="$MBO_ROOT/mbo_soft"
export MBO_BIN="$MBO_SOFT/bin"
export MBO_REPOS="$MBO_SOFT/repos"
export MBO_NVIM="$MBO_SOFT/neovim"
export MBO_ENVS="$MBO_SOFT/envs"
export MBO_ENV="$MBO_ENVS/mbo"

export MBO_DATA="$MBO_ROOT/mbo_data"
export MBO_LBM="$MBO_DATA/lbm"
export MBO_LSM="$MBO_DATA/lsm"

export MBO_SCRATCH="$MBO_ROOT/${USER:-$(id -un)}"

# uv: home is 40 GB with strict inode limits, so cache + managed pythons live on
# scratch. cache and target are different filesystems, so hardlinks fail -> copy.
export UV_LINK_MODE=copy
export UV_CACHE_DIR="${UV_CACHE_DIR:-$MBO_SCRATCH/.uv/cache}"
export UV_PYTHON_INSTALL_DIR="${UV_PYTHON_INSTALL_DIR:-$MBO_SCRATCH/.uv/python}"
