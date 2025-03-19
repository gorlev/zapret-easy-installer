@echo off
setlocal enabledelayedexpansion

echo  ______                    _   _____           _        _ _           
echo ^|___  /                   ^| ^| ^|_   _^|         ^| ^|      ^| ^| ^|          
echo    / / __ _ _ __  _ __ ___^| ^|_  ^| ^|  _ __  ___^| ^|_ __ _^| ^| ^| ___ _ __ 
echo   / / / _` ^| '_ \^| '__/ _ \ __^| ^| ^| ^| '_ \/ __^| __/ _` ^| ^| ^|/ _ \ '__^|
echo  / /_^| (_^| ^| ^|_) ^| ^| ^|  __/ ^|_ _^| ^|_^| ^| ^| \__ \ ^|^| (_^| ^| ^| ^|  __/ ^|   
echo /_____\__,_^| .__/^|_^|  \___^|\__^|_____^|_^| ^|_^|___/\__\__,_^|_^|_^|\___^|_^|   
echo            ^| ^|                                                        
echo            ^|_^|                                                        
echo.
echo Zapret Easy Installer for Windows
echo https://github.com/gorlev/zapret-easy-installer
echo.

:: Check for administrator rights
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo This script requires administrator privileges.
    echo Please right-click on the script and select "Run as administrator".
    pause
    exit /b 1
)

:: Create and execute PowerShell script
echo Creating PowerShell installer script...
echo $ErrorActionPreference = 'Stop' > "%TEMP%\zapret_installer.ps1"
echo Write-Host "Starting Zapret Windows installer..." -ForegroundColor Green >> "%TEMP%\zapret_installer.ps1"
echo. >> "%TEMP%\zapret_installer.ps1"

echo # Install curl if not present >> "%TEMP%\zapret_installer.ps1"
echo if (-NOT (Get-Command "curl.exe" -ErrorAction SilentlyContinue)) { >> "%TEMP%\zapret_installer.ps1"
echo     Write-Host "curl not found, installing via PowerShell..." -ForegroundColor Yellow >> "%TEMP%\zapret_installer.ps1"
echo     $ProgressPreference = 'SilentlyContinue' >> "%TEMP%\zapret_installer.ps1"
echo     Invoke-WebRequest -UseBasicParsing -Uri https://curl.se/windows/dl-7.88.1_5/curl-7.88.1_5-win64-mingw.zip -OutFile "$env:TEMP\curl.zip" >> "%TEMP%\zapret_installer.ps1"
echo     Expand-Archive -Path "$env:TEMP\curl.zip" -DestinationPath "$env:TEMP\curl" -Force >> "%TEMP%\zapret_installer.ps1"
echo     Copy-Item "$env:TEMP\curl\curl-7.88.1_5-win64-mingw\bin\curl.exe" -Destination "$env:SystemRoot\System32" -Force >> "%TEMP%\zapret_installer.ps1"
echo } >> "%TEMP%\zapret_installer.ps1"
echo. >> "%TEMP%\zapret_installer.ps1"

echo # Create download directory >> "%TEMP%\zapret_installer.ps1"
echo $downloadDir = "$env:USERPROFILE\Downloads" >> "%TEMP%\zapret_installer.ps1"
echo $extractDir = "$downloadDir\zapret" >> "%TEMP%\zapret_installer.ps1"
echo if (-NOT (Test-Path $extractDir)) { >> "%TEMP%\zapret_installer.ps1"
echo     New-Item -ItemType Directory -Path $extractDir | Out-Null >> "%TEMP%\zapret_installer.ps1"
echo } >> "%TEMP%\zapret_installer.ps1"
echo. >> "%TEMP%\zapret_installer.ps1"

