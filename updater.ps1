<#
    SDX Tools Updater

    This script is launched automatically by SDX Tools inside Revit when you agree to install
    an update. It waits for Revit to close, verifies the update is still needed, then downloads
    the new SDX.dll and SDX.addin files directly from the public SDX-Tools-Updater repository
    on GitHub and copies them into your Revit Addins folder.

    You can see every file this script will download by visiting:
    https://github.com/Stibbz/SDX-Tools-Updater

    Parameters passed in by the add-in at runtime:
        -RevitPid          The process ID of the running Revit that scheduled the update.
                           The script waits for it to close before checking versions or
                           touching any files.
        -FilesBaseUrl      The base URL where the update files are hosted.
                           Example: https://stibbz.github.io/SDX-Tools-Updater
        -RevitAddinsFolder The path to the Revit Addins folder on this machine.
                           Example: C:\Users\YourName\AppData\Roaming\Autodesk\Revit\Addins
        -NewVersion        The version string being installed (e.g. "v0.2.2"). Used to verify
                           the update is still needed before downloading anything.
#>

param(
    [Parameter(Mandatory = $true)] [int]    $RevitPid,
    [Parameter(Mandatory = $true)] [string] $FilesBaseUrl,
    [Parameter(Mandatory = $true)] [string] $RevitAddinsFolder,
    [Parameter(Mandatory = $true)] [string] $NewVersion
)

$ErrorActionPreference = "Stop"

# The two files that are replaced for each Revit version.
$FilesToUpdate = @("SDX.dll", "SDX.addin")

# The Revit versions SDX Tools supports. Only versions actually installed on this
# machine (i.e. the folder exists) will be updated.
$SupportedRevitVersions = @("2025", "2026")

# Log file so you can inspect exactly what the updater did.
$LogFile = Join-Path $env:APPDATA "SDX\updater.log"

function Write-Log {
    param([string] $Message)
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $logLine   = "$timestamp  $Message"
    try {
        $logFolder = Split-Path $LogFile -Parent
        if (-not (Test-Path $logFolder)) { New-Item -ItemType Directory -Path $logFolder -Force | Out-Null }
        Add-Content -Path $LogFile -Value $logLine
    } catch { }
    Write-Host $logLine
}

# Shows a Windows message box. Works even when the process has no console window.
function Show-MessageBox {
    param(
        [string] $Message,
        [string] $Title,
        [string] $Icon = "Information"
    )
    try {
        Add-Type -AssemblyName System.Windows.Forms
        $iconEnum = [System.Windows.Forms.MessageBoxIcon]::$Icon
        [System.Windows.Forms.MessageBox]::Show(
            $Message,
            $Title,
            [System.Windows.Forms.MessageBoxButtons]::OK,
            $iconEnum
        ) | Out-Null
    } catch {
        Write-Log "WARNING: could not show message box: $($_.Exception.Message)"
    }
}

# Polls until Revit's process disappears from the process list.
function Wait-ForRevitToClose {
    param([int] $ProcessId, [int] $TimeoutSeconds = 120)
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        $revitProcess = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
        if ($null -eq $revitProcess) { return $true }
        Start-Sleep -Milliseconds 500
    }
    return $false
}

# Polls until no Revit process remains on the machine, then returns.
# Intended to run after the scheduling Revit has already closed; waits silently
# for any other open Revit sessions to close before touching shared files.
function Wait-ForAllRevitToClose {
    Write-Log "Waiting for all remaining Revit instances to close..."
    while ($true) {
        $remaining = Get-Process -Name Revit -ErrorAction SilentlyContinue
        if ($null -eq $remaining -or @($remaining).Count -eq 0) { return }
        Start-Sleep -Seconds 2
    }
}

