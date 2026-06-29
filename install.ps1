# MBO Server Configs - Windows Admin Setup
# Target: Windows Server 2022, Windows 11
#
# Usage:
#   .\install.ps1           Interactive mode (prompts for each group)
#   .\install.ps1 -y        Auto-accept all installations
#   .\install.ps1 -All      Auto-accept installations AND configurations
#
# Installation Groups:
#   - Shell: PowerShell Core, fonts
#   - CLI Tools: git, lazygit, fd, ripgrep, fzf, bat, delta, eza, zoxide, starship, fastfetch
#   - Editors: Neovim, VS Code
#   - Python: uv, Python 3.12, ruff, ty, pynvim
#
# Configuration Options:
#   - Git editor, PSReadLine, shell aliases, VS Code, Windows Terminal

param(
    [Alias('y')]
    [switch]$Yes,           # Auto-accept installations (-y)
    [switch]$All            # Auto-accept installations AND configurations (-All)
)

#Requires -RunAsAdministrator
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Global flags
$script:AutoInstall = $Yes -or $All
$script:AutoConfig = $All

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
        Write-Info "added $Path to user PATH"
    }
}

function Add-ToMachinePath {
    param([string]$Path)
    $currentPath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    if ($currentPath -notlike "*$Path*") {
        [System.Environment]::SetEnvironmentVariable("Path", "$Path;$currentPath", "Machine")
        $env:Path = "$Path;$env:Path"
        Write-Info "added $Path to system PATH (all users)"
    }
}

