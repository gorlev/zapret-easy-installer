#!/bin/sh
#
# Zapret Easy Installer Script
# Supports: OpenWrt, Linux, macOS, Windows (via separate installer)
# Features:
# - Checks for root/admin privileges
# - Installs curl if not available
# - Detects OS type (OpenWrt, Linux, macOS, Windows)
# - Downloads appropriate Zapret package for detected OS
# - Verifies downloaded file with checksum
# - Extracts and installs the package
# - Cleans up after installation
#

cat << "EOF"
 ______                    _   _____           _        _ _           
|___  /                   | | |_   _|         | |      | | |          
   / / __ _ _ __  _ __ ___| |_  | |  _ __  ___| |_ __ _| | | ___ _ __ 
  / / / _` | '_ \| '__/ _ \ __| | | | '_ \/ __| __/ _` | | |/ _ \ '__|
 / /_| (_| | |_) | | |  __/ |_ _| |_| | | \__ \ || (_| | | |  __/ |   
/_____\__,_| .__/|_|  \___|\__|_____|_| |_|___/\__\__,_|_|_|\___|_|   
           | |                                                        
           |_|                                                        
  
Zapret Easy Installer
https://github.com/gorlev/zapret-easy-installer
EOF
echo

# Function to install curl
install_curl() {
    echo "curl not found. Attempting to install..."
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update && apt-get install -y curl
    elif command -v yum >/dev/null 2>&1; then
        yum install -y curl
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y curl
    elif command -v opkg >/dev/null 2>&1; then
        opkg update && opkg install curl
    elif command -v pacman >/dev/null 2>&1; then
        pacman -Sy curl --noconfirm
    elif command -v brew >/dev/null 2>&1; then
        brew install curl
    else
        echo "ERROR: Could not install curl. Please install curl manually and try again."
        exit 1
    fi
    
    # Verify curl was installed
    if ! command -v curl >/dev/null 2>&1; then
        echo "ERROR: Failed to install curl. Please install curl manually and try again."
        exit 1
    fi
    
    echo "curl has been installed successfully!"
}

# Check if curl is installed, try to install if not
if ! command -v curl >/dev/null 2>&1; then
    install_curl
fi

# Detect Windows and run separate installer
if [ "$(uname -s 2>/dev/null)" = "Windows_NT" ] || [ -n "$WINDIR" ] || [ -n "$windir" ]; then
    echo "Windows detected. Creating and running Windows-specific installer..."
    # Create PowerShell script in temp directory
    cat << 'EOF' > ./zapret_installer.ps1
# Zapret Windows Installer
Write-Host "Starting Zapret Windows installer..." -ForegroundColor Green

# Check for admin rights
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "This script requires Administrator privileges. Please run it as Administrator."
    pause
    exit
}

# Install curl if not present
if (-NOT (Get-Command "curl.exe" -ErrorAction SilentlyContinue)) {
    Write-Host "curl not found, installing via PowerShell..." -ForegroundColor Yellow
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -UseBasicParsing -Uri https://curl.se/windows/dl-7.88.1_5/curl-7.88.1_5-win64-mingw.zip -OutFile "$env:TEMP\curl.zip"
    Expand-Archive -Path "$env:TEMP\curl.zip" -DestinationPath "$env:TEMP\curl" -Force
    Copy-Item "$env:TEMP\curl\curl-7.88.1_5-win64-mingw\bin\curl.exe" -Destination "$env:SystemRoot\System32" -Force
}

# Create download directory
$downloadDir = "$env:USERPROFILE\Downloads"
$extractDir = "$downloadDir\zapret"
if (-NOT (Test-Path $extractDir)) {
    New-Item -ItemType Directory -Path $extractDir | Out-Null
}

# Get latest release info
Write-Host "Fetching latest Zapret release information..." -ForegroundColor Cyan
$apiUrl = "https://api.github.com/repos/bol-van/zapret/releases/latest"
$releaseInfo = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing

# Find Windows zipfile
$zipAsset = $releaseInfo.assets | Where-Object { $_.name -like "*.zip" -and $_.name -notlike "*Source*" } | Select-Object -First 1
if (-NOT $zipAsset) {
    Write-Host "ERROR: Could not find Windows ZIP file in the latest release." -ForegroundColor Red
    pause
    exit
}