# Returns true when a file is not held open by any process (i.e. safe to overwrite).
function Test-FileIsUnlocked {
    param([string] $FilePath)
    if (-not (Test-Path $FilePath)) { return $true }
    try {
        $fileStream = [System.IO.File]::Open($FilePath, 'Open', 'ReadWrite', 'None')
        $fileStream.Close()
        $fileStream.Dispose()
        return $true
    } catch {
        return $false
    }
}

# Polls until all listed files are unlocked, or the timeout is reached.
function Wait-ForAllFilesToUnlock {
    param([string[]] $FilePaths, [int] $TimeoutSeconds = 60)
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        $allUnlocked = $true
        foreach ($filePath in $FilePaths) {
            if (-not (Test-FileIsUnlocked -FilePath $filePath)) {
                $allUnlocked = $false
                break
            }
        }
        if ($allUnlocked) { return $true }
        Start-Sleep -Milliseconds 500
    }
    return $false
}

# Reads the FileVersion from an installed SDX.dll. Returns $null if not found.
function Get-InstalledVersion {
    param([string] $DllPath)
    if (-not (Test-Path $DllPath)) { return $null }
    try {
        return [System.Diagnostics.FileVersionInfo]::GetVersionInfo($DllPath).ProductVersion
    } catch {
        return $null
    }
}

# ------------------------------------------------------------------
# Single-instance guard: only one updater may run at a time.
# If another instance is already waiting (e.g. launched by a second
# Revit that was closed earlier), exit silently so we don't interfere.
# ------------------------------------------------------------------
$mutex          = New-Object System.Threading.Mutex($false, 'Global\SdxToolsUpdater')
$mutexAcquired  = $false