function Get-GitHubLatestRelease {
    param([string]$Repo)
    $url = "https://api.github.com/repos/$Repo/releases/latest"
    try {
        $headers = @{ "User-Agent" = "PowerShell" }
        # Use GitHub token if available (avoids rate limiting)
        if ($env:GITHUB_TOKEN) {
            $headers["Authorization"] = "token $env:GITHUB_TOKEN"
        }
        $release = Invoke-RestMethod -Uri $url -Headers $headers
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

function Confirm-InstallGroup {
    param(
        [string]$Name,
        [string]$Description,
        [string[]]$Items
    )

    if ($script:AutoInstall) { return $true }

    Write-Host ""
    Write-Host "  $Name" -ForegroundColor Cyan
    Write-Host "  $Description" -ForegroundColor Gray
    Write-Host "    $($Items -join ', ')" -ForegroundColor White
    Write-Host ""
    $response = Read-Host "  Install? [Y/n]"
    return ($response -eq "" -or $response -match "^[Yy]")
}

function Get-InstallationChoices {
    Write-Host ""
    Write-Host "  Installation Groups" -ForegroundColor Cyan
    Write-Host ""

    $choices = @{
        Shell = Confirm-InstallGroup -Name "Shell" -Description "Terminal environment" -Items @("PowerShell 7", "JetBrainsMono Nerd Font", "FiraCode")
        CliTools = Confirm-InstallGroup -Name "CLI Tools" -Description "Command line utilities" -Items @("git", "lazygit", "fd", "ripgrep", "fzf", "bat", "delta", "eza", "zoxide", "starship", "fastfetch")
        Editors = Confirm-InstallGroup -Name "Editors" -Description "Code editors + build tools" -Items @("MinGW (gcc)", "Node.js (npm)", "CMake", "Neovim", "VS Code")
        Python = Confirm-InstallGroup -Name "Python" -Description "Python environment via uv (no system Python)" -Items @("uv", "Python 3.12", "ruff", "ty", "pynvim")
        Configs = Confirm-InstallGroup -Name "Configs" -Description "Symlink configuration files" -Items @("nvim", "lazygit", "starship", "fastfetch")
    }

    return $choices
}

# POWERSHELL CORE

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

# FONTS

function Test-FontInstalled {
    param([string]$FontName)
    $fontsDir = "$env:WINDIR\Fonts"
    $userFontsDir = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"

    # check font files on disk
    if (Test-Path "$fontsDir\$FontName") { return $true }
    if (Test-Path "$userFontsDir\$FontName") { return $true }

    # check registry: font filename is stored as the property VALUE, not the name
    foreach ($regPath in @(
        "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts",
        "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
    )) {
        $regFonts = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
        if ($regFonts) {
            foreach ($prop in $regFonts.PSObject.Properties) {
                if ($prop.Value -is [string] -and $prop.Value -match [regex]::Escape($FontName)) {
                    return $true
                }
            }
        }
    }

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

# GIT

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

# MINGW (GCC for Neovim treesitter) - installed globally for all users

function Install-MinGW {
    if (Test-CommandExists "gcc") {
        Write-Ok "gcc already installed: $(gcc --version | Select-Object -First 1)"
        return
    }

    Write-Info "installing mingw (gcc) globally..."

    # Download MinGW from winlibs (standalone, no installer needed)
    $mingwUrl = "https://github.com/brechtsanders/winlibs_mingw/releases/download/14.2.0posix-19.1.1-12.0.0-ucrt-r2/winlibs-x86_64-posix-seh-gcc-14.2.0-mingw-w64ucrt-12.0.0-r2.zip"
    $zipPath = "$env:TEMP\mingw.zip"
    $mingwDir = "$env:ProgramFiles\mingw64"

    try {
        Write-Info "downloading mingw (this may take a moment)..."
        Invoke-WebRequest -Uri $mingwUrl -OutFile $zipPath -UseBasicParsing

        Write-Info "extracting mingw..."
        $extractPath = "$env:TEMP\mingw-extract"
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

        # Move to Program Files (global location)
        if (Test-Path $mingwDir) {
            Remove-Item $mingwDir -Recurse -Force
        }
        Move-Item "$extractPath\mingw64" $mingwDir -Force

        # Add to system PATH (all users)
        Add-ToMachinePath "$mingwDir\bin"

        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
        Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue

        Write-Ok "mingw (gcc) installed globally"
    } catch {
        Write-Warn "failed to install mingw: $_"
    }
}

# NODE.JS (for LSPs like pyright, markdownlint) - installed globally for all users

function Install-NodeJS {
    if (Test-CommandExists "node") {
        Write-Ok "node already installed: $(node --version)"
        return
    }

    Write-Info "installing node.js globally..."

    $nodeVersion = "20.18.0"
    $nodeUrl = "https://nodejs.org/dist/v$nodeVersion/node-v$nodeVersion-win-x64.zip"
    $zipPath = "$env:TEMP\node.zip"
    $nodeDir = "$env:ProgramFiles\nodejs"

    try {
        Invoke-WebRequest -Uri $nodeUrl -OutFile $zipPath -UseBasicParsing

        Write-Info "extracting node.js..."
        $extractPath = "$env:TEMP\node-extract"
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

        if (Test-Path $nodeDir) {
            Remove-Item $nodeDir -Recurse -Force
        }
        Move-Item "$extractPath\node-v$nodeVersion-win-x64" $nodeDir -Force

        # Add to system PATH (all users)
        Add-ToMachinePath $nodeDir

        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
        Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue

        Write-Ok "node.js installed globally"
    } catch {
        Write-Warn "failed to install node.js: $_"
    }
}

# CMAKE (for some neovim plugins like telescope-fzf-native) - installed globally for all users

function Install-CMake {
    if (Test-CommandExists "cmake") {
        Write-Ok "cmake already installed: $(cmake --version | Select-Object -First 1)"
        return
    }

    Write-Info "installing cmake globally..."

    $release = Get-GitHubLatestRelease "Kitware/CMake"
    if (-not $release) {
        Write-Warn "could not get cmake release"
        return
    }

    $asset = $release.assets | Where-Object { $_.name -match "windows-x86_64\.zip$" -and $_.name -notmatch "\.msi" } | Select-Object -First 1
    if (-not $asset) {
        Write-Warn "could not find cmake asset"
        return
    }

    $zipPath = "$env:TEMP\cmake.zip"
    $cmakeDir = "$env:ProgramFiles\CMake"

    try {
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath -UseBasicParsing

        Write-Info "extracting cmake..."
        $extractPath = "$env:TEMP\cmake-extract"
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

        # Find the extracted cmake folder (has version in name)
        $cmakeExtracted = Get-ChildItem -Path $extractPath -Directory | Select-Object -First 1

        if (Test-Path $cmakeDir) {
            Remove-Item $cmakeDir -Recurse -Force
        }
        Move-Item $cmakeExtracted.FullName $cmakeDir -Force

        # Add to system PATH (all users)
        Add-ToMachinePath "$cmakeDir\bin"

        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
        Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue

        Write-Ok "cmake installed globally"
    } catch {
        Write-Warn "failed to install cmake: $_"
    }
}

# MAKE (for some neovim plugins)

function Install-Make {
    if (Test-CommandExists "make") {
        Write-Ok "make already installed"
        return
    }

    # If MinGW is installed globally, make should be available via mingw32-make
    $mingwMake = "$env:ProgramFiles\mingw64\bin\mingw32-make.exe"
    if (Test-Path $mingwMake) {
        # Create a 'make' alias by copying
        Copy-Item $mingwMake "$env:ProgramFiles\mingw64\bin\make.exe" -Force
        Write-Ok "make available (via mingw)"
        return
    }

    Write-Info "make will be available after mingw installation"
}

# NEOVIM

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

# VSCODE

function Resolve-UserPath {
    param([string]$InputPath)

    if ([string]::IsNullOrWhiteSpace($InputPath)) { return $null }

    $p = $InputPath.Trim().Trim('"').Trim("'")

    if ($p -eq "~") {
        $p = $env:USERPROFILE
    } elseif ($p -match '^~[\\/]') {
        $p = Join-Path $env:USERPROFILE $p.Substring(2)
    }

    $p = [System.Environment]::ExpandEnvironmentVariables($p)

    try {
        return [System.IO.Path]::GetFullPath($p)
    } catch {
        return $null
    }
}

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
    param([string]$PythonEnvPath)

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

    # drop stale ~/mbo/envs (mbo dir no longer used)
    if ($settings.ContainsKey("python.venvFolders")) {
        $cleaned = @($settings["python.venvFolders"] | Where-Object {
            $_ -ne "~/mbo/envs" -and $_ -ne "$env:USERPROFILE\mbo\envs"
        })
        if ($cleaned.Count -eq 0) {
            $settings.Remove("python.venvFolders")
        } else {
            $settings["python.venvFolders"] = $cleaned
        }
    }

    # point vscode at a user-specified folder of python environments
    # envs live one level deep as <folder>/<name>/.venv, so use a glob that the
    # Python Environments extension expands during discovery
    if ($PythonEnvPath) {
        $envGlob = ($PythonEnvPath -replace '\\', '/').TrimEnd('/') + "/*/.venv"

        if (-not $settings.ContainsKey("python-envs.globalSearchPaths")) {
            $settings["python-envs.globalSearchPaths"] = @()
        }
        $searchPaths = [System.Collections.ArrayList]@($settings["python-envs.globalSearchPaths"])
        if ($searchPaths -notcontains $envGlob) {
            $searchPaths.Add($envGlob) | Out-Null
        }
        $settings["python-envs.globalSearchPaths"] = @($searchPaths)
    }

    # save
    $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding UTF8
    $envNote = if ($PythonEnvPath) { ", python envs: $PythonEnvPath" } else { "" }
    Write-Ok "vscode configured (pwsh terminal$envNote)"
}

# CLI TOOLS (from GitHub releases)

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

# UV + PYTHON

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

        $uvExe = "$LOCAL_BIN\uv.exe"
        Write-Ok "uv installed"
    } else {
        # resolve the existing uv (may be on PATH but not in LOCAL_BIN)
        $uvExe = (Get-Command uv -ErrorAction SilentlyContinue).Source
        if (-not $uvExe) { $uvExe = "$LOCAL_BIN\uv.exe" }
        Write-Ok "uv already installed: $(& $uvExe --version)"
    }

    # install python 3.12
    $pythonInstalled = & $uvExe python list 2>$null | Select-String "3\.12"
    if ($pythonInstalled) {
        Write-Ok "python 3.12 already installed"
    } else {
        Write-Info "installing python 3.12 via uv..."
        $null = & $uvExe python install 3.12 2>&1
        Write-Ok "python 3.12 installed"
    }

    # neovim python venv
    $nvimVenv = "$env:LOCALAPPDATA\nvim-python"
    $nvimPython = "$nvimVenv\Scripts\python.exe"

    if (-not (Test-Path $nvimPython)) {
        Write-Info "creating neovim python venv..."
        $oldErrorPref = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        & $uvExe venv $nvimVenv --python 3.12 2>&1 | Out-Null
        $ErrorActionPreference = $oldErrorPref

        if (Test-Path $nvimPython) {
            Write-Ok "neovim venv created"
        } else {
            Write-Warn "failed to create neovim venv"
        }
    } else {
        Write-Ok "neovim venv already exists"
    }

    # install pynvim if venv exists
    if (Test-Path $nvimPython) {
        $pynvimPath = Get-ChildItem "$nvimVenv\Lib\site-packages\pynvim*" -ErrorAction SilentlyContinue
        if ($pynvimPath) {
            Write-Ok "pynvim already installed"
        } else {
            Write-Info "installing pynvim..."
            $oldErrorPref = $ErrorActionPreference
            $ErrorActionPreference = "Continue"
            & $uvExe pip install pynvim --python $nvimPython 2>&1 | Out-Null
            $ErrorActionPreference = $oldErrorPref
            Write-Ok "pynvim installed"
        }
    }

    # install uv tools
    $oldErrorPref = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    foreach ($tool in @("ruff", "ty")) {
        $toolList = & $uvExe tool list 2>&1
        if ($toolList -match $tool) {
            Write-Ok "$tool already installed"
        } else {
            Write-Info "installing $tool..."
            & $uvExe tool install $tool 2>&1 | Out-Null
            Write-Ok "$tool installed"
        }
    }
    $ErrorActionPreference = $oldErrorPref
}

