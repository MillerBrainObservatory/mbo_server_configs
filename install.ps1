# MBO Server Configs - Windows Admin Setup
# Target: Windows Server 2022, Windows 11
#
# Downloads and installs:
#   - PowerShell Core: latest MSI from GitHub (PowerShell/PowerShell)
#   - CLI tools: latest releases from GitHub (lazygit, fd, ripgrep, fzf, bat, delta, eza, zoxide, starship, fastfetch)
#   - IDEs: VS Code (pwsh terminal, ~/mbo/envs python path), Neovim (GitHub)
#   - Python: uv package manager (GitHub), Python 3.12, ruff, ty
#   - Fonts: JetBrainsMono Nerd Font, FiraCode (GitHub)
#
# Run as Administrator:
#   .\install.ps1

#Requires -RunAsAdministrator
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# explicit admin check
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[ERROR] This script must be run as Administrator" -ForegroundColor Red
    exit 1
}

# config
$REPO_URL = "https://github.com/MillerBrainObservatory/mbo_server_configs"
$CONFIG_ROOT = "$env:USERPROFILE\.mbo_server_configs"
$LOCAL_BIN = "$env:USERPROFILE\.local\bin"
$TOOLS_DIR = "$env:LOCALAPPDATA\Programs"

# colors
function Write-Info { Write-Host "[INFO] $args" -ForegroundColor Blue }
function Write-Ok { Write-Host "[OK] $args" -ForegroundColor Green }
function Write-Warn { Write-Host "[WARN] $args" -ForegroundColor Yellow }
function Write-Err { Write-Host "[ERROR] $args" -ForegroundColor Red }

function Show-Banner {
    Write-Host ""
    Write-Host "  __  __ ___  ___  " -ForegroundColor Cyan
    Write-Host " |  \/  | _ )/ _ \ " -ForegroundColor Cyan
    Write-Host " | |\/| | _ \ (_) |" -ForegroundColor Cyan
    Write-Host " |_|  |_|___/\___/ " -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Miller Brain Observatory - Server Setup" -ForegroundColor White
    Write-Host ""
}

