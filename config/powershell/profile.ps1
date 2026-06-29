# MBO PowerShell Profile

# path
$env:Path = "$env:USERPROFILE\.local\bin;$env:Path"

# PSReadLine: history search + inline predictions
if (Get-Module -ListAvailable -Name PSReadLine) {
    Set-PSReadLineOption -PredictionSource History
    Set-PSReadLineOption -PredictionViewStyle InlineView
    Set-PSReadLineOption -HistorySearchCursorMovesToEnd
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
}

# aliases
Set-Alias -Name lg -Value lazygit -ErrorAction SilentlyContinue
Set-Alias -Name vim -Value nvim -ErrorAction SilentlyContinue
Set-Alias -Name vi -Value nvim -ErrorAction SilentlyContinue
Set-Alias -Name g -Value git -ErrorAction SilentlyContinue

# ls -> eza
Remove-Item Alias:ls -Force -ErrorAction SilentlyContinue
function ls { eza -l --icons --group-directories-first --no-permissions --no-time --no-user @args }
function lsv { eza -l --icons --group-directories-first @args }
function la { eza -la --icons --group-directories-first --no-permissions --no-time --no-user @args }
function lt { eza -T --icons --group-directories-first @args }

# cat -> bat
Remove-Item Alias:cat -Force -ErrorAction SilentlyContinue
function cat { bat --paging=never @args }

# navigation
function .. { Set-Location .. }
function ... { Set-Location ..\.. }

# directory shortcuts (skip if drive not mapped)
function mbospace { if (Test-Path Y:\) { Set-Location Y:\ } else { Write-Host "Y: not mapped" -ForegroundColor Yellow } }
function s1data { if (Test-Path X:\) { Set-Location X:\ } else { Write-Host "X: not mapped" -ForegroundColor Yellow } }

# git shortcuts
function gs { git status @args }
function ga { git add @args }
function gc { git commit @args }
function gp { git push @args }
function gl { git pull @args }
function gd { git diff @args }
function gco { git checkout @args }
function glog { git log --oneline --graph --decorate -20 @args }