# WINDOWS TERMINAL CONFIG

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

# CONFIGS

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
            $null = git submodule update --init --recursive 2>&1
            Pop-Location
            Write-Ok "configs updated"
        } else {
            if (Test-Path $CONFIG_ROOT) {
                Remove-Item $CONFIG_ROOT -Recurse -Force
            }
            $null = git clone --recursive "$REPO_URL.git" $CONFIG_ROOT 2>&1
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
        "$env:USERPROFILE\.config\fastfetch" = "$configSource\fastfetch"
        "$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1" = "$configSource\powershell\profile.ps1"
    }

    foreach ($link in $links.GetEnumerator()) {
        if (-not (Test-Path $link.Value)) { continue }

        $parent = Split-Path $link.Key -Parent
        if (-not (Test-Path $parent)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }

        if (Test-Path $link.Key) {
            $existing = Get-Item $link.Key -Force
            if ($existing.LinkType -eq "SymbolicLink") {
                Remove-Item $link.Key -Recurse -Force -ErrorAction SilentlyContinue
            } else {
                $backup = "$($link.Key).backup.$(Get-Date -Format 'yyyyMMddHHmmss')"
                Move-Item $link.Key $backup -Force
                Write-Warn "backed up existing $(Split-Path $link.Key -Leaf) to $backup"
            }
        }

        try {
            New-Item -ItemType SymbolicLink -Path $link.Key -Target $link.Value -Force | Out-Null
            Write-Ok "linked $(Split-Path $link.Key -Leaf)"
        } catch {
            Write-Warn "failed to link $($link.Key)"
        }
    }
}