function Test-CommandExists {
    param([string]$Command)
    $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function Add-ToPath {
    param([string]$Path)
    $currentPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
    if ($currentPath -notlike "*$Path*") {
        [System.Environment]::SetEnvironmentVariable("Path", "$Path;$currentPath", "User")
        $env:Path = "$Path;$env:Path"
        Write-Info "added $Path to PATH"
    }
}

function Get-GitHubLatestRelease {
    param([string]$Repo)
    $url = "https://api.github.com/repos/$Repo/releases/latest"
    try {
        $release = Invoke-RestMethod -Uri $url -Headers @{ "User-Agent" = "PowerShell" }
        return $release
    } catch {
        Write-Warn "failed to get latest release for $Repo"
        return $null
    }
}

function Ensure-Directories {
    @($LOCAL_BIN, $TOOLS_DIR, "$env:USERPROFILE\.config") | ForEach-Object {
        if (-not (Test-Path $_)) {
            New-Item -ItemType Directory -Path $_ -Force | Out-Null
        }
    }
    Add-ToPath $LOCAL_BIN
}

# ============================================================================
# POWERSHELL CORE
# ============================================================================

function Install-PowerShellCore {
    Write-Info "checking powershell core..."

    if (Test-CommandExists "pwsh") {
        $version = pwsh -NoProfile -Command '$PSVersionTable.PSVersion.ToString()'
        Write-Ok "pwsh already installed: $version"
        return
    }

    Write-Info "installing powershell core..."

    # get latest release
    $release = Get-GitHubLatestRelease "PowerShell/PowerShell"
    if (-not $release) {
        Write-Warn "could not get pwsh release info, using fallback"
        $msiUrl = "https://github.com/PowerShell/PowerShell/releases/download/v7.4.6/PowerShell-7.4.6-win-x64.msi"
    } else {
        $msiAsset = $release.assets | Where-Object { $_.name -match "win-x64\.msi$" -and $_.name -notmatch "arm" } | Select-Object -First 1
        $msiUrl = $msiAsset.browser_download_url
    }

    $msiPath = "$env:TEMP\pwsh-install.msi"
    Write-Info "downloading from $msiUrl"

    try {
        Invoke-WebRequest -Uri $msiUrl -OutFile $msiPath -UseBasicParsing
    } catch {
        # fallback to .NET WebClient
        Write-Info "trying alternate download method..."
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($msiUrl, $msiPath)
    }

    Write-Info "installing pwsh..."
    $args = "/i `"$msiPath`" /quiet ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ADD_FILE_CONTEXT_MENU_RUNPOWERSHELL=1 REGISTER_MANIFEST=1 USE_MU=1 ENABLE_MU=1 ADD_PATH=1"
    Start-Process msiexec.exe -ArgumentList $args -Wait -NoNewWindow

    Remove-Item $msiPath -Force -ErrorAction SilentlyContinue

    # refresh path and add pwsh explicitly
    $pwshDir = "$env:ProgramFiles\PowerShell\7"
    $env:Path = "$pwshDir;$env:Path"
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

    if (Test-Path "$pwshDir\pwsh.exe") {
        Write-Ok "pwsh installed"
    } else {
        Write-Warn "pwsh may require terminal restart"
    }
}

# ============================================================================
# FONTS
# ============================================================================

function Test-FontInstalled {
    param([string]$FontName)
    $fontsDir = "$env:WINDIR\Fonts"
    $userFontsDir = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
    $regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"

    # check registry (most reliable)
    $regFonts = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
    if ($regFonts.PSObject.Properties.Name -match [regex]::Escape($FontName)) {
        return $true
    }

    # check font directories
    if (Test-Path "$fontsDir\$FontName" -ErrorAction SilentlyContinue) { return $true }
    if (Test-Path "$userFontsDir\$FontName" -ErrorAction SilentlyContinue) { return $true }

    return $false
}

function Install-Fonts {
    Write-Info "installing fonts..."

    # JetBrainsMono Nerd Font
    $jbFonts = @(
        "JetBrainsMonoNerdFont-Regular.ttf",
        "JetBrainsMonoNerdFont-Bold.ttf",
        "JetBrainsMonoNerdFont-Italic.ttf",
        "JetBrainsMonoNerdFont-BoldItalic.ttf"
    )

    $jbMissing = $jbFonts | Where-Object { -not (Test-FontInstalled $_) }

    if (-not $jbMissing) {
        Write-Ok "JetBrainsMono Nerd Font already installed"
    } else {
        Write-Info "downloading JetBrainsMono Nerd Font..."
        $zipUrl = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
        $zipPath = "$env:TEMP\JetBrainsMono.zip"
        $extractPath = "$env:TEMP\JetBrainsMono"

        try {
            Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
            Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

            $shell = New-Object -ComObject Shell.Application
            $fontsFolder = $shell.Namespace(0x14)

            Get-ChildItem -Path $extractPath -Filter "*.ttf" | Where-Object {
                $jbMissing -contains $_.Name
            } | ForEach-Object {
                $fontsFolder.CopyHere($_.FullName, 0x10)  # 0x10 = overwrite without prompt
            }

            Write-Ok "JetBrainsMono Nerd Font installed"
        } catch {
            Write-Warn "failed to install font: $_"
        } finally {
            Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
            Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    # FiraCode
    $firaFonts = @("FiraCode-Regular.ttf", "FiraCode-Bold.ttf")
    $firaMissing = $firaFonts | Where-Object { -not (Test-FontInstalled $_) }

    if (-not $firaMissing) {
        Write-Ok "FiraCode already installed"
    } else {
        Write-Info "downloading FiraCode..."
        $firaUrl = "https://github.com/tonsky/FiraCode/releases/download/6.2/Fira_Code_v6.2.zip"
        $firaZip = "$env:TEMP\FiraCode.zip"
        $firaExtract = "$env:TEMP\FiraCode"

        try {
            Invoke-WebRequest -Uri $firaUrl -OutFile $firaZip -UseBasicParsing
            Expand-Archive -Path $firaZip -DestinationPath $firaExtract -Force

            $shell = New-Object -ComObject Shell.Application
            $fontsFolder = $shell.Namespace(0x14)

            Get-ChildItem -Path "$firaExtract\ttf" -Filter "*.ttf" | Where-Object {
                $firaMissing -contains $_.Name
            } | ForEach-Object {
                $fontsFolder.CopyHere($_.FullName, 0x10)
            }
            Write-Ok "FiraCode installed"
        } catch {
            Write-Warn "failed to install FiraCode: $_"
        } finally {
            Remove-Item $firaZip -Force -ErrorAction SilentlyContinue
            Remove-Item $firaExtract -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# ============================================================================
# GIT
# ============================================================================

function Install-Git {
    if (Test-CommandExists "git") {
        Write-Ok "git already installed: $(git --version)"
        return
    }

    Write-Info "installing git..."

    $release = Get-GitHubLatestRelease "git-for-windows/git"
    $asset = $release.assets | Where-Object { $_.name -match "64-bit\.exe$" -and $_.name -notmatch "portable" } | Select-Object -First 1

    $installerPath = "$env:TEMP\git-installer.exe"
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $installerPath -UseBasicParsing

    Write-Info "running git installer (silent)..."
    Start-Process $installerPath -ArgumentList "/VERYSILENT /NORESTART /NOCANCEL /SP- /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS /COMPONENTS=`"icons,ext\reg\shellhere,assoc,assoc_sh`"" -Wait -NoNewWindow

    Remove-Item $installerPath -Force -ErrorAction SilentlyContinue

    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    Write-Ok "git installed"
}

# ============================================================================
# NEOVIM
# ============================================================================

function Install-Neovim {
    if (Test-CommandExists "nvim") {
        Write-Ok "neovim already installed: $(nvim --version | Select-Object -First 1)"
        return
    }

    Write-Info "installing neovim..."

    $release = Get-GitHubLatestRelease "neovim/neovim"
    $asset = $release.assets | Where-Object { $_.name -match "nvim-win64\.zip$" } | Select-Object -First 1

    $zipPath = "$env:TEMP\nvim.zip"
    $extractPath = "$TOOLS_DIR"

    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath -UseBasicParsing
    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

    $nvimBin = "$extractPath\nvim-win64\bin"
    Add-ToPath $nvimBin

    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
    Write-Ok "neovim installed"
}

# ============================================================================
# VSCODE
# ============================================================================

function Install-VSCode {
    if (Test-CommandExists "code") {
        Write-Ok "vscode already installed"
        return
    }

    # check if installed in program files
    $vscodePaths = @(
        "$env:ProgramFiles\Microsoft VS Code\bin\code.cmd",
        "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd"
    )
    foreach ($path in $vscodePaths) {
        if (Test-Path $path) {
            Write-Ok "vscode already installed"
            return
        }
    }

    Write-Info "installing vscode..."

    $installerUrl = "https://code.visualstudio.com/sha/download?build=stable&os=win32-x64"
    $installerPath = "$env:TEMP\vscode-installer.exe"

    Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing

    Write-Info "running vscode installer..."
    Start-Process $installerPath -ArgumentList "/VERYSILENT /NORESTART /MERGETASKS=!runcode,addcontextmenufiles,addcontextmenufolders,addtopath" -Wait -NoNewWindow

    Remove-Item $installerPath -Force -ErrorAction SilentlyContinue

    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    Write-Ok "vscode installed"
}

function Set-VSCodeConfig {
    Write-Info "configuring vscode..."

    $settingsPath = "$env:APPDATA\Code\User\settings.json"
    $settingsDir = Split-Path $settingsPath -Parent

    if (-not (Test-Path $settingsDir)) {
        New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null
    }

    # load existing settings or create new
    if (Test-Path $settingsPath) {
        try {
            $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json -AsHashtable
        } catch {
            Write-Warn "could not parse vscode settings, creating new"
            $settings = @{}
        }
    } else {
        $settings = @{}
    }

    # set pwsh as default terminal
    $settings["terminal.integrated.defaultProfile.windows"] = "PowerShell"

    # ensure terminal profiles exist
    if (-not $settings.ContainsKey("terminal.integrated.profiles.windows")) {
        $settings["terminal.integrated.profiles.windows"] = @{}
    }
    $settings["terminal.integrated.profiles.windows"]["PowerShell"] = @{
        source = "PowerShell"
        icon = "terminal-powershell"
    }

    # add mbo/envs to python venv folders
    $mboEnvs = "$env:USERPROFILE\mbo\envs"
    if (-not $settings.ContainsKey("python.venvFolders")) {
        $settings["python.venvFolders"] = @()
    }
    $venvFolders = [System.Collections.ArrayList]@($settings["python.venvFolders"])
    if ($venvFolders -notcontains $mboEnvs -and $venvFolders -notcontains "~/mbo/envs") {
        $venvFolders.Add("~/mbo/envs") | Out-Null
        $settings["python.venvFolders"] = @($venvFolders)
    }

    # set font
    $settings["editor.fontFamily"] = "'JetBrainsMono Nerd Font', Consolas, 'Courier New', monospace"
    $settings["terminal.integrated.fontFamily"] = "JetBrainsMono Nerd Font"

    # save
    $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding UTF8
    Write-Ok "vscode configured (pwsh terminal, python envs: ~/mbo/envs)"
}

# ============================================================================
# CLI TOOLS (from GitHub releases)
# ============================================================================

function Install-CliTool {
    param(
        [string]$Name,
        [string]$Repo,
        [string]$AssetPattern,
        [string]$BinaryName = $null,
        [switch]$IsTarGz
    )

    $cmd = if ($BinaryName) { $BinaryName } else { $Name }

    if (Test-CommandExists $cmd) {
        Write-Ok "$Name already installed"
        return
    }

    Write-Info "installing $Name..."

    $release = Get-GitHubLatestRelease $Repo
    if (-not $release) {
        Write-Warn "could not get release for $Name"
        return
    }

    $asset = $release.assets | Where-Object { $_.name -match $AssetPattern } | Select-Object -First 1
    if (-not $asset) {
        Write-Warn "could not find asset for $Name matching $AssetPattern"
        return
    }

    $downloadPath = "$env:TEMP\$($asset.name)"

    try {
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $downloadPath -UseBasicParsing

        if ($asset.name -match "\.zip$") {
            $extractPath = "$env:TEMP\$Name-extract"
            Expand-Archive -Path $downloadPath -DestinationPath $extractPath -Force

            # find the binary
            $binary = Get-ChildItem -Path $extractPath -Recurse -Filter "$cmd.exe" | Select-Object -First 1
            if (-not $binary) {
                $binary = Get-ChildItem -Path $extractPath -Recurse -Filter "*.exe" | Select-Object -First 1
            }

            if ($binary) {
                Copy-Item $binary.FullName "$LOCAL_BIN\$cmd.exe" -Force
                Write-Ok "$Name installed"
            }

            Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue
        } elseif ($asset.name -match "\.tar\.gz$") {
            # use tar if available
            $extractPath = "$env:TEMP\$Name-extract"
            New-Item -ItemType Directory -Path $extractPath -Force | Out-Null
            tar -xzf $downloadPath -C $extractPath 2>$null

            $binary = Get-ChildItem -Path $extractPath -Recurse -Filter "$cmd.exe" | Select-Object -First 1
            if (-not $binary) {
                $binary = Get-ChildItem -Path $extractPath -Recurse -Filter "*.exe" | Select-Object -First 1
            }

            if ($binary) {
                Copy-Item $binary.FullName "$LOCAL_BIN\$cmd.exe" -Force
                Write-Ok "$Name installed"
            }

            Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue
        } elseif ($asset.name -match "\.exe$") {
            Copy-Item $downloadPath "$LOCAL_BIN\$cmd.exe" -Force
            Write-Ok "$Name installed"
        }
    } catch {
        Write-Warn "failed to install $Name`: $_"
    } finally {
        Remove-Item $downloadPath -Force -ErrorAction SilentlyContinue
    }
}

function Install-CliTools {
    Write-Info "installing cli tools..."

    # lazygit
    Install-CliTool -Name "lazygit" -Repo "jesseduffield/lazygit" -AssetPattern "Windows_x86_64\.zip$"

    # fd
    Install-CliTool -Name "fd" -Repo "sharkdp/fd" -AssetPattern "x86_64-pc-windows-msvc\.zip$"

    # ripgrep
    Install-CliTool -Name "ripgrep" -Repo "BurntSushi/ripgrep" -AssetPattern "x86_64-pc-windows-msvc\.zip$" -BinaryName "rg"

    # fzf
    Install-CliTool -Name "fzf" -Repo "junegunn/fzf" -AssetPattern "windows_amd64\.zip$"

    # bat
    Install-CliTool -Name "bat" -Repo "sharkdp/bat" -AssetPattern "x86_64-pc-windows-msvc\.zip$"

    # delta
    Install-CliTool -Name "delta" -Repo "dandavison/delta" -AssetPattern "x86_64-pc-windows-msvc\.zip$"

    # eza
    Install-CliTool -Name "eza" -Repo "eza-community/eza" -AssetPattern "x86_64-pc-windows-gnu\.zip$"

    # zoxide
    Install-CliTool -Name "zoxide" -Repo "ajeetdsouza/zoxide" -AssetPattern "x86_64-pc-windows-msvc\.zip$"

    # starship
    Install-CliTool -Name "starship" -Repo "starship/starship" -AssetPattern "x86_64-pc-windows-msvc\.zip$"

    # fastfetch
    Install-CliTool -Name "fastfetch" -Repo "fastfetch-cli/fastfetch" -AssetPattern "windows-amd64\.zip$"
}

# ============================================================================
# UV + PYTHON
# ============================================================================

function Install-Python {
    Write-Info "setting up python via uv..."

    if (-not (Test-CommandExists "uv")) {
        Write-Info "installing uv..."

        $release = Get-GitHubLatestRelease "astral-sh/uv"
        $asset = $release.assets | Where-Object { $_.name -match "x86_64-pc-windows-msvc\.zip$" } | Select-Object -First 1

        $zipPath = "$env:TEMP\uv.zip"
        $extractPath = "$env:TEMP\uv-extract"

        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath -UseBasicParsing
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

        $uvBinary = Get-ChildItem -Path $extractPath -Recurse -Filter "uv.exe" | Select-Object -First 1
        Copy-Item $uvBinary.FullName "$LOCAL_BIN\uv.exe" -Force

        # also copy uvx if present
        $uvxBinary = Get-ChildItem -Path $extractPath -Recurse -Filter "uvx.exe" | Select-Object -First 1
        if ($uvxBinary) {
            Copy-Item $uvxBinary.FullName "$LOCAL_BIN\uvx.exe" -Force
        }

        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
        Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue

        Write-Ok "uv installed"
    } else {
        Write-Ok "uv already installed: $(uv --version)"
    }

    # install python 3.12
    $pythonInstalled = & "$LOCAL_BIN\uv.exe" python list 2>$null | Select-String "3\.12"
    if ($pythonInstalled) {
        Write-Ok "python 3.12 already installed"
    } else {
        Write-Info "installing python 3.12 via uv..."
        $null = & "$LOCAL_BIN\uv.exe" python install 3.12 2>&1
        Write-Ok "python 3.12 installed"
    }

    # neovim python venv
    $nvimVenv = "$env:LOCALAPPDATA\nvim-python"
    if (-not (Test-Path $nvimVenv)) {
        Write-Info "creating neovim python venv..."
        $null = & "$LOCAL_BIN\uv.exe" venv $nvimVenv --python 3.12 2>&1
    }

    # check if pynvim already installed
    $pynvimPath = Get-ChildItem "$nvimVenv\Lib\site-packages\pynvim*" -ErrorAction SilentlyContinue
    if ($pynvimPath) {
        Write-Ok "pynvim already installed"
    } else {
        Write-Info "installing pynvim..."
        $null = & "$LOCAL_BIN\uv.exe" pip install pynvim --python "$nvimVenv\Scripts\python.exe" 2>&1
        Write-Ok "pynvim installed"
    }

    # install uv tools
    foreach ($tool in @("ruff", "ty")) {
        $installed = & "$LOCAL_BIN\uv.exe" tool list 2>$null | Select-String $tool
        if ($installed) {
            Write-Ok "$tool already installed"
        } else {
            Write-Info "installing $tool..."
            $null = & "$LOCAL_BIN\uv.exe" tool install $tool 2>&1
            Write-Ok "$tool installed"
        }
    }
}

# ============================================================================
# WINDOWS TERMINAL CONFIG
# ============================================================================

function Set-WindowsTerminalConfig {
    Write-Info "configuring windows terminal..."

    $wtPaths = @(
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"
    )

    $settingsPath = $wtPaths | Where-Object { Test-Path $_ } | Select-Object -First 1

    if (-not $settingsPath) {
        Write-Warn "windows terminal not found, skipping config"
        return
    }

    # backup
    $backup = "$settingsPath.backup.$(Get-Date -Format 'yyyyMMddHHmmss')"
    Copy-Item $settingsPath $backup -Force
    Write-Info "backed up to $backup"

    try {
        $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
    } catch {
        Write-Warn "could not parse settings.json: $_"
        return
    }

    # ensure structure
    if (-not $settings.profiles) {
        $settings | Add-Member -NotePropertyName "profiles" -NotePropertyValue @{ defaults = @{}; list = @() }
    }
    if (-not $settings.profiles.defaults) {
        $settings.profiles | Add-Member -NotePropertyName "defaults" -NotePropertyValue @{}
    }

    # set font on defaults
    $fontConfig = @{
        face = "JetBrainsMono Nerd Font"
        size = 11
    }
    $settings.profiles.defaults | Add-Member -NotePropertyName "font" -NotePropertyValue $fontConfig -Force

    # set font on all existing profiles
    foreach ($profile in $settings.profiles.list) {
        $profile | Add-Member -NotePropertyName "font" -NotePropertyValue $fontConfig -Force
    }
    Write-Ok "set JetBrainsMono Nerd Font on all profiles"

    # find/create pwsh profile
    $pwshPath = "$env:ProgramFiles\PowerShell\7\pwsh.exe"
    $pwshGuid = $null

    foreach ($profile in $settings.profiles.list) {
        if ($profile.source -eq "Windows.Terminal.PowershellCore" -or $profile.commandline -match "pwsh") {
            $pwshGuid = $profile.guid
            break
        }
    }

    if (-not $pwshGuid -and (Test-Path $pwshPath)) {
        $pwshGuid = "{574e775e-4f2a-5b96-ac1e-a2962a402336}"
        $pwshProfile = @{
            guid = $pwshGuid
            name = "PowerShell"
            commandline = $pwshPath
            hidden = $false
        }
        $settings.profiles.list = @($pwshProfile) + @($settings.profiles.list)
        Write-Ok "added pwsh profile"
    }

    if ($pwshGuid) {
        $settings | Add-Member -NotePropertyName "defaultProfile" -NotePropertyValue $pwshGuid -Force
        Write-Ok "set pwsh as default"
    }

    # hide legacy powershell
    foreach ($profile in $settings.profiles.list) {
        if ($profile.source -eq "Windows.Terminal.PowerShell") {
            $profile | Add-Member -NotePropertyName "hidden" -NotePropertyValue $true -Force
            Write-Ok "hidden legacy Windows PowerShell"
        }
        if ($profile.source -eq "Windows.Terminal.Azure") {
            $profile | Add-Member -NotePropertyName "hidden" -NotePropertyValue $true -Force
        }
    }

    $settings | ConvertTo-Json -Depth 100 | Set-Content $settingsPath -Encoding UTF8
    Write-Ok "windows terminal configured"
}

# ============================================================================
# CONFIGS
# ============================================================================

function Install-Configs {
    Write-Info "setting up configurations..."

    # use local config dir if running from cloned repo, otherwise clone
    $scriptDir = $PSScriptRoot
    if ($scriptDir -and (Test-Path "$scriptDir\config")) {
        $configSource = "$scriptDir\config"
        Write-Ok "using local configs from $scriptDir"
    } else {
        # running via iex (irm ...) - need to clone
        if (-not (Test-CommandExists "git")) {
            Write-Warn "git not available, skipping config setup"
            return
        }

        if (Test-Path "$CONFIG_ROOT\.git") {
            Push-Location $CONFIG_ROOT
            $null = git pull --ff-only 2>&1
            Pop-Location
            Write-Ok "configs updated"
        } else {
            if (Test-Path $CONFIG_ROOT) {
                Remove-Item $CONFIG_ROOT -Recurse -Force
            }
            $null = git clone "$REPO_URL.git" $CONFIG_ROOT 2>&1
            Write-Ok "configs cloned"
        }
        $configSource = "$CONFIG_ROOT\config"
    }

    # symlinks
    $links = @{
        "$env:LOCALAPPDATA\nvim" = "$configSource\nvim"
        "$env:USERPROFILE\.vimrc" = "$configSource\vimrc"
        "$env:USERPROFILE\.config\lazygit" = "$configSource\lazygit"
        "$env:USERPROFILE\.config\starship.toml" = "$configSource\starship.toml"
    }

    foreach ($link in $links.GetEnumerator()) {
        if (-not (Test-Path $link.Value)) { continue }

        $parent = Split-Path $link.Key -Parent
        if (-not (Test-Path $parent)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }

        if (Test-Path $link.Key) {
            Remove-Item $link.Key -Recurse -Force -ErrorAction SilentlyContinue
        }

        try {
            New-Item -ItemType SymbolicLink -Path $link.Key -Target $link.Value -Force | Out-Null
            Write-Ok "linked $(Split-Path $link.Key -Leaf)"
        } catch {
            Write-Warn "failed to link $($link.Key)"
        }
    }
}

# ============================================================================
# POWERSHELL PROFILE
# ============================================================================

function Get-ShellPreferences {
    Write-Host ""
    Write-Host "  Shell Enhancement Options" -ForegroundColor Cyan
    Write-Host "  Replace built-in commands with modern alternatives?" -ForegroundColor White
    Write-Host ""

    $prefs = @{
        ReplaceLs = $true
        ReplaceCat = $true
        ReplaceCd = $true
    }

    # ls -> eza
    Write-Host "  [1] ls -> eza (icons, colors, better formatting)" -ForegroundColor Gray
    $response = Read-Host "      Replace ls? [Y/n] (recommended)"
    $prefs.ReplaceLs = ($response -eq "" -or $response -match "^[Yy]")

    # cat -> bat
    Write-Host "  [2] cat -> bat (syntax highlighting)" -ForegroundColor Gray
    $response = Read-Host "      Replace cat? [Y/n] (recommended)"
    $prefs.ReplaceCat = ($response -eq "" -or $response -match "^[Yy]")

    # cd -> z (zoxide)
    Write-Host "  [3] cd -> z (zoxide smart jump)" -ForegroundColor Gray
    $response = Read-Host "      Replace cd? [Y/n] (recommended)"
    $prefs.ReplaceCd = ($response -eq "" -or $response -match "^[Yy]")

    Write-Host ""
    return $prefs
}

function Install-PowerShellProfile {
    Write-Info "setting up powershell profile..."

    $profileDir = "$env:USERPROFILE\Documents\PowerShell"
    $profilePath = "$profileDir\Microsoft.PowerShell_profile.ps1"

    if (-not (Test-Path $profileDir)) {
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    }

    # check if already configured
    if (Test-Path $profilePath) {
        $existing = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
        if ($existing -match "MBO PowerShell Profile") {
            Write-Ok "profile already configured"
            return
        }
    }

    # get user preferences
    $prefs = Get-ShellPreferences

    # build profile content
    $content = @'
# MBO PowerShell Profile

# path
$env:Path = "$env:USERPROFILE\.local\bin;$env:Path"

# aliases
Set-Alias -Name lg -Value lazygit -ErrorAction SilentlyContinue
Set-Alias -Name vim -Value nvim -ErrorAction SilentlyContinue
Set-Alias -Name vi -Value nvim -ErrorAction SilentlyContinue
Set-Alias -Name g -Value git -ErrorAction SilentlyContinue

'@

    # ls replacements
    if ($prefs.ReplaceLs) {
        $content += @'
# ls -> eza (size, icon, name by default)
Remove-Item Alias:ls -Force -ErrorAction SilentlyContinue
function ls { eza -l --icons --group-directories-first --no-permissions --no-time --no-user @args }
function lsv { eza -l --icons --group-directories-first @args }
function la { eza -la --icons --group-directories-first --no-permissions --no-time --no-user @args }
function lt { eza -T --icons --group-directories-first @args }

'@
    }

    # cat replacement
    if ($prefs.ReplaceCat) {
        $content += @'
# cat -> bat (syntax highlighting)
Remove-Item Alias:cat -Force -ErrorAction SilentlyContinue
function cat { bat --paging=never @args }

'@
    }

    # cd replacement and zoxide
    if ($prefs.ReplaceCd) {
        $content += @'
# cd -> zoxide (smart directory jump)
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell --cmd cd | Out-String) })
}