# mbohelp: full cheatsheet (mbo / lsp / uv / pytorch / gpu / git / shell)
function mbohelp {
    Write-Host ""
    Write-Host "  env" -ForegroundColor Cyan
    Write-Host "    .venv\Scripts\Activate.ps1   activate the venv (Windows)" -ForegroundColor Gray
    Write-Host "    source .venv/bin/activate    activate the venv (Unix)" -ForegroundColor Gray
    Write-Host "    deactivate                   exit the venv" -ForegroundColor Gray
    Write-Host "    (activated: drop the uv run prefix; else cd to the .venv folder, then uv run)" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  mbo / viewer" -ForegroundColor Cyan
    Write-Host "    uv run mbo                       open the viewer (file dialog)" -ForegroundColor Gray
    Write-Host "    uv run mbo <path>                open a file or folder" -ForegroundColor Gray
    Write-Host "    uv run mbo <path> --metadata     print metadata only" -ForegroundColor Gray
    Write-Host "    uv run mbo info <path>           shape / dtype / dims" -ForegroundColor Gray
    Write-Host "    uv run mbo convert <in> <out>    convert tiff / zarr / h5 / bin" -ForegroundColor Gray
    Write-Host "    uv run mbo formats               list supported formats" -ForegroundColor Gray
    Write-Host "    uv run mbo init [path]           create starter notebooks" -ForegroundColor Gray
    Write-Host "    uv run mbo gpu                   list GPUs" -ForegroundColor Gray
    Write-Host "    uv run mbo shortcut              desktop icon for this env" -ForegroundColor Gray
    Write-Host "    uv run mbo hpc <cmd>             submit SLURM jobs" -ForegroundColor Gray
    Write-Host "    uv run mbo --check-install       verify the install" -ForegroundColor Gray
    Write-Host "    uv run jupyter lab .             notebook in current dir" -ForegroundColor Gray
    Write-Host "    uv run ipython                   interactive shell" -ForegroundColor Gray
    Write-Host "    uv run isoview init [path]       scaffold isoview scripts" -ForegroundColor Gray
    Write-Host "    uv run isoview info <path>       isoview metadata + config" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  lsp / suite2p" -ForegroundColor Cyan
    Write-Host "    uv run lsp <in> <out>                       run the pipeline" -ForegroundColor Gray
    Write-Host "    uv run lsp <in> <out> --planes 1 2 3        specific z-planes (1-indexed)" -ForegroundColor Gray
    Write-Host "    uv run lsp <in> <out> --num-timepoints 500  quick test, first N frames" -ForegroundColor Gray
    Write-Host "    uv run lsp <in> <out> --rastermap           add rastermap embedding" -ForegroundColor Gray
    Write-Host "    uv run lsp <in> <out> --ops-file ops.json   start from saved ops" -ForegroundColor Gray
    Write-Host "    uv run lsp <in> <out> --algorithm cellpose --diameter 8  cellpose detection" -ForegroundColor Gray
    Write-Host "    uv run lsp --list-ops                       list all params + defaults" -ForegroundColor Gray
    Write-Host "    uv run suite2p                              suite2p GUI" -ForegroundColor Gray
    Write-Host "    (flags use dashes, not underscores)" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  uv / python" -ForegroundColor Cyan
    Write-Host "    uv pip install .                            install current project" -ForegroundColor Gray
    Write-Host "    uv pip install ../mbo_utilities             a sibling repo" -ForegroundColor Gray
    Write-Host "    uv pip install ../LBM-Suite2p-Python[all]   sibling repo, all extras" -ForegroundColor Gray
    Write-Host "    uv pip install .[all]                       current project, all extras" -ForegroundColor Gray
    Write-Host "    uv pip list                                 packages in this env" -ForegroundColor Gray
    Write-Host "    uv pip show torch                           show one package" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  pytorch" -ForegroundColor Cyan
    Write-Host "    uv pip uninstall torch torchvision          remove existing first" -ForegroundColor Gray
    Write-Host "    uv pip install torch torchvision --index-url https://download.pytorch.org/whl/cu126" -ForegroundColor Gray
    Write-Host "    uv pip install cupy-cuda12x                 cupy arrays (cuda 12.x)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  gpu / cuda" -ForegroundColor Cyan
    Write-Host "    nvidia-smi                GPU status, memory, processes" -ForegroundColor Gray
    Write-Host "    nvidia-smi --query-gpu=utilization.gpu,memory.used --format=csv -l 1  watch util + mem" -ForegroundColor Gray
    Write-Host "    nvcc --version            CUDA toolkit version" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  git" -ForegroundColor Cyan
    Write-Host "    git pull                  update current branch" -ForegroundColor Gray
    Write-Host "    git push                  upload commits" -ForegroundColor Gray
    Write-Host "    git switch <branch>       change branch (or git checkout)" -ForegroundColor Gray
    Write-Host "    git merge <branch>        merge a branch into current" -ForegroundColor Gray
    Write-Host "    git clone <url>           copy a repo" -ForegroundColor Gray
    Write-Host "    gs ga gc gp gl gd gco glog   status add commit push pull diff checkout log" -ForegroundColor Gray
    Write-Host "    lg                        lazygit" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  shell / files" -ForegroundColor Cyan
    Write-Host "    ls / lsv / la / lt        list / long / all / tree (eza)" -ForegroundColor Gray
    Write-Host "    cat <file>                view a file (bat)" -ForegroundColor Gray
    Write-Host "    mkdir <dir>               create a directory (nested ok)" -ForegroundColor Gray
    Write-Host "    .. / ...                  up one / two dirs" -ForegroundColor Gray
    Write-Host "    mbospace / s1data         Y: / X:" -ForegroundColor Gray
    Write-Host "    code .                    open folder in VS Code" -ForegroundColor Gray
    Write-Host "    nvim                      editor" -ForegroundColor Gray
    Write-Host ""
}

# starship prompt
if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (&starship init powershell)
}

# zoxide (smart cd) - must be last, after starship and any other prompt hooks
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell --cmd cd | Out-String) })
}

# startup: fastfetch + quick reference (nav / git / uv)
if (Get-Command fastfetch -ErrorAction SilentlyContinue) {
    fastfetch
    Write-Host ""
    Write-Host "  nav" -ForegroundColor Cyan
    Write-Host "    cd <name>     smart jump (zoxide)" -ForegroundColor Gray
    Write-Host "    cd ~          home" -ForegroundColor Gray
    Write-Host "    cd ..         up one" -ForegroundColor Gray
    Write-Host "    cd ../repo    sibling repo" -ForegroundColor Gray
    Write-Host "    ls / lt       list / tree" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  git" -ForegroundColor Cyan
    Write-Host "    gs            status" -ForegroundColor Gray
    Write-Host "    git pull      update branch" -ForegroundColor Gray
    Write-Host "    git push      upload commits" -ForegroundColor Gray
    Write-Host "    lg            lazygit" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  uv" -ForegroundColor Cyan
    Write-Host "    uv pip install .             install project" -ForegroundColor Gray
    Write-Host "    .venv\Scripts\Activate.ps1   activate venv" -ForegroundColor Gray
    Write-Host "    uv pip list                  list packages" -ForegroundColor Gray
    Write-Host ""
    Write-Host "    mbohelp                      full cheatsheet" -ForegroundColor Gray
    Write-Host ""
}