# POWERSHELL PROFILE

# INTERACTIVE CONFIGURATION

function Get-InstalledEditors {
    $editors = @()

    # Notepad (always available on Windows)
    $editors += @{ Name = "Notepad"; Command = "notepad"; Path = "$env:SystemRoot\notepad.exe" }

    # Notepad++
    $nppPaths = @(
        "$env:ProgramFiles\Notepad++\notepad++.exe",
        "${env:ProgramFiles(x86)}\Notepad++\notepad++.exe"
    )
    foreach ($path in $nppPaths) {
        if (Test-Path $path) {
            $editors += @{ Name = "Notepad++"; Command = "`"$path`" -multiInst -notabbar -nosession -noPlugin"; Path = $path }
            break
        }
    }

    # VS Code
    $vscodePaths = @(
        "$env:ProgramFiles\Microsoft VS Code\bin\code.cmd",
        "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd"
    )
    foreach ($path in $vscodePaths) {
        if (Test-Path $path) {
            $editors += @{ Name = "VS Code"; Command = "code --wait"; Path = $path }
            break
        }
    }
    if (-not ($editors | Where-Object { $_.Name -eq "VS Code" }) -and (Test-CommandExists "code")) {
        $editors += @{ Name = "VS Code"; Command = "code --wait"; Path = "code" }
    }

    # PyCharm
    $pycharmPaths = @(
        "$env:ProgramFiles\JetBrains\PyCharm*\bin\pycharm64.exe",
        "$env:LOCALAPPDATA\Programs\PyCharm*\bin\pycharm64.exe",
        "$env:LOCALAPPDATA\JetBrains\Toolbox\apps\PyCharm*\ch-0\*\bin\pycharm64.exe"
    )
    foreach ($pattern in $pycharmPaths) {
        $found = Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) {
            $editors += @{ Name = "PyCharm"; Command = "`"$($found.FullName)`" --wait"; Path = $found.FullName }
            break
        }
    }

    # Neovim
    if (Test-CommandExists "nvim") {
        $editors += @{ Name = "Neovim"; Command = "nvim"; Path = "nvim" }
    } elseif (Test-Path "$TOOLS_DIR\nvim-win64\bin\nvim.exe") {
        $editors += @{ Name = "Neovim"; Command = "$TOOLS_DIR\nvim-win64\bin\nvim.exe"; Path = "$TOOLS_DIR\nvim-win64\bin\nvim.exe" }
    }

    return $editors
}

function Get-ConfigurationPreferences {
    $prefs = @{
        GitEditor = $null
        ConfigureVSCode = $true
        PythonEnvPath = $null
        ConfigureWindowsTerminal = $true
    }

    # Auto-accept all config with defaults
    if ($script:AutoConfig) {
        Write-Info "auto-accepting configuration defaults (-All)"
        return $prefs
    }

    Write-Host ""
    Write-Host "  Configuration Options" -ForegroundColor Cyan
    Write-Host ""

    # Git Editor Selection
    Write-Host "  Git Editor" -ForegroundColor Yellow
    Write-Host "  Choose which editor Git will use for commit messages, rebase, etc." -ForegroundColor Gray
    Write-Host ""

    $editors = Get-InstalledEditors
    $currentEditor = git config --global core.editor 2>$null

    if ($currentEditor) {
        Write-Host "  Current: $currentEditor" -ForegroundColor DarkGray
    }

    for ($i = 0; $i -lt $editors.Count; $i++) {
        Write-Host "    [$($i + 1)] $($editors[$i].Name)" -ForegroundColor White
    }
    Write-Host "    [S] Skip (keep current)" -ForegroundColor DarkGray
    Write-Host ""

    $response = Read-Host "  Select editor [1-$($editors.Count)/S]"
    if ($response -match "^\d+$") {
        $idx = [int]$response - 1
        if ($idx -ge 0 -and $idx -lt $editors.Count) {
            $prefs.GitEditor = $editors[$idx]
            Write-Host "  -> $($editors[$idx].Name)" -ForegroundColor Green
        }
    } else {
        Write-Host "  -> Skipped" -ForegroundColor DarkGray
    }
    Write-Host ""

    # VS Code Configuration
    Write-Host "  VS Code Configuration" -ForegroundColor Yellow
    Write-Host "  Set PowerShell as default terminal and optionally point VS Code" -ForegroundColor Gray
    Write-Host "  at a folder it scans for Python virtual environments." -ForegroundColor Gray
    Write-Host ""
    Write-Host "    [Y] Configure VS Code (recommended)" -ForegroundColor White
    Write-Host "    [N] Skip VS Code configuration" -ForegroundColor White
    Write-Host ""

    $response = Read-Host "  Configure VS Code? [Y/n]"
    $prefs.ConfigureVSCode = ($response -eq "" -or $response -match "^[Yy]")
    Write-Host "  -> $(if ($prefs.ConfigureVSCode) { 'Yes' } else { 'Skipped' })" -ForegroundColor $(if ($prefs.ConfigureVSCode) { 'Green' } else { 'DarkGray' })
    Write-Host ""

    if ($prefs.ConfigureVSCode) {
        Write-Host "  Python environments folder (optional)" -ForegroundColor Yellow
        Write-Host "  Parent folder holding your envs, e.g. ~/repos or ~/projects." -ForegroundColor Gray
        Write-Host "  Tip: keep each env in its own subfolder as <name>/.venv" -ForegroundColor Gray
        Write-Host "       (~/repos/env1/.venv, ~/repos/env2/.venv); VS Code then lists them all." -ForegroundColor Gray
        Write-Host "  Enter to skip." -ForegroundColor Gray
        Write-Host ""

        while ($true) {
            $envInput = Read-Host "  Env folder"
            if ([string]::IsNullOrWhiteSpace($envInput)) {
                Write-Host "  -> Skipped" -ForegroundColor DarkGray
                break
            }
            $resolved = Resolve-UserPath $envInput
            if ($resolved -and (Test-Path $resolved -PathType Container)) {
                $prefs.PythonEnvPath = $resolved
                Write-Host "  -> $resolved" -ForegroundColor Green
                break
            }
            Write-Warn "folder not found: $envInput"
        }
        Write-Host ""
    }

    # Windows Terminal Configuration
    Write-Host "  Windows Terminal Configuration" -ForegroundColor Yellow
    Write-Host "  Set JetBrainsMono Nerd Font, PowerShell as default profile," -ForegroundColor Gray
    Write-Host "  and hide legacy Windows PowerShell." -ForegroundColor Gray
    Write-Host ""
    Write-Host "    [Y] Configure Windows Terminal (recommended)" -ForegroundColor White
    Write-Host "    [N] Skip Windows Terminal configuration" -ForegroundColor White
    Write-Host ""

    $response = Read-Host "  Configure Windows Terminal? [Y/n]"
    $prefs.ConfigureWindowsTerminal = ($response -eq "" -or $response -match "^[Yy]")
    Write-Host "  -> $(if ($prefs.ConfigureWindowsTerminal) { 'Yes' } else { 'Skipped' })" -ForegroundColor $(if ($prefs.ConfigureWindowsTerminal) { 'Green' } else { 'DarkGray' })

    Write-Host ""
    return $prefs
}

function Set-GitEditor {
    param([hashtable]$Editor)

    if (-not $Editor) { return }

    Write-Info "setting git editor to $($Editor.Name)..."
    git config --global core.editor $Editor.Command
    Write-Ok "git editor set to $($Editor.Name)"
}

# GIT BASH PROFILE

function Install-GitBashProfile {
    Write-Info "setting up git bash profile..."

    $bashrcPath = "$env:USERPROFILE\.bashrc"

    # check if already configured
    if (Test-Path $bashrcPath) {
        $existing = Get-Content $bashrcPath -Raw -ErrorAction SilentlyContinue
        if ($existing -match "MBO Bash Profile") {
            Write-Ok "git bash profile already configured"
            return
        }
    }

    $content = @'
# MBO Bash Profile

# path
export PATH="$HOME/.local/bin:$PATH"

# prefix history search: Up/Down step through history entries that start with the typed text
if [[ $- == *i* ]]; then
    bind '"\e[A": history-search-backward'
    bind '"\e[B": history-search-forward'
fi

# aliases
alias lg='lazygit'
alias vim='nvim'
alias vi='nvim'
alias g='git'

# ls -> eza (size, icon, name by default)
if command -v eza &> /dev/null; then
    alias ls='eza -l --icons --group-directories-first --no-permissions --no-time --no-user'
    alias lsv='eza -l --icons --group-directories-first'
    alias la='eza -la --icons --group-directories-first --no-permissions --no-time --no-user'
    alias lt='eza -T --icons --group-directories-first'
fi

# cat -> bat
if command -v bat &> /dev/null; then
    alias cat='bat --paging=never'
fi

# navigation
alias ..='cd ..'
alias ...='cd ../..'

# git shortcuts
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'
alias gco='git checkout'
alias glog='git log --oneline --graph --decorate -20'

# starship prompt
if command -v starship &> /dev/null; then
    eval "$(starship init bash)"
fi

# zoxide (smart cd) - must be after starship
if command -v zoxide &> /dev/null; then
    eval "$(zoxide init bash --cmd cd)"
fi

# fastfetch + tips on startup
if command -v fastfetch &> /dev/null && [[ $- == *i* ]]; then
    fastfetch
    echo ""
    echo -e "  \033[36mquick reference\033[0m"
    echo -e "  \033[90m  ls           size + icon + name       lsv         detailed list\033[0m"
    echo -e "  \033[90m  lt           tree view                la          list all (hidden)\033[0m"
    echo -e "  \033[90m  cd <name>    smart jump (zoxide)      cd -        go back\033[0m"
    echo -e "  \033[90m  fd <pat>     find files               rg <pat>    search contents\033[0m"
    echo -e "  \033[90m  cat <file>   view with syntax         nvim        editor\033[0m"
    echo -e "  \033[90m  lg           lazygit                  uv run      run python script\033[0m"
    echo ""
fi
'@

    if (Test-Path $bashrcPath) {
        Add-Content -Path $bashrcPath -Value "`n`n$content"
    } else {
        Set-Content -Path $bashrcPath -Value $content
    }
    Write-Ok "git bash profile created"
}

# SUMMARY

function Show-Summary {
    Write-Host ""
    Write-Host "  Setup Complete!" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Close and reopen your terminal to apply changes." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Commands" -ForegroundColor Cyan
    Write-Host "    ls, la, lt      list files (eza with icons)" -ForegroundColor Gray
    Write-Host "    cat <file>      view file with syntax highlighting (bat)" -ForegroundColor Gray
    Write-Host "    cd <dir>        smart jump, learns your habits (zoxide)" -ForegroundColor Gray
    Write-Host "    fd <pattern>    fast file search" -ForegroundColor Gray
    Write-Host "    rg <pattern>    fast text search in files (ripgrep)" -ForegroundColor Gray
    Write-Host "    fzf             fuzzy finder, pipe anything into it" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Tools" -ForegroundColor Cyan
    Write-Host "    fastfetch       system info displayed on terminal startup" -ForegroundColor Gray
    Write-Host "    starship        customizable prompt showing git status, python env, etc." -ForegroundColor Gray
    Write-Host "                    config: ~/.config/starship.toml" -ForegroundColor DarkGray
    Write-Host "    lazygit         terminal UI for git - stage, commit, push, branch, merge" -ForegroundColor Gray
    Write-Host "                    run 'lg' to open, ? for help, q to quit" -ForegroundColor DarkGray
    Write-Host "    nvim            neovim text editor, plugins auto-install on first run" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Python (uv)" -ForegroundColor Cyan
    Write-Host "    uv run <script.py>      run python script (auto-creates venv)" -ForegroundColor Gray
    Write-Host "    uv pip install <pkg>    install package to current venv" -ForegroundColor Gray
    Write-Host "    uv venv                 create virtual environment" -ForegroundColor Gray
    Write-Host "    uv sync                 install dependencies from pyproject.toml" -ForegroundColor Gray
    Write-Host ""
}

# MAIN

function Main {
    Show-Banner
    Ensure-Directories

    # Get installation choices (prompts unless -y or -Y)
    $install = Get-InstallationChoices

    # Install based on choices
    if ($install.Shell) {
        Install-PowerShellCore
        Install-Fonts
    }

    if ($install.CliTools) {
        Install-Git
        Install-CliTools
    }

    if ($install.Editors) {
        Install-MinGW    # gcc for neovim treesitter
        Install-NodeJS   # npm for LSPs (pyright, markdownlint, etc.)
        Install-CMake    # for telescope-fzf-native and other plugins
        Install-Make     # create make alias from mingw
        Install-Neovim
        Install-VSCode
    }

    if ($install.Python) {
        Install-Python
    }

    if ($install.Configs) {
        Install-Configs
    }

    # Get user configuration preferences (prompts unless -Y)
    $preferences = Get-ConfigurationPreferences

    # Apply git editor preference
    if ($preferences.GitEditor) {
        Set-GitEditor -Editor $preferences.GitEditor
    }

    # Apply VS Code configuration if requested
    if ($preferences.ConfigureVSCode) {
        Set-VSCodeConfig -PythonEnvPath $preferences.PythonEnvPath
    }

    # Apply Windows Terminal configuration if requested
    if ($preferences.ConfigureWindowsTerminal) {
        Set-WindowsTerminalConfig
    }

    # Install git bash profile (powershell profile is symlinked by Install-Configs)
    Install-GitBashProfile

    Show-Summary
}

Main