'@
    } else {
        $content += @'
# zoxide (use z to jump)
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}

'@
    }

    $content += @'
function .. { Set-Location .. }
function ... { Set-Location ..\.. }

# git shortcuts
function gs { git status @args }
function ga { git add @args }
function gc { git commit @args }
function gp { git push @args }
function gl { git pull @args }
function gd { git diff @args }
function gco { git checkout @args }
function glog { git log --oneline --graph --decorate -20 @args }

# starship prompt
if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (&starship init powershell)
}

# fastfetch + tips
if (Get-Command fastfetch -ErrorAction SilentlyContinue) {
    fastfetch
    Write-Host ""
    Write-Host "  quick reference" -ForegroundColor Cyan
    Write-Host "    ls           size + icon + name       lsv         detailed list" -ForegroundColor Gray
    Write-Host "    lt           tree view                la          list all (hidden)" -ForegroundColor Gray
    Write-Host "    cd <name>    smart jump (zoxide)      cd -        go back" -ForegroundColor Gray
    Write-Host "    fd <pat>     find files               rg <pat>    search contents" -ForegroundColor Gray
    Write-Host "    cat <file>   view with syntax         nvim        editor" -ForegroundColor Gray
    Write-Host "    lg           lazygit                  uv run      run python script" -ForegroundColor Gray
    Write-Host ""
}
'@

    if (Test-Path $profilePath) {
        Add-Content -Path $profilePath -Value "`n`n$content"
    } else {
        Set-Content -Path $profilePath -Value $content
    }
    Write-Ok "profile created"
}