try {
    try   { $mutexAcquired = $mutex.WaitOne(0) }
    catch [System.Threading.AbandonedMutexException] { $mutexAcquired = $true }

    if (-not $mutexAcquired) {
        Write-Log "Another SDX updater instance is already running. Exiting silently."
        exit 0
    }

    try {
        Write-Log "SDX Tools updater started."
        Write-Log "Revit process ID : $RevitPid"
        Write-Log "Target version   : $NewVersion"
        Write-Log "Update files URL : $FilesBaseUrl"
        Write-Log "Revit Addins path: $RevitAddinsFolder"

        # Step 1: Wait for the Revit that scheduled this update to close.
        # This releases the DLL lock so we can read the installed version.
        Write-Log "Waiting for Revit (PID $RevitPid) to close..."
        $revitIsClosed = Wait-ForRevitToClose -ProcessId $RevitPid
        if (-not $revitIsClosed) {
            Write-Log "ERROR: Revit (PID $RevitPid) did not close within 2 minutes. Aborting."
            Show-MessageBox `
                -Message "SDX Tools update aborted: Revit did not close within 2 minutes.`n`nCheck $LogFile for details." `
                -Title   "SDX Tools Update Aborted" `
                -Icon    "Warning"
            exit 1
        }
        Write-Log "Revit (PID $RevitPid) has closed."

        # Step 2: Version check -- bail out early if already on the target version.
        # The UI prevents scheduling an update when already current, but this guard
        # catches any edge-case where the script is invoked unnecessarily.
        $versionFoldersToCheck = $SupportedRevitVersions | Where-Object {
            Test-Path (Join-Path $RevitAddinsFolder $_)
        }

        if ($versionFoldersToCheck.Count -gt 0) {
            $firstDll = Join-Path $RevitAddinsFolder "$($versionFoldersToCheck[0])\SDX.dll"
            $installedRaw = Get-InstalledVersion -DllPath $firstDll

            if ($null -ne $installedRaw) {
                # Normalise both versions to Major.Minor.Build for comparison.
                $installedNorm = ($installedRaw.TrimStart('v') -split '\.' | Select-Object -First 3) -join '.'
                $targetNorm    = ($NewVersion.TrimStart('v')   -split '\.' | Select-Object -First 3) -join '.'

                if ($installedNorm -eq $targetNorm) {
                    Write-Log "Already on version $NewVersion. Nothing to update."
                    exit 0
                }

                Write-Log "Installed version: $installedRaw  ->  Target: $NewVersion  (update needed)"
            }
        }

        # Step 3: Wait for any other open Revit instances before touching files.
        Wait-ForAllRevitToClose

        # Step 4: Build the list of version folders that exist on this machine.
        $installedVersionFolders = @()
        foreach ($revitVersion in $SupportedRevitVersions) {
            $versionFolderPath = Join-Path $RevitAddinsFolder $revitVersion
            if (Test-Path $versionFolderPath) {
                $installedVersionFolders += $revitVersion
            }
        }

        if ($installedVersionFolders.Count -eq 0) {
            Write-Log "No SDX Tools installation folders found under $RevitAddinsFolder. Nothing to update."
            exit 0
        }

        # Step 5: Confirm the existing DLL files are no longer locked by Revit.
        $existingDllPaths = @()
        foreach ($revitVersion in $installedVersionFolders) {
            $dllPath = Join-Path $RevitAddinsFolder "$revitVersion\SDX.dll"
            if (Test-Path $dllPath) { $existingDllPaths += $dllPath }
        }

        if ($existingDllPaths.Count -gt 0) {
            Write-Log "Checking that files are unlocked..."
            $filesAreUnlocked = Wait-ForAllFilesToUnlock -FilePaths $existingDllPaths
            if (-not $filesAreUnlocked) {
                Write-Log "ERROR: File(s) are still locked after 60 seconds. Aborting."
                Show-MessageBox `
                    -Message "SDX Tools update to $NewVersion failed: files are still locked.`n`nCheck $LogFile for details." `
                    -Title   "SDX Tools Update Failed" `
                    -Icon    "Error"
                exit 1
            }
            Write-Log "Files are unlocked and ready to replace."
        }

        # Step 6: Download the updated files directly from the public repository.
        # Every file downloaded here is publicly visible at $FilesBaseUrl on GitHub.
        $baseUrl         = $FilesBaseUrl.TrimEnd('/')
        $downloadClient  = New-Object System.Net.WebClient
        $anythingUpdated = $false

        foreach ($revitVersion in $installedVersionFolders) {
            $destinationFolder = Join-Path $RevitAddinsFolder $revitVersion
            Write-Log "Updating Revit $revitVersion..."

            foreach ($fileName in $FilesToUpdate) {
                $downloadUrl         = "$baseUrl/$revitVersion/$fileName"
                $destinationFilePath = Join-Path $destinationFolder $fileName

                Write-Log "  Downloading: $downloadUrl"
                $downloadClient.DownloadFile($downloadUrl, $destinationFilePath)
                Write-Log "  Installed to: $destinationFilePath"
            }

            Write-Log "Revit $revitVersion updated successfully."
            $anythingUpdated = $true
        }

        $downloadClient.Dispose()

        if ($anythingUpdated) {
            Write-Log "Update to $NewVersion complete. You can now reopen Revit."
            Show-MessageBox `
                -Message "SDX Tools has been updated to $NewVersion.`n`nYou can now reopen Revit." `
                -Title   "SDX Tools Updated" `
                -Icon    "Information"
        } else {
            Write-Log "No version folders matched. Nothing was updated."
        }

        exit 0
    }
    catch {
        Write-Log "ERROR: $($_.Exception.Message)"
        Show-MessageBox `
            -Message "SDX Tools update to $NewVersion failed.`n`nError: $($_.Exception.Message)`n`nCheck $LogFile for details." `
            -Title   "SDX Tools Update Failed" `
            -Icon    "Error"
        exit 1
    }
    finally {
        if ($mutexAcquired) {
            try { $mutex.ReleaseMutex() } catch { }
        }
        $mutex.Dispose()
    }
}
catch {
    # Mutex acquisition itself failed -- should not normally happen.
    exit 1
}