$zipUrl = $zipAsset.browser_download_url
$zipFile = Join-Path $downloadDir $zipAsset.name
Write-Host "Downloading: $zipUrl" -ForegroundColor Cyan

# Download ZIP file
Invoke-WebRequest -Uri $zipUrl -OutFile $zipFile -UseBasicParsing

# Find sha256sum file
$shaAsset = $releaseInfo.assets | Where-Object { $_.name -eq "sha256sum.txt" } | Select-Object -First 1
if (-NOT $shaAsset) {
    Write-Host "WARNING: Could not find checksum file. Proceeding without verification." -ForegroundColor Yellow
} else {
    $shaUrl = $shaAsset.browser_download_url
    $shaFile = Join-Path $downloadDir "sha256sum.txt"
    Write-Host "Downloading checksum: $shaUrl" -ForegroundColor Cyan
    Invoke-WebRequest -Uri $shaUrl -OutFile $shaFile -UseBasicParsing
    
    # Verify checksum
    Write-Host "Verifying file integrity..." -ForegroundColor Cyan
    $expectedHash = Get-Content $shaFile | Where-Object { $_ -like "*$($zipAsset.name)*" } | ForEach-Object { ($_ -split '\s+')[0] }
    if ($expectedHash) {
        $actualHash = (Get-FileHash -Algorithm SHA256 $zipFile).Hash.ToLower()
        if ($actualHash -ne $expectedHash.ToLower()) {
            Write-Host "ERROR: Checksum verification failed! Expected: $expectedHash, Got: $actualHash" -ForegroundColor Red
            pause
            exit
        }
        Write-Host "Checksum verification passed." -ForegroundColor Green
    } else {
        Write-Host "WARNING: Could not find checksum for ZIP file. Proceeding without verification." -ForegroundColor Yellow
    }
}

# Extract ZIP file
Write-Host "Extracting archive..." -ForegroundColor Cyan
Expand-Archive -Path $zipFile -DestinationPath $extractDir -Force

# Find extracted folder
$extractedFolders = Get-ChildItem -Path $extractDir -Directory
if ($extractedFolders.Count -eq 0) {
    Write-Host "ERROR: No folders found in extracted ZIP." -ForegroundColor Red
    pause
    exit
}
$zapretFolder = $extractedFolders[0].FullName

# Run windows installer if exists
$winInstaller = Join-Path $zapretFolder "install_win.bat"
if (Test-Path $winInstaller) {
    Write-Host "Running Windows installer..." -ForegroundColor Green
    Set-Location $zapretFolder
    Start-Process -FilePath $winInstaller -Wait -NoNewWindow
} else {
    Write-Host "ERROR: Windows installer (install_win.bat) not found in extracted files." -ForegroundColor Red
    Write-Host "Please check the Zapret documentation for manual installation." -ForegroundColor Yellow
}

Write-Host "`nZapret installation completed!" -ForegroundColor Green
Write-Host "Extracted files are located at: $zapretFolder" -ForegroundColor Cyan
Write-Host "You can delete downloaded files from $downloadDir if installation was successful." -ForegroundColor Cyan
pause
EOF

    # Run the PowerShell script
    powershell -ExecutionPolicy Bypass -File ./zapret_installer.ps1
    exit 0
fi

########################################
# 1) Check for root / sudo permission
########################################
if [ "$(id -u 2>/dev/null)" != "0" ]; then
    echo "Please run this script as root (or with sudo)."
    echo "Example: sudo sh install_zapret.sh"
    exit 1
fi

########################################
# 2) Detect OS, vendor
########################################
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"   # e.g. linux, darwin, freebsd
ARCH="$(uname -m)"
OS_VENDOR=""

if [ -f "/etc/os-release" ]; then
    . /etc/os-release
    OS_VENDOR="$ID"  # e.g. ubuntu, debian, openwrt, etc.
fi

# Special check for OpenWrt
if [ -f "/etc/openwrt_release" ]; then
    OS_VENDOR="openwrt"
fi

echo "System detection:"
echo "  OS       = $OS"
echo "  ARCH     = $ARCH"
[ -n "$OS_VENDOR" ] && echo "  VENDOR   = $OS_VENDOR"
echo