# ============================================================================
# SUMMARY
# ============================================================================

function Show-Summary {
    Write-Host ""
    Write-Host "Setup Complete" -ForegroundColor Green
    Write-Host ""
    Write-Host "  IDEs:" -ForegroundColor White
    Write-Host "    VS Code (pwsh terminal, ~/mbo/envs for python)" -ForegroundColor Gray
    Write-Host "    Neovim" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Terminal:" -ForegroundColor White
    Write-Host "    pwsh (default), legacy PS hidden" -ForegroundColor Gray
    Write-Host "    JetBrainsMono Nerd Font" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Tools ($LOCAL_BIN):" -ForegroundColor White
    Write-Host "    git, lazygit, fd, rg, fzf, bat, delta, eza, zoxide, starship, fastfetch" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Python:" -ForegroundColor White
    Write-Host "    uv, python 3.12, ruff, ty" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  NEXT:" -ForegroundColor Yellow
    Write-Host "    1. Close and reopen terminal" -ForegroundColor White
    Write-Host "    2. Run 'nvim' (plugins auto-install)" -ForegroundColor White
    Write-Host ""
}

# ============================================================================
# MAIN
# ============================================================================

function Main {
    Show-Banner
    Ensure-Directories

    Install-PowerShellCore
    Install-Fonts
    Install-Git
    Install-Neovim
    Install-VSCode
    Set-VSCodeConfig
    Install-CliTools
    Install-Python
    Install-Configs
    Set-WindowsTerminalConfig
    Install-PowerShellProfile

    Show-Summary
}

Main
