<#
    Zapret Easy Installer for Windows
    https://github.com/gorlev/zapret-easy-installer

    Downloads the official zapret-win-bundle (https://github.com/bol-van/zapret-win-bundle),
    which contains winws (zapret) and winws2 (zapret2), and helps you run blockcheck,
    test a strategy and install it as a Windows service.

    Usage (PowerShell):
        irm https://raw.githubusercontent.com/gorlev/zapret-easy-installer/main/install_zapret.ps1 | iex
    or
        powershell -ExecutionPolicy Bypass -File install_zapret.ps1 [-Flavor 1|2] [-InstallDir C:\zapret]

    Environment variables: ZAPRET_FLAVOR=1|2, ZAPRET_DIR=<path>
#>
[CmdletBinding()]
param(
    [ValidateSet('', '1', '2')]
    [string]$Flavor = $env:ZAPRET_FLAVOR,
    [string]$InstallDir = $env:ZAPRET_DIR,
    [switch]$SkipDownload
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'   # Invoke-WebRequest is very slow with the progress bar on PS 5.1

$InstallerUrl = 'https://raw.githubusercontent.com/gorlev/zapret-easy-installer/main/install_zapret.ps1'
$BundleRepo   = 'bol-van/zapret-win-bundle'
$BundleBranch = 'master'
if (-not $InstallDir) { $InstallDir = 'C:\zapret' }

# ---------------------------------------------------------------- helpers
function Write-Info($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Err($msg)  { Write-Host "[ERROR] $msg" -ForegroundColor Red }

function Exit-Installer([int]$code = 0) {
    Write-Host ''
    Read-Host 'Press Enter to exit' | Out-Null
    exit $code
}

function Read-YesNo([string]$question, [bool]$default = $false) {
    $hint = if ($default) { '[Y/n]' } else { '[y/N]' }
    $answer = Read-Host "$question $hint"
    if ([string]::IsNullOrWhiteSpace($answer)) { return $default }
    return $answer.Trim().ToLower().StartsWith('y')
}

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    return ([Security.Principal.WindowsPrincipal]$id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ---------------------------------------------------------------- elevation
# When started via "irm | iex" the installer always continues in its own elevated window,
# so "exit" never closes the user's PowerShell session.
if (-not (Test-Admin) -or -not $PSCommandPath) {
    Write-Info 'Starting the installer in an elevated PowerShell window...'
    $scriptPath = $PSCommandPath
    if (-not $scriptPath) {
        # Running via "irm | iex": save a copy of the installer so it can be started as a file.
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        $scriptPath = Join-Path $env:TEMP 'zapret_easy_installer.ps1'
        Invoke-WebRequest -UseBasicParsing -Uri $InstallerUrl -OutFile $scriptPath
    }
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$scriptPath`"", '-InstallDir', "`"$InstallDir`"")
    if ($Flavor) { $argList += @('-Flavor', $Flavor) }
    try {
        Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $argList
    } catch {
        Write-Err 'Elevation was cancelled. Please run the installer as Administrator.'
        Exit-Installer 1
    }
    return
}

[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

Clear-Host
Write-Host @'
 ______                    _     _____
|___  /                   | |   |  ___|
   / / __ _ _ __  _ __ ___| |_  | |__  __ _ ___ _   _
  / / / _` | '_ \| '__/ _ \ __| |  __|/ _` / __| | | |
./ /_| (_| | |_) | | |  __/ |_  | |__| (_| \__ \ |_| |
\_____\__,_| .__/|_|  \___|\__| \____/\__,_|___/\__, |
           | |                                   __/ |
           |_|          Easy Installer          |___/
'@ -ForegroundColor Cyan
Write-Host 'https://github.com/gorlev/zapret-easy-installer'
Write-Host ''

# ---------------------------------------------------------------- system checks
if (-not [Environment]::Is64BitOperatingSystem) {
    Write-Err 'zapret for Windows requires a 64-bit version of Windows.'
    Exit-Installer 1
}
$osArch = $env:PROCESSOR_ARCHITECTURE
if ($env:PROCESSOR_ARCHITEW6432) { $osArch = $env:PROCESSOR_ARCHITEW6432 }
$isArm64 = $osArch -eq 'ARM64'
$osVersion = [Environment]::OSVersion.Version
$isWin7 = ($osVersion.Major -eq 6 -and $osVersion.Minor -le 1)

if ($InstallDir -match '\s') {
    Write-Warn "The install path '$InstallDir' contains spaces. A path without spaces (e.g. C:\zapret) is strongly recommended."
}

# ---------------------------------------------------------------- flavor
if (-not $Flavor) {
    Write-Host 'Which version do you want to use?' -ForegroundColor White
    Write-Host '  1) zapret   (winws.exe)  - stable and mature, best choice for most users (recommended)'
    Write-Host '  2) zapret2  (winws2.exe) - next generation, Lua based strategies; for advanced users'
    $choice = Read-Host 'Enter choice [1]'
    switch ($choice.Trim()) {
        ''      { $Flavor = '1' }
        '1'     { $Flavor = '1' }
        '2'     { $Flavor = '2' }
        default { Write-Err "Invalid choice: $choice"; Exit-Installer 1 }
    }
}

if ($Flavor -eq '2') {
    $Project      = 'zapret2'
    $ServiceName  = 'zapret2'
    $ExeName      = 'winws2.exe'
    $PresetFile   = 'preset2_example.cmd'
    $BlockcheckCmd = 'blockcheck2.cmd'
} else {
    $Project      = 'zapret'
    $ServiceName  = 'zapret'
    $ExeName      = 'winws.exe'
    $PresetFile   = 'preset1_example.cmd'
    $BlockcheckCmd = 'blockcheck.cmd'
}
$AllServiceNames = @('zapret', 'zapret2', 'winws1', 'winws2')   # ours + the names used by the bundle's own scripts

$WinwsDir     = Join-Path $InstallDir 'zapret-winws'
$ExePath      = Join-Path $WinwsDir $ExeName
$StrategyFile = Join-Path $InstallDir "strategy-$Project.txt"
$BlockcheckPath = Join-Path $InstallDir "blockcheck\$BlockcheckCmd"

Write-Info "Selected: $Project, install folder: $InstallDir"

# ---------------------------------------------------------------- stop running instances
function Stop-Zapret {
    foreach ($name in $AllServiceNames) {
        $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
        if ($svc -and $svc.Status -ne 'Stopped') {
            Write-Info "Stopping service $name..."
            Stop-Service -Name $name -Force -ErrorAction SilentlyContinue
        }
    }
    Get-Process -Name 'winws', 'winws2' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 500
}

function Remove-ZapretServices {
    foreach ($name in $AllServiceNames) {
        if (Get-Service -Name $name -ErrorAction SilentlyContinue) {
            Write-Info "Removing service $name..."
            Stop-Service -Name $name -Force -ErrorAction SilentlyContinue
            & sc.exe delete $name | Out-Null
        }
    }
}

function Remove-WinDivert {
    foreach ($name in @('WinDivert', 'WinDivert14')) {
        if (Get-Service -Name $name -ErrorAction SilentlyContinue) {
            & sc.exe stop $name | Out-Null
            & sc.exe delete $name | Out-Null
        }
    }
}

# ---------------------------------------------------------------- download bundle
function Install-Bundle {
    $commitSha = $null
    try {
        $commit = Invoke-RestMethod -UseBasicParsing -Uri "https://api.github.com/repos/$BundleRepo/commits/$BundleBranch"
        $commitSha = $commit.sha
        Write-Info "Latest zapret-win-bundle commit: $($commitSha.Substring(0, 12)) ($($commit.commit.committer.date))"
    } catch {
        Write-Warn 'Could not query the GitHub API (rate limit?). Downloading the current branch instead.'
    }
    $ref = if ($commitSha) { $commitSha } else { $BundleBranch }
    $zipUrl = "https://github.com/$BundleRepo/archive/$ref.zip"

    $tmp = Join-Path $env:TEMP ("zapret-installer-" + [Guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    $zipFile = Join-Path $tmp 'bundle.zip'
    try {
        Write-Info "Downloading $zipUrl ..."
        Invoke-WebRequest -UseBasicParsing -Uri $zipUrl -OutFile $zipFile
        Write-Info 'Extracting...'
        Expand-Archive -Path $zipFile -DestinationPath $tmp -Force
        $root = Get-ChildItem -Path $tmp -Directory | Where-Object { $_.Name -like 'zapret-win-bundle-*' } | Select-Object -First 1
        if (-not $root -or -not (Test-Path (Join-Path $root.FullName 'zapret-winws'))) {
            throw 'Unexpected archive layout (zapret-winws folder not found).'
        }

        Stop-Zapret
        Remove-WinDivert   # unload the driver so WinDivert64.sys can be replaced
        if (Test-Path $InstallDir) {
            Write-Info "Updating existing installation in $InstallDir (strategy files are kept)..."
            Get-ChildItem -Path $InstallDir -Force | Where-Object { $_.Name -notlike 'strategy-*.txt' } |
                Remove-Item -Recurse -Force -ErrorAction Stop
        } else {
            New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
        }
        Copy-Item -Path (Join-Path $root.FullName '*') -Destination $InstallDir -Recurse -Force
        if ($commitSha) { Set-Content -Path (Join-Path $InstallDir 'BUNDLE_COMMIT.txt') -Value $commitSha -Encoding ASCII }
        Write-Ok "zapret-win-bundle installed to $InstallDir"
    } finally {
        Remove-Item -Path $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Cross-check winws against the official zapret / zapret2 release checksums (informational).
function Test-AgainstRelease {
    $repo = "bol-van/$Project"
    try {
        $release = Invoke-RestMethod -UseBasicParsing -Uri "https://api.github.com/repos/$repo/releases/latest"
        $asset = $release.assets | Where-Object { $_.name -eq 'sha256sum.txt' } | Select-Object -First 1
        if (-not $asset) { return }
        $sumFile = Join-Path $env:TEMP 'zapret_sha256sum.txt'
        Invoke-WebRequest -UseBasicParsing -Uri $asset.browser_download_url -OutFile $sumFile
        $sums = Get-Content -Path $sumFile
        Remove-Item -Path $sumFile -Force -ErrorAction SilentlyContinue
        $line = $sums | Where-Object { $_ -match "/binaries/windows-x86_64/$([regex]::Escape($ExeName))\s*$" } | Select-Object -First 1
        if (-not $line) { return }
        $expected = ($line -split '\s+')[0].ToLower()
        $actual = (Get-FileHash -Algorithm SHA256 -Path $ExePath).Hash.ToLower()
        if ($expected -eq $actual) {
            Write-Ok "$ExeName matches the official $Project $($release.tag_name) release checksum."
        } else {
            Write-Warn "$ExeName differs from the $Project $($release.tag_name) release build. This is normal when the bundle is newer than the last release."
        }
    } catch {
        Write-Warn "Could not cross-check $ExeName with the official release (offline or rate limited)."
    }
}

# ---------------------------------------------------------------- strategy file
# The strategy file holds winws/winws2 arguments, one or more per line. Lines starting with # are comments.
# It is seeded from the bundle's example preset, which is NOT a ready-made solution.
function New-StrategyFile {
    $preset = Join-Path $WinwsDir $PresetFile
    if (-not (Test-Path $preset)) { throw "$PresetFile not found in the bundle." }

    $content = Get-Content -Path $preset -Raw
    # Take everything after the executable name and turn the cmd syntax into plain arguments.
    $idx = $content.IndexOf($ExeName + '"')
    if ($idx -lt 0) { throw "Could not parse $PresetFile." }
    $argsText = $content.Substring($idx + $ExeName.Length + 1)
    $winwsDirSlash = $WinwsDir.TrimEnd('\') + '\'
    $argsText = $argsText.Replace('%~dp0', $winwsDirSlash)
    $lines = $argsText -split "`r?`n" | ForEach-Object { ($_ -replace '\^\s*$', '').Trim() } | Where-Object { $_ }

    $header = @(
        "# zapret-easy-installer strategy file for $ExeName",
        "# Generated from the bundle's $PresetFile example. This is an EXAMPLE, not a ready-made solution.",
        "# Replace it with a strategy that blockcheck finds for your ISP, then choose 'Install as a service' again.",
        "# One or more arguments per line. Lines starting with # are ignored.",
        "# Reference: https://github.com/bol-van/$Project",
        ''
    )
    Set-Content -Path $StrategyFile -Value ($header + $lines) -Encoding ASCII
    Write-Ok "Example strategy written to $StrategyFile"
}

function Get-StrategyArgs {
    if (-not (Test-Path $StrategyFile)) { New-StrategyFile }
    $parts = Get-Content -Path $StrategyFile | ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not $_.StartsWith('#') }
    $joined = ($parts -join ' ').Trim()
    if (-not $joined) { throw "The strategy file $StrategyFile is empty." }
    return $joined
}

# ---------------------------------------------------------------- actions
function Invoke-Blockcheck {
    if (-not (Test-Path $BlockcheckPath)) { Write-Err "$BlockcheckPath not found."; return }
    Stop-Zapret
    Write-Info 'blockcheck opens in a new window. It tests many strategies and can take a long time.'
    Write-Info 'When it finishes, copy the working winws arguments from its summary into:'
    Write-Host "     $StrategyFile" -ForegroundColor White
    Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', "`"$BlockcheckPath`"" -WorkingDirectory (Split-Path $BlockcheckPath)
}

function Start-Test {
    $argLine = Get-StrategyArgs
    Stop-Zapret
    Write-Info "Starting $ExeName in a new window with the strategy from $StrategyFile"
    Write-Info 'Check if the blocked sites open now. Close that window (or press Ctrl+C in it) to stop.'
    Start-Process -FilePath $ExePath -ArgumentList $argLine -WorkingDirectory $WinwsDir
}

function Install-Service {
    $argLine = Get-StrategyArgs
    Write-Warn 'The service starts automatically with Windows and runs the strategy file below:'
    Write-Host "     $StrategyFile" -ForegroundColor White
    Write-Warn 'A wrong strategy can break connections to some sites. You can always remove the service from this menu.'
    if (-not (Read-YesNo 'Install the service now?' $false)) { return }

    Stop-Zapret
    Remove-ZapretServices
    $binPath = "`"$ExePath`" $argLine"
    New-Service -Name $ServiceName -BinaryPathName $binPath -DisplayName "zapret DPI bypass ($Project)" `
        -Description "zapret DPI bypass ($ExeName), installed by zapret-easy-installer" -StartupType Automatic | Out-Null
    Start-Service -Name $ServiceName
    Start-Sleep -Seconds 2
    $svc = Get-Service -Name $ServiceName
    if ($svc.Status -eq 'Running') {
        Write-Ok "Service '$ServiceName' is installed and running."
    } else {
        Write-Err "Service '$ServiceName' was created but is not running (status: $($svc.Status)). Test the strategy with option 2 first."
    }
}

function Show-Status {
    foreach ($name in $AllServiceNames) {
        $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
        if ($svc) { Write-Host ("  service {0,-8}: {1} ({2})" -f $name, $svc.Status, $svc.StartType) }
    }
    $procs = Get-Process -Name 'winws', 'winws2' -ErrorAction SilentlyContinue
    if ($procs) { $procs | ForEach-Object { Write-Host "  process     : $($_.ProcessName).exe (PID $($_.Id))" } }
    if (-not $procs -and -not ($AllServiceNames | Where-Object { Get-Service -Name $_ -ErrorAction SilentlyContinue })) {
        Write-Host '  zapret is not running.'
    }
}

function Uninstall-Zapret {
    if (-not (Read-YesNo "Remove all zapret services, the WinDivert driver and $InstallDir ?" $false)) { return $false }
    Stop-Zapret
    Remove-ZapretServices
    Remove-WinDivert
    if (Test-Path $InstallDir) {
        Remove-Item -Path $InstallDir -Recurse -Force -ErrorAction SilentlyContinue
        if (Test-Path $InstallDir) { Write-Warn "Some files in $InstallDir could not be removed. Reboot and delete the folder manually." }
    }
    Write-Ok 'zapret has been removed.'
    return $true
}

# ---------------------------------------------------------------- main
try {
    $installed = Test-Path $ExePath
    if ($SkipDownload -and $installed) {
        Write-Info 'Skipping download, using the existing installation.'
    } elseif ($installed) {
        if (Read-YesNo "An installation was found in $InstallDir. Update it to the latest bundle?" $true) { Install-Bundle }
    } else {
        Install-Bundle
    }
    if (-not (Test-Path $ExePath)) { throw "$ExePath not found after installation." }
    Test-AgainstRelease
    if (-not (Test-Path $StrategyFile)) { New-StrategyFile }
} catch {
    Write-Err $_.Exception.Message
    Exit-Installer 1
}

if ($isArm64) {
    Write-Warn 'ARM64 Windows detected. WinDivert needs test-signing mode on ARM64:'
    Write-Warn "  run $InstallDir\arm64\install_arm64.cmd once and reboot before starting zapret."
}
if ($isWin7) {
    Write-Warn "Windows 7 detected. If WinDivert does not load, run $InstallDir\win7\install_win7.cmd"
}

while ($true) {
    Write-Host ''
    Write-Host "zapret easy installer - $Project ($ExeName)" -ForegroundColor White
    Write-Host '  1) Run blockcheck (find a strategy that works with your ISP)'
    Write-Host '  2) Test the strategy now (runs in a window until you close it)'
    Write-Host '  3) Install as a Windows service (start automatically with Windows)'
    Write-Host '  4) Edit the strategy file'
    Write-Host '  5) Show status'
    Write-Host '  6) Stop and remove the service'
    Write-Host '  7) Uninstall everything'
    Write-Host '  0) Exit'
    $sel = Read-Host 'Select'
    try {
        switch ($sel.Trim()) {
            '1' { Invoke-Blockcheck }
            '2' { Start-Test }
            '3' { Install-Service }
            '4' { Start-Process -FilePath 'notepad.exe' -ArgumentList "`"$StrategyFile`"" }
            '5' { Show-Status }
            '6' { Stop-Zapret; Remove-ZapretServices; Write-Ok 'Services removed.' }
            '7' { if (Uninstall-Zapret) { Exit-Installer 0 } }
            '0' { exit 0 }
            ''  { exit 0 }
            default { Write-Warn "Unknown option: $sel" }
        }
    } catch {
        Write-Err $_.Exception.Message
    }
}