########################################
# 3) Set up directories based on OS
########################################
if [ "$OS_VENDOR" = "openwrt" ]; then
    DOWNLOAD_DIR="/tmp"
    EXTRACT_DIR="/tmp/zapret"
    echo "Using OpenWrt paths: $DOWNLOAD_DIR and $EXTRACT_DIR"
elif [ "$OS" = "darwin" ]; then
    DOWNLOAD_DIR="$HOME/Downloads"
    EXTRACT_DIR="$HOME/Downloads/zapret"
    echo "Using macOS paths: $DOWNLOAD_DIR and $EXTRACT_DIR"
else
    # For Linux
    DOWNLOAD_DIR="/tmp"
    EXTRACT_DIR="/tmp/zapret"
    echo "Using Linux paths: $DOWNLOAD_DIR and $EXTRACT_DIR"
fi

# Create directories
mkdir -p "$DOWNLOAD_DIR" "$EXTRACT_DIR"

########################################
# 4) Fetch the latest release info from GitHub
########################################
GH_API_URL="https://api.github.com/repos/bol-van/zapret/releases/latest"
echo "Fetching latest release info from GitHub: $GH_API_URL"

LATEST_JSON="$(curl -sSL "$GH_API_URL")"
if [ -z "$LATEST_JSON" ]; then
    echo "ERROR: Could not retrieve data from GitHub API. Please check your connection."
    exit 1
fi

# Extract version number for better asset filtering
VERSION="$(echo "$LATEST_JSON" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')"
echo "Latest version: $VERSION"

########################################
# 5) Find the correct asset based on OS
########################################
TARBALL_URL=""
if [ "$OS_VENDOR" = "openwrt" ]; then
    # Look for OpenWrt embedded tarball
    echo "Looking for OpenWrt specific package..."
    TARBALL_URL="$(echo "$LATEST_JSON" \
        | grep "browser_download_url" \
        | grep "openwrt" \
        | grep "embedded" \
        | grep "tar.gz" \
        | cut -d '"' -f 4 \
        | head -n1)"
elif [ "$OS" = "darwin" ]; then
    # For macOS, get the regular tarball
    echo "Looking for macOS compatible package..."
    TARBALL_URL="$(echo "$LATEST_JSON" \
        | grep "browser_download_url" \
        | grep "tar.gz" \
        | grep -v "openwrt" \
        | grep -v "embedded" \
        | grep -v "Source" \
        | cut -d '"' -f 4 \
        | head -n1)"
else
    # For Linux
    echo "Looking for Linux compatible package..."
    TARBALL_URL="$(echo "$LATEST_JSON" \
        | grep "browser_download_url" \
        | grep "tar.gz" \
        | grep -v "openwrt" \
        | grep -v "embedded" \
        | grep -v "Source" \
        | cut -d '"' -f 4 \
        | head -n1)"
fi

if [ -z "$TARBALL_URL" ]; then
    echo "ERROR: Could not find a suitable package for this system."
    echo "Please check: https://github.com/bol-van/zapret/releases"
    exit 1
fi

########################################
# 6) Find sha256sum.txt
########################################
SHA256SUM_URL="$(echo "$LATEST_JSON" \
    | grep "browser_download_url" \
    | grep "sha256sum.txt" \
    | cut -d '"' -f 4 \
    | head -n1)"

if [ -z "$SHA256SUM_URL" ]; then
    echo "WARNING: No sha256sum.txt found in the release assets."
    echo "Proceeding without checksum verification."
fi

echo "Download URLs:"
echo "  PACKAGE     = $TARBALL_URL"
[ -n "$SHA256SUM_URL" ] && echo "  SHA256SUM   = $SHA256SUM_URL"
echo

########################################
# 7) Download the package and sha256sum.txt
########################################
cd "$DOWNLOAD_DIR" || exit 1
TARBALL_FILE="$(basename "$TARBALL_URL")"

echo "Downloading: $TARBALL_FILE"
if ! curl -sSLO "$TARBALL_URL"; then
    echo "ERROR: Failed to download $TARBALL_URL"
    exit 1
fi

if [ ! -f "$TARBALL_FILE" ]; then
    echo "ERROR: Downloaded file not found: $TARBALL_FILE"
    exit 1
fi