echo # Get latest release info >> "%TEMP%\zapret_installer.ps1"
echo Write-Host "Fetching latest Zapret release information..." -ForegroundColor Cyan >> "%TEMP%\zapret_installer.ps1"
echo $apiUrl = "https://api.github.com/repos/bol-van/zapret/releases/latest" >> "%TEMP%\zapret_installer.ps1"
echo try { >> "%TEMP%\zapret_installer.ps1"
echo     $releaseInfo = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing >> "%TEMP%\zapret_installer.ps1"
echo } catch { >> "%TEMP%\zapret_installer.ps1"
echo     Write-Host "ERROR: Failed to fetch release information. Check your internet connection." -ForegroundColor Red >> "%TEMP%\zapret_installer.ps1"
echo     Write-Host $_.Exception.Message -ForegroundColor Red >> "%TEMP%\zapret_installer.ps1"
echo     pause >> "%TEMP%\zapret_installer.ps1"
echo     exit >> "%TEMP%\zapret_installer.ps1"
echo } >> "%TEMP%\zapret_installer.ps1"
echo. >> "%TEMP%\zapret_installer.ps1"

echo # Find Windows zipfile >> "%TEMP%\zapret_installer.ps1"
echo $zipAsset = $releaseInfo.assets | Where-Object { $_.name -like "*.zip" -and $_.name -notlike "*Source*" } | Select-Object -First 1 >> "%TEMP%\zapret_installer.ps1"
echo if (-NOT $zipAsset) { >> "%TEMP%\zapret_installer.ps1"
echo     Write-Host "ERROR: Could not find Windows ZIP file in the latest release." -ForegroundColor Red >> "%TEMP%\zapret_installer.ps1"
echo     Write-Host "Please check https://github.com/bol-van/zapret/releases for a compatible Windows package." -ForegroundColor Yellow >> "%TEMP%\zapret_installer.ps1"
echo     pause >> "%TEMP%\zapret_installer.ps1"
echo     exit >> "%TEMP%\zapret_installer.ps1"
echo } >> "%TEMP%\zapret_installer.ps1"
echo. >> "%TEMP%\zapret_installer.ps1"

echo $zipUrl = $zipAsset.browser_download_url >> "%TEMP%\zapret_installer.ps1"
echo $zipFile = Join-Path $downloadDir $zipAsset.name >> "%TEMP%\zapret_installer.ps1"
echo Write-Host "Downloading: $zipUrl" -ForegroundColor Cyan >> "%TEMP%\zapret_installer.ps1"
echo. >> "%TEMP%\zapret_installer.ps1"

echo # Download ZIP file >> "%TEMP%\zapret_installer.ps1"
echo try { >> "%TEMP%\zapret_installer.ps1"
echo     Invoke-WebRequest -Uri $zipUrl -OutFile $zipFile -UseBasicParsing >> "%TEMP%\zapret_installer.ps1"
echo } catch { >> "%TEMP%\zapret_installer.ps1"
echo     Write-Host "ERROR: Failed to download Zapret package." -ForegroundColor Red >> "%TEMP%\zapret_installer.ps1"
echo     Write-Host $_.Exception.Message -ForegroundColor Red >> "%TEMP%\zapret_installer.ps1"
echo     pause >> "%TEMP%\zapret_installer.ps1"
echo     exit >> "%TEMP%\zapret_installer.ps1"
echo } >> "%TEMP%\zapret_installer.ps1"
echo. >> "%TEMP%\zapret_installer.ps1"

