<#
    SDX Tools Updater

    This script is launched automatically by SDX Tools inside Revit when you agree to install
    an update. It waits for Revit to close, then downloads the new SDX.dll and SDX.addin files
    directly from the public SDX-Tools-Updater repository on GitHub and copies them into your
    Revit Addins folder.

    You can see every file this script will download by visiting:
    https://github.com/Stibbz/SDX-Tools-Updater

    Parameters passed in by the add-in at runtime:
        -RevitPid          The process ID of the running Revit. The script waits for it to close
                           before touching any files, because Revit holds a lock on SDX.dll.
        -FilesBaseUrl      The base URL where the update files are hosted.
                           Example: https://stibbz.github.io/SDX-Tools-Updater
        -RevitAddinsFolder The path to the Revit Addins folder on this machine.
                           Example: C:\Users\YourName\AppData\Roaming\Autodesk\Revit\Addins
        -NewVersion        The version string being installed (e.g. "v0.2.2"). Written to the
                           result file so SDX Tools can show a confirmation dialog on next start.
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
$LogFile      = Join-Path $env:APPDATA "SDX\updater.log"
$ResultFile   = Join-Path $env:APPDATA "SDX\update-result.xml"

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

function Write-Result {
    param([bool] $Success)
    try {
        $xml = "<Result><Version>$NewVersion</Version><Success>$($Success.ToString().ToLower())</Success></Result>"
        $resultFolder = Split-Path $ResultFile -Parent
        if (-not (Test-Path $resultFolder)) { New-Item -ItemType Directory -Path $resultFolder -Force | Out-Null }
        Set-Content -Path $ResultFile -Value $xml -Encoding UTF8
    } catch { }
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

try {
    Write-Log "SDX Tools updater started."
    Write-Log "Revit process ID : $RevitPid"
    Write-Log "Update files URL : $FilesBaseUrl"
    Write-Log "Revit Addins path: $RevitAddinsFolder"

    # Step 1: Wait for Revit to fully close before we touch any files.
    Write-Log "Waiting for Revit to close..."
    $revitIsClosed = Wait-ForRevitToClose -ProcessId $RevitPid
    if (-not $revitIsClosed) {
        Write-Log "ERROR: Revit did not close within 2 minutes. Aborting to avoid overwriting a file that is still in use."
        exit 1
    }
    Write-Log "Revit has closed."

    # Step 2: Build the list of version folders that exist on this machine.
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

    # Step 3: Confirm the existing DLL files are no longer locked by Revit.
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
            exit 1
        }
        Write-Log "Files are unlocked and ready to replace."
    }

    # Step 4: Download the updated files directly from the public repository.
    # Every file downloaded here is publicly visible at $FilesBaseUrl on GitHub.
    $baseUrl        = $FilesBaseUrl.TrimEnd('/')
    $downloadClient = New-Object System.Net.WebClient
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
        Write-Log "Update complete. You can now reopen Revit."
        Write-Result -Success $true
    } else {
        Write-Log "No version folders matched. Nothing was updated."
        Write-Result -Success $false
    }

    exit 0
}
catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    Write-Result -Success $false
    exit 1
}
