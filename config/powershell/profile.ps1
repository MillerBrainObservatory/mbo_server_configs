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

# mbohelp: git / gpu / uv / pytorch reference
function mbohelp {
    Write-Host ""
    Write-Host "  git" -ForegroundColor Cyan
    Write-Host "    git pull                 update current branch" -ForegroundColor Gray
    Write-Host "    git switch <branch>      change branch (or: git checkout)" -ForegroundColor Gray
    Write-Host "    git push                 upload commits" -ForegroundColor Gray
    Write-Host "    git clone <url>          copy a repo" -ForegroundColor Gray
    Write-Host "    git merge <branch>       merge a branch into current" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  gpu / cuda" -ForegroundColor Cyan
    Write-Host "    nvidia-smi               GPU status, memory, processes" -ForegroundColor Gray
    Write-Host "    nvcc --version           CUDA toolkit version" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  uv (python)" -ForegroundColor Cyan
    Write-Host "    uv pip install .                          install current project" -ForegroundColor Gray
    Write-Host "    uv pip install ../mbo_utilities           install a sibling repo" -ForegroundColor Gray
    Write-Host "    uv pip install ../LBM-Suite2p-Python[all] sibling repo, all extras" -ForegroundColor Gray
    Write-Host "    uv pip install .[all]                     current project, all extras" -ForegroundColor Gray
    Write-Host "    uv pip list                               packages in this env" -ForegroundColor Gray
    Write-Host "    uv pip show torch                         show one package" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  pytorch / cuda" -ForegroundColor Cyan
    Write-Host "    uv pip install torch torchvision --index-url https://download.pytorch.org/whl/cu126" -ForegroundColor Gray
    Write-Host "    uv pip install cupy-cuda12x" -ForegroundColor Gray
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

# startup: fastfetch + compact quick reference
if (Get-Command fastfetch -ErrorAction SilentlyContinue) {
    fastfetch
    Write-Host ""
    Write-Host "  quick reference" -ForegroundColor Cyan
    Write-Host "    ls / lt / la   list, tree, or all" -ForegroundColor Gray
    Write-Host "    cd <name>      smart jump (zoxide)" -ForegroundColor Gray
    Write-Host "    code .         open folder in VS Code" -ForegroundColor Gray
    Write-Host "    lg             lazygit" -ForegroundColor Gray
    Write-Host "    git pull/push  sync this repo" -ForegroundColor Gray
    Write-Host "    nvim           editor" -ForegroundColor Gray
    Write-Host "    mbohelp        git / uv / gpu cheatsheet" -ForegroundColor Gray
    Write-Host ""
}