# Download SHA256SUM file if available
if [ -n "$SHA256SUM_URL" ]; then
    SUM_FILE="$(basename "$SHA256SUM_URL")"
    echo "Downloading: $SUM_FILE"
    
    if ! curl -sSLO "$SHA256SUM_URL"; then
        echo "WARNING: Failed to download SHA256SUM file. Proceeding without verification."
    elif [ ! -f "$SUM_FILE" ]; then
        echo "WARNING: Downloaded SHA256SUM file not found. Proceeding without verification."
    fi
fi

########################################
# 8) Verify checksum if available
########################################
if [ -f "$SUM_FILE" ]; then
    echo "Verifying checksum for $TARBALL_FILE..."
    
    # Extract expected checksum for our file
    EXPECTED_SUM=$(grep "$TARBALL_FILE" "$SUM_FILE" | cut -d ' ' -f 1)
    if [ -z "$EXPECTED_SUM" ]; then
        echo "WARNING: Could not find checksum for $TARBALL_FILE in $SUM_FILE."
        echo "Proceeding without verification."
    else
        # Calculate actual checksum
        if command -v sha256sum >/dev/null 2>&1; then
            ACTUAL_SUM=$(sha256sum "$TARBALL_FILE" | cut -d ' ' -f 1)
        elif command -v shasum >/dev/null 2>&1; then
            ACTUAL_SUM=$(shasum -a 256 "$TARBALL_FILE" | cut -d ' ' -f 1)
        else
            echo "WARNING: Neither sha256sum nor shasum found. Skipping verification."
            ACTUAL_SUM=""
        fi
        
        # Compare checksums
        if [ -n "$ACTUAL_SUM" ]; then
            if [ "$ACTUAL_SUM" = "$EXPECTED_SUM" ]; then
                echo "Checksum verification PASSED!"
            else
                echo "ERROR: Checksum verification FAILED!"
                echo "Expected: $EXPECTED_SUM"
                echo "Actual:   $ACTUAL_SUM"
                echo "Aborting installation due to integrity failure."
                exit 1
            fi
        fi
    fi
fi

########################################
# 9) Extract package to temporary directory
########################################
echo "Extracting archive: $TARBALL_FILE to $EXTRACT_DIR"
mkdir -p "$EXTRACT_DIR"
tar -xzf "$TARBALL_FILE" -C "$EXTRACT_DIR"

# Find the top-level directory in the extracted archive
ARCHIVE_DIR=$(find "$EXTRACT_DIR" -maxdepth 1 -type d | grep -v "^$EXTRACT_DIR$" | head -1)
if [ -z "$ARCHIVE_DIR" ]; then
    echo "ERROR: Could not find extracted directory."
    exit 1
fi

echo "Extracted to: $ARCHIVE_DIR"

########################################
# 10) Run the installation scripts
########################################
cd "$ARCHIVE_DIR" || {
    echo "ERROR: Cannot access $ARCHIVE_DIR"
    exit 1
}

# Check if the required install scripts exist
if [ ! -f "install_bin.sh" ] || [ ! -f "install_prereq.sh" ] || [ ! -f "install_easy.sh" ]; then
    echo "ERROR: One or more installation scripts not found."
    echo "Please check the extracted files in $ARCHIVE_DIR"
    exit 1
fi

# Make scripts executable
chmod +x install_bin.sh install_prereq.sh install_easy.sh

echo "==> Running install_bin.sh..."
./install_bin.sh

echo "==> Running install_prereq.sh..."
./install_prereq.sh

echo "==> Running install_easy.sh..."
./install_easy.sh

########################################
# 11) Cleanup
########################################
echo
echo "Installation steps completed."

# Ask if the user wants to clean up downloaded files
printf "Do you want to clean up downloaded files? (y/n): "
read -r CLEANUP
if [ "$CLEANUP" = "y" ] || [ "$CLEANUP" = "Y" ]; then
    echo "Cleaning up..."
    cd /
    rm -f "$DOWNLOAD_DIR/$TARBALL_FILE"
    rm -f "$DOWNLOAD_DIR/$SUM_FILE"
    rm -rf "$EXTRACT_DIR"
    echo "Cleanup done."
fi

echo
echo "Zapret installation is complete!"
echo "Thank you for using the Zapret Easy Installer."
echo "Visit https://github.com/bol-van/zapret for more information about Zapret."