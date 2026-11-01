# SICSENSE - Safe PC Maintenance Tool
# Compatible with Windows PowerShell 5.1 and Windows 10/11.
# This script removes temporary/cache files only. It does not disable services,
# change Registry settings, or promise an FPS increase.

$ErrorActionPreference = 'Continue'
$Host.UI.RawUI.WindowTitle = 'SICSENSE | PC Maintenance'

function Test-IsAdministrator {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        return $false
    }
}

# Relaunch elevated so Windows temp and update-cache folders can be cleaned.
if (-not (Test-IsAdministrator)) {
    if ([string]::IsNullOrWhiteSpace($PSCommandPath)) {
        Write-Host 'Please save and run this script as a .ps1 file.' -ForegroundColor Yellow
        Read-Host 'Press Enter to exit'
        exit
    }

    try {
        $quotedPath = '"' + $PSCommandPath + '"'
        $arguments = '-NoProfile -ExecutionPolicy Bypass -File ' + $quotedPath
        Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList $arguments -Verb RunAs
    }
    catch {
        Write-Host 'Administrator permission was not granted. SICSENSE cannot continue.' -ForegroundColor Red
        Read-Host 'Press Enter to exit'
    }
    exit
}

function Write-Section {
    param([string]$Text)
    Write-Host ''
    Write-Host ('  ' + $Text) -ForegroundColor Cyan
    Write-Host '  ------------------------------------------------------------' -ForegroundColor DarkGray
}

function Wait-ForKey {
    Write-Host ''
    [void](Read-Host 'Press Enter to return to the main menu')
}

function Confirm-Action {
    param([string]$Question)
    $answer = Read-Host ($Question + ' [Y/N]')
    return ($answer -match '^(?i:y|yes)$')
}

function Clear-DirectoryContents {
    param([Parameter(Mandatory = $true)][string]$Path)

    $removed = 0
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        return 0
    }

    try {
        $items = @(Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue)
        foreach ($item in $items) {
            try {
                # Do not follow junctions/symbolic links into unrelated folders.
                if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                    Remove-Item -LiteralPath $item.FullName -Force -ErrorAction Stop
                }
                else {
                    Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction Stop
                }
                $removed++
            }
            catch {
                # Locked or protected items are skipped; cleanup continues.
            }
        }
    }
    catch {
        # An inaccessible folder is skipped.
    }

    return $removed
}

function Clear-ListedFolders {
    param([array]$Folders)

    foreach ($folder in $Folders) {
        if ([string]::IsNullOrWhiteSpace($folder.Path)) { continue }

        if (Test-Path -LiteralPath $folder.Path -PathType Container) {
            $count = Clear-DirectoryContents -Path $folder.Path
            Write-Host ('  [OK] {0} - {1} item(s) removed' -f $folder.Name, $count) -ForegroundColor Green
        }
        else {
            Write-Host ('  [--] {0} - folder not found' -f $folder.Name) -ForegroundColor DarkGray
        }
    }
}