echo # Find sha256sum file >> "%TEMP%\zapret_installer.ps1"
echo $shaAsset = $releaseInfo.assets | Where-Object { $_.name -eq "sha256sum.txt" } | Select-Object -First 1 >> "%TEMP%\zapret_installer.ps1"
echo if (-NOT $shaAsset) { >> "%TEMP%\zapret_installer.ps1"
echo     Write-Host "WARNING: Could not find checksum file. Proceeding without verification." -ForegroundColor Yellow >> "%TEMP%\zapret_installer.ps1"
echo } else { >> "%TEMP%\zapret_installer.ps1"
echo     $shaUrl = $shaAsset.browser_download_url >> "%TEMP%\zapret_installer.ps1"
echo     $shaFile = Join-Path $downloadDir "sha256sum.txt" >> "%TEMP%\zapret_installer.ps1"
echo     Write-Host "Downloading checksum: $shaUrl" -ForegroundColor Cyan >> "%TEMP%\zapret_installer.ps1"
echo     try { >> "%TEMP%\zapret_installer.ps1"
echo         Invoke-WebRequest -Uri $shaUrl -OutFile $shaFile -UseBasicParsing >> "%TEMP%\zapret_installer.ps1"
echo     } catch { >> "%TEMP%\zapret_installer.ps1"
echo         Write-Host "WARNING: Failed to download checksum file. Proceeding without verification." -ForegroundColor Yellow >> "%TEMP%\zapret_installer.ps1"
echo     } >> "%TEMP%\zapret_installer.ps1"
echo     >> "%TEMP%\zapret_installer.ps1"
echo     # Verify checksum >> "%TEMP%\zapret_installer.ps1"
echo     if (Test-Path $shaFile) { >> "%TEMP%\zapret_installer.ps1"
echo         Write-Host "Verifying file integrity..." -ForegroundColor Cyan >> "%TEMP%\zapret_installer.ps1"
echo         $expectedHash = Get-Content $shaFile | Where-Object { $_ -like "*$($zipAsset.name)*" } | ForEach-Object { ($_ -split '\s+')[0] } >> "%TEMP%\zapret_installer.ps1"
echo         if ($expectedHash) { >> "%TEMP%\zapret_installer.ps1"
echo             $actualHash = (Get-FileHash -Algorithm SHA256 $zipFile).Hash.ToLower() >> "%TEMP%\zapret_installer.ps1"
echo             if ($actualHash -ne $expectedHash.ToLower()) { >> "%TEMP%\zapret_installer.ps1"
echo                 Write-Host "ERROR: Checksum verification failed! Expected: $expectedHash, Got: $actualHash" -ForegroundColor Red >> "%TEMP%\zapret_installer.ps1"
echo                 Write-Host "The downloaded file may be corrupted or tampered with." -ForegroundColor Red >> "%TEMP%\zapret_installer.ps1"
echo                 $continue = Read-Host "Do you want to continue anyway? (y/n)" >> "%TEMP%\zapret_installer.ps1"
echo                 if ($continue -ne "y") { >> "%TEMP%\zapret_installer.ps1"
echo                     pause >> "%TEMP%\zapret_installer.ps1"
echo                     exit >> "%TEMP%\zapret_installer.ps1"
echo                 } >> "%TEMP%\zapret_installer.ps1"
echo             } else { >> "%TEMP%\zapret_installer.ps1"
echo                 Write-Host "Checksum verification passed." -ForegroundColor Green >> "%TEMP%\zapret_installer.ps1"
echo             } >> "%TEMP%\zapret_installer.ps1"
echo         } else { >> "%TEMP%\zapret_installer.ps1"
echo             Write-Host "WARNING: Could not find checksum for ZIP file. Proceeding without verification." -ForegroundColor Yellow >> "%TEMP%\zapret_installer.ps1"
echo         } >> "%TEMP%\zapret_installer.ps1"
echo     } >> "%TEMP%\zapret_installer.ps1"
echo } >> "%TEMP%\zapret_installer.ps1"
echo. >> "%TEMP%\zapret_installer.ps1"

echo # Extract ZIP file >> "%TEMP%\zapret_installer.ps1"
echo Write-Host "Extracting archive..." -ForegroundColor Cyan >> "%TEMP%\zapret_installer.ps1"
echo try { >> "%TEMP%\zapret_installer.ps1"
echo     Expand-Archive -Path $zipFile -DestinationPath $extractDir -Force >> "%TEMP%\zapret_installer.ps1"
echo } catch { >> "%TEMP%\zapret_installer.ps1"
echo     Write-Host "ERROR: Failed to extract ZIP file." -ForegroundColor Red >> "%TEMP%\zapret_installer.ps1"
echo     Write-Host $_.Exception.Message -ForegroundColor Red >> "%TEMP%\zapret_installer.ps1"
echo     pause >> "%TEMP%\zapret_installer.ps1"
echo     exit >> "%TEMP%\zapret_installer.ps1"
echo } >> "%TEMP%\zapret_installer.ps1"
echo. >> "%TEMP%\zapret_installer.ps1"