function Invoke-TemporaryCleanup {
    Write-Section '01 / TEMPORARY FILES'
    Write-Host 'Cleaning temporary files and crash dumps...' -ForegroundColor Gray

    $folders = @(
        [pscustomobject]@{ Name = 'User TEMP';       Path = $env:TEMP },
        [pscustomobject]@{ Name = 'Local TEMP';      Path = (Join-Path $env:LOCALAPPDATA 'Temp') },
        [pscustomobject]@{ Name = 'Windows TEMP';    Path = (Join-Path $env:WINDIR 'Temp') },
        [pscustomobject]@{ Name = 'Crash dump files';Path = (Join-Path $env:LOCALAPPDATA 'CrashDumps') }
    )

    $seen = @{}
    $uniqueFolders = @()
    foreach ($folder in $folders) {
        if (-not [string]::IsNullOrWhiteSpace($folder.Path)) {
            $key = $folder.Path.TrimEnd('\').ToLowerInvariant()
            if (-not $seen.ContainsKey($key)) {
                $seen[$key] = $true
                $uniqueFolders += $folder
            }
        }
    }
    Clear-ListedFolders -Folders $uniqueFolders

    if (Confirm-Action 'Empty the Recycle Bin? This permanently deletes its contents.') {
        try {
            Clear-RecycleBin -Force -ErrorAction Stop
            Write-Host '  [OK] Recycle Bin emptied' -ForegroundColor Green
        }
        catch {
            Write-Host ('  [!] Recycle Bin could not be emptied: ' + $_.Exception.Message) -ForegroundColor Yellow
        }
    }
    else {
        Write-Host '  [--] Recycle Bin left unchanged' -ForegroundColor DarkGray
    }
}

function Invoke-BrowserCacheCleanup {
    Write-Section '02 / BROWSER CACHE'
    Write-Host 'Only cache folders are targeted. Cookies, passwords, bookmarks and history are kept.' -ForegroundColor Gray

    $runningBrowsers = @(Get-Process -Name chrome, msedge, firefox -ErrorAction SilentlyContinue)
    if ($runningBrowsers.Count -gt 0) {
        $names = ($runningBrowsers | Select-Object -ExpandProperty ProcessName -Unique) -join ', '
        Write-Host ('  [!] Close your browser(s) and run this option again: ' + $names) -ForegroundColor Yellow
        return
    }

    $cachePaths = @()
    $chromiumRoots = @(
        (Join-Path $env:LOCALAPPDATA 'Google\Chrome\User Data'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\User Data')
    )
    $cacheFolders = @('Cache', 'Network\Cache', 'Code Cache', 'GPUCache')

    foreach ($root in $chromiumRoots) {
        if (Test-Path -LiteralPath $root -PathType Container) {
            $profiles = @(Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -eq 'Default' -or $_.Name -like 'Profile *' })

            foreach ($profile in $profiles) {
                foreach ($relative in $cacheFolders) {
                    $cachePaths += (Join-Path $profile.FullName $relative)
                }
            }
        }
    }

    $firefoxRoot = Join-Path $env:LOCALAPPDATA 'Mozilla\Firefox\Profiles'
    if (Test-Path -LiteralPath $firefoxRoot -PathType Container) {
        $profiles = @(Get-ChildItem -LiteralPath $firefoxRoot -Directory -ErrorAction SilentlyContinue)
        foreach ($profile in $profiles) {
            $cachePaths += (Join-Path $profile.FullName 'cache2')
            $cachePaths += (Join-Path $profile.FullName 'startupCache')
        }
    }

    $cachePaths = @($cachePaths | Select-Object -Unique)
    if ($cachePaths.Count -eq 0) {
        Write-Host '  [--] No supported browser cache folders were found.' -ForegroundColor DarkGray
        return
    }

    $total = 0
    foreach ($path in $cachePaths) {
        if (Test-Path -LiteralPath $path -PathType Container) {
            $count = Clear-DirectoryContents -Path $path
            $total += $count
            Write-Host ('  [OK] {0} - {1} item(s) removed' -f $path, $count) -ForegroundColor Green
        }
    }
    Write-Host ('  Browser cache cleanup complete. Total items removed: ' + $total) -ForegroundColor Cyan
}

function Invoke-WindowsCacheCleanup {
    Write-Section '03 / WINDOWS CACHE'
    Write-Host 'Cleaning DirectX shader cache, Delivery Optimization cache and Windows Update downloads.' -ForegroundColor Gray

    $directXCache = Join-Path $env:LOCALAPPDATA 'D3DSCache'
    if (Test-Path -LiteralPath $directXCache -PathType Container) {
        $count = Clear-DirectoryContents -Path $directXCache
        Write-Host ('  [OK] DirectX shader cache - {0} item(s) removed' -f $count) -ForegroundColor Green
    }
    else {
        Write-Host '  [--] DirectX shader cache - folder not found' -ForegroundColor DarkGray
    }

    $doCommand = Get-Command -Name Delete-DeliveryOptimizationCache -ErrorAction SilentlyContinue
    if ($null -ne $doCommand) {
        try {
            Delete-DeliveryOptimizationCache -Force -ErrorAction Stop
            Write-Host '  [OK] Delivery Optimization cache cleared' -ForegroundColor Green
        }
        catch {
            Write-Host ('  [!] Delivery Optimization cache skipped: ' + $_.Exception.Message) -ForegroundColor Yellow
        }
    }
    else {
        Write-Host '  [--] Delivery Optimization cleanup command is unavailable on this Windows version.' -ForegroundColor DarkGray
    }

    $updateDownload = Join-Path $env:WINDIR 'SoftwareDistribution\Download'
    $serviceNames = @('wuauserv', 'bits')
    $wasRunning = @{}
    $canClearUpdateCache = $true

    try {
        foreach ($serviceName in $serviceNames) {
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            if ($null -ne $service -and $service.Status -eq 'Running') {
                $wasRunning[$serviceName] = $true
                try {
                    Stop-Service -Name $serviceName -Force -ErrorAction Stop
                }
                catch {
                    $canClearUpdateCache = $false
                    Write-Host ('  [!] Could not stop ' + $serviceName + '; Windows Update download cache will be skipped.') -ForegroundColor Yellow
                }
            }
            else {
                $wasRunning[$serviceName] = $false
            }
        }

        if ($canClearUpdateCache -and (Test-Path -LiteralPath $updateDownload -PathType Container)) {
            $count = Clear-DirectoryContents -Path $updateDownload
            Write-Host ('  [OK] Windows Update download cache - {0} item(s) removed' -f $count) -ForegroundColor Green
            Write-Host '       Windows may download required update files again later.' -ForegroundColor DarkGray
        }
        elseif (-not (Test-Path -LiteralPath $updateDownload -PathType Container)) {
            Write-Host '  [--] Windows Update download cache - folder not found' -ForegroundColor DarkGray
        }
    }
    finally {
        foreach ($serviceName in $serviceNames) {
            if ($wasRunning.ContainsKey($serviceName) -and $wasRunning[$serviceName]) {
                try {
                    Start-Service -Name $serviceName -ErrorAction Stop
                    Write-Host ('  [OK] Service restored: ' + $serviceName) -ForegroundColor Green
                }
                catch {
                    Write-Host ('  [!] Could not restart ' + $serviceName + '. Check Windows Services.') -ForegroundColor Yellow
                }
            }
        }
    }
}

function Invoke-NetworkCleanup {
    Write-Section '04 / NETWORK REFRESH'
    Write-Host 'Flushing the DNS resolver cache. This does not guarantee faster internet.' -ForegroundColor Gray

    try {
        $output = & (Join-Path $env:WINDIR 'System32\ipconfig.exe') /flushdns 2>&1
        foreach ($line in $output) {
            Write-Host ('  ' + $line) -ForegroundColor Gray
        }
        if ($LASTEXITCODE -eq 0) {
            Write-Host '  [OK] DNS cache refreshed' -ForegroundColor Green
        }
        else {
            Write-Host '  [!] DNS refresh returned an error.' -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host ('  [!] Could not run ipconfig: ' + $_.Exception.Message) -ForegroundColor Yellow
    }
}

function Show-MainMenu {
    Clear-Host
    Write-Host ''
    Write-Host '   _____ ___ ____ ____  _____ _   _ ____  _____' -ForegroundColor Cyan
    Write-Host '  / ____|_ _/ ___/ ___|| ____| \ | / ___|| ____|' -ForegroundColor Cyan
    Write-Host '  \___ \ | | |   \___ \|  _| |  \| \___ \|  _|' -ForegroundColor Cyan
    Write-Host '   ___) || | |___ ___) | |___| |\  |___) | |___' -ForegroundColor Cyan
    Write-Host '  |____/|___\____|____/|_____|_| \_|____/|_____|' -ForegroundColor Cyan
    Write-Host ''
    Write-Host '                 PC MAINTENANCE TOOL' -ForegroundColor White
    Write-Host '             SAFE CLEANUP  /  WINDOWS 10-11' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '  ===========================================================' -ForegroundColor DarkGray
    Write-Host '   [1]  TEMP CLEANER        Temporary files / crash dumps' -ForegroundColor White
    Write-Host '   [2]  BROWSER CLEANER     Chrome / Edge / Firefox cache' -ForegroundColor White
    Write-Host '   [3]  WINDOWS CLEANER     DirectX / Update / Delivery cache' -ForegroundColor White
    Write-Host '   [4]  NETWORK REFRESH     Flush DNS cache' -ForegroundColor White
    Write-Host '  -----------------------------------------------------------' -ForegroundColor DarkGray
    Write-Host '   [5]  FULL CLEAN          Run all cleanup categories' -ForegroundColor Green
    Write-Host '   [0]  EXIT' -ForegroundColor DarkGray
    Write-Host '  ===========================================================' -ForegroundColor DarkGray
    Write-Host ''
}

while ($true) {
    Show-MainMenu
    $choice = Read-Host '  Select an option'

    switch ($choice) {
        '1' {
            Invoke-TemporaryCleanup
            Wait-ForKey
        }
        '2' {
            Invoke-BrowserCacheCleanup
            Wait-ForKey
        }
        '3' {
            Invoke-WindowsCacheCleanup
            Wait-ForKey
        }
        '4' {
            Invoke-NetworkCleanup
            Wait-ForKey
        }
        '5' {
            Write-Host ''
            if (Confirm-Action 'Run the full cleanup? Browser data is limited to cache; Recycle Bin requires separate confirmation.') {
                Invoke-TemporaryCleanup
                Invoke-BrowserCacheCleanup
                Invoke-WindowsCacheCleanup
                Invoke-NetworkCleanup
                Write-Host ''
                Write-Host '  SICSENSE full cleanup finished.' -ForegroundColor Green
            }
            else {
                Write-Host '  Full cleanup cancelled.' -ForegroundColor Yellow
            }
            Wait-ForKey
        }
        '0' {
            Clear-Host
            Write-Host '  SICSENSE closed. Have a good day.' -ForegroundColor Cyan
            Start-Sleep -Milliseconds 500
            exit
        }
        default {
            Write-Host '  Invalid option. Please choose 0-5.' -ForegroundColor Yellow
            Start-Sleep -Seconds 1
        }
    }
}