echo # Find extracted folder >> "%TEMP%\zapret_installer.ps1"
echo $extractedFolders = Get-ChildItem -Path $extractDir -Directory >> "%TEMP%\zapret_installer.ps1"
echo if ($extractedFolders.Count -eq 0) { >> "%TEMP%\zapret_installer.ps1"
echo     Write-Host "ERROR: No folders found in extracted ZIP." -ForegroundColor Red >> "%TEMP%\zapret_installer.ps1"
echo     pause >> "%TEMP%\zapret_installer.ps1"
echo     exit >> "%TEMP%\zapret_installer.ps1"
echo } >> "%TEMP%\zapret_installer.ps1"
echo $zapretFolder = $extractedFolders[0].FullName >> "%TEMP%\zapret_installer.ps1"
echo. >> "%TEMP%\zapret_installer.ps1"

echo # Run windows installer if exists >> "%TEMP%\zapret_installer.ps1"
echo $winInstaller = Join-Path $zapretFolder "install_win.bat" >> "%TEMP%\zapret_installer.ps1"
echo if (Test-Path $winInstaller) { >> "%TEMP%\zapret_installer.ps1"
echo     Write-Host "Running Windows installer..." -ForegroundColor Green >> "%TEMP%\zapret_installer.ps1"
echo     Set-Location $zapretFolder >> "%TEMP%\zapret_installer.ps1"
echo     try { >> "%TEMP%\zapret_installer.ps1"
echo         Start-Process -FilePath $winInstaller -Wait -NoNewWindow >> "%TEMP%\zapret_installer.ps1"
echo     } catch { >> "%TEMP%\zapret_installer.ps1"
echo         Write-Host "ERROR: Failed to run Windows installer." -ForegroundColor Red >> "%TEMP%\zapret_installer.ps1"
echo         Write-Host $_.Exception.Message -ForegroundColor Red >> "%TEMP%\zapret_installer.ps1"
echo     } >> "%TEMP%\zapret_installer.ps1"
echo } else { >> "%TEMP%\zapret_installer.ps1"
echo     Write-Host "ERROR: Windows installer (install_win.bat) not found in extracted files." -ForegroundColor Red >> "%TEMP%\zapret_installer.ps1"
echo     Write-Host "Please check the Zapret documentation for manual installation:" -ForegroundColor Yellow >> "%TEMP%\zapret_installer.ps1"
echo     Write-Host "https://github.com/bol-van/zapret" -ForegroundColor Cyan >> "%TEMP%\zapret_installer.ps1"
echo } >> "%TEMP%\zapret_installer.ps1"
echo. >> "%TEMP%\zapret_installer.ps1"

echo # Cleanup >> "%TEMP%\zapret_installer.ps1"
echo $cleanup = Read-Host "Do you want to clean up downloaded files? (y/n)" >> "%TEMP%\zapret_installer.ps1"
echo if ($cleanup -eq "y") { >> "%TEMP%\zapret_installer.ps1"
echo     Write-Host "Cleaning up downloaded files..." -ForegroundColor Cyan >> "%TEMP%\zapret_installer.ps1"
echo     Remove-Item -Path $zipFile -Force -ErrorAction SilentlyContinue >> "%TEMP%\zapret_installer.ps1"
echo     if (Test-Path $shaFile) { >> "%TEMP%\zapret_installer.ps1"
echo         Remove-Item -Path $shaFile -Force -ErrorAction SilentlyContinue >> "%TEMP%\zapret_installer.ps1"
echo     } >> "%TEMP%\zapret_installer.ps1"
echo     Write-Host "Cleanup completed." -ForegroundColor Green >> "%TEMP%\zapret_installer.ps1"
echo } >> "%TEMP%\zapret_installer.ps1"
echo. >> "%TEMP%\zapret_installer.ps1"

echo Write-Host "`nZapret installation completed!" -ForegroundColor Green >> "%TEMP%\zapret_installer.ps1"
echo Write-Host "Extracted files are located at: $zapretFolder" -ForegroundColor Cyan >> "%TEMP%\zapret_installer.ps1"
echo Write-Host "Thank you for using the Zapret Easy Installer." -ForegroundColor Green >> "%TEMP%\zapret_installer.ps1"
echo Write-Host "Visit https://github.com/bol-van/zapret for more information about Zapret." -ForegroundColor Cyan >> "%TEMP%\zapret_installer.ps1"
echo pause >> "%TEMP%\zapret_installer.ps1"

echo Running PowerShell installer...
powershell -ExecutionPolicy Bypass -File "%TEMP%\zapret_installer.ps1"

echo.
echo Zapret installation completed!
echo.
pause 