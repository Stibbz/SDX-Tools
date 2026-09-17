<#
    SDX Tools Updater

    This script is launched automatically by SDX Tools inside Revit when you agree to install
    an update. It waits for Revit to close, verifies the update is still needed, then downloads
    the new SDX.dll and SDX.addin files directly from the public SDX-Tools release
    assets on GitHub and copies them into your Revit Addins folder.

    You can see every file this script will download by visiting:
    https://github.com/Stibbz/SDX-Tools/releases/latest

    Parameters passed in by the add-in at runtime:
        -RevitPid          The process ID of the running Revit that scheduled the update.
                           The script waits for it to close before checking versions or
                           touching any files.
        -FilesBaseUrl      The base URL where the update files are hosted.
                           Example: https://github.com/Stibbz/SDX-Tools/releases/download/v0.2.4
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
$SupportedRevitVersions = @("2024", "2025", "2026", "2027")

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

function Try-ForceCloseRevit {
    param([int] $ProcessId)

    try {
        $revitProcess = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
        if ($null -eq $revitProcess) { return $true }

        Write-Log "Force-close requested for Revit (PID $ProcessId)."

        try {
            $null = $revitProcess.CloseMainWindow()
        } catch { }

        if (-not $revitProcess.WaitForExit(5000)) {
            try {
                $revitProcess.Kill()
            } catch { }
            $revitProcess.WaitForExit(10000) | Out-Null
        }

        return $revitProcess.HasExited
    }
    catch {
        Write-Log "WARNING: force-close failed: $($_.Exception.Message)"
        return $false
    }
}

function New-FallbackSdxWindowIcon {
    try {
        $bitmap = New-Object System.Drawing.Bitmap 32, 32
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

        $backgroundBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(34, 41, 51))
        $accentBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(0, 122, 204))
        $textBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
        $font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)

        $graphics.FillRectangle($backgroundBrush, 0, 0, 32, 32)
        $graphics.FillRectangle($accentBrush, 2, 2, 28, 28)
        $graphics.DrawString("S", $font, $textBrush, 7, 5)

        $iconHandle = $bitmap.GetHicon()
        $icon = [System.Drawing.Icon]::FromHandle($iconHandle)
        $clone = $icon.Clone()

        $font.Dispose()
        $textBrush.Dispose()
        $accentBrush.Dispose()
        $backgroundBrush.Dispose()
        $graphics.Dispose()
        $bitmap.Dispose()
        $icon.Dispose()

        return $clone
    }
    catch {
        return $null
    }
}

function New-IconFromBitmap {
    param([System.Drawing.Bitmap] $Bitmap)

    try {
        $iconHandle = $Bitmap.GetHicon()
        $icon = [System.Drawing.Icon]::FromHandle($iconHandle)
        $clone = $icon.Clone()
        $icon.Dispose()
        return $clone
    }
    catch {
        return $null
    }
}

function Get-SdxWindowIcon {
    try {
        $iconPath = Join-Path $PSScriptRoot "sdx-updater.ico"
        if (Test-Path $iconPath) {
            return New-Object System.Drawing.Icon($iconPath)
        }

        $pngPath = Join-Path $PSScriptRoot "sdx-updater.png"
        if (Test-Path $pngPath) {
            $bitmap = New-Object System.Drawing.Bitmap($pngPath)
            try {
                $iconFromPng = New-IconFromBitmap -Bitmap $bitmap
                if ($null -ne $iconFromPng) {
                    Write-Log "Using updater icon from $pngPath"
                    return $iconFromPng
                }
            }
            finally {
                $bitmap.Dispose()
            }
        }
    }
    catch {
        Write-Log "WARNING: custom updater icon could not be loaded: $($_.Exception.Message)"
    }

    return New-FallbackSdxWindowIcon
}

# Shows a small status window while waiting for the scheduling Revit process to
# fully exit. Closing the window cancels the update. The user can also request a
# force-close of Revit from this window.
function Wait-ForRevitToCloseInteractive {
    param([int] $ProcessId, [int] $TimeoutSeconds = 120)

    $alreadyClosed = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
    if ($null -eq $alreadyClosed) {
        return [pscustomobject]@{ Closed = $true; Cancelled = $false; TimedOut = $false }
    }

    try {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing

        $form = New-Object System.Windows.Forms.Form
        $form.Text = "SDX Updater"
        $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
        $form.Width = 520
        $form.Height = 210
        $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
        $form.MaximizeBox = $false
        $form.MinimizeBox = $false
        $form.TopMost = $true

        $windowIcon = Get-SdxWindowIcon
        if ($null -ne $windowIcon) {
            $form.Icon = $windowIcon
        }

        $label = New-Object System.Windows.Forms.Label
        $label.Left = 20
        $label.Top = 20
        $label.Width = 470
        $label.Height = 75
        $label.Text = "Waiting for Revit to close, please wait.`r`n`r`nClosing this window cancels the update."
        $form.Controls.Add($label)

        $cancelButton = New-Object System.Windows.Forms.Button
        $cancelButton.Text = "Cancel Update"
        $cancelButton.Left = 250
        $cancelButton.Top = 110
        $cancelButton.Width = 110
        $cancelButton.Height = 30
        $form.Controls.Add($cancelButton)

        $forceButton = New-Object System.Windows.Forms.Button
        $forceButton.Text = "Force Close Revit"
        $forceButton.Left = 370
        $forceButton.Top = 110
        $forceButton.Width = 120
        $forceButton.Height = 30
        $form.Controls.Add($forceButton)

        $state = [pscustomobject]@{
            Closed = $false
            Cancelled = $false
            TimedOut = $false
            CompletedByTimer = $false
            StartedUtc = [DateTime]::UtcNow
        }

        $cancelButton.Add_Click({
            $state.Cancelled = $true
            $form.Close()
        })

        $forceButton.Add_Click({
            $forceButton.Enabled = $false
            $forceButton.Text = "Forcing..."

            $forced = Try-ForceCloseRevit -ProcessId $ProcessId
            if ($forced) {
                Write-Log "Force-close succeeded for Revit (PID $ProcessId)."
            } else {
                Write-Log "Force-close did not finish Revit (PID $ProcessId)."
                $forceButton.Enabled = $true
                $forceButton.Text = "Force Close Revit"
            }
        })

        $timer = New-Object System.Windows.Forms.Timer
        $timer.Interval = 500
        $timer.Add_Tick({
            $running = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
            if ($null -eq $running) {
                $state.Closed = $true
                $state.CompletedByTimer = $true
                $timer.Stop()
                $form.Close()
                return
            }

            $elapsedSeconds = [int]([DateTime]::UtcNow - $state.StartedUtc).TotalSeconds
            $label.Text = "Waiting for Revit to close, please wait.`r`nElapsed: $elapsedSeconds seconds.`r`n`r`nClosing this window cancels the update."

            if ($elapsedSeconds -ge $TimeoutSeconds) {
                $state.TimedOut = $true
                $timer.Stop()
                $form.Close()
            }
        })

        $form.Add_FormClosing({
            if (-not $state.CompletedByTimer -and -not $state.TimedOut) {
                if (-not $state.Cancelled) {
                    $state.Cancelled = $true
                }
            }
        })

        $timer.Start()
        $null = $form.ShowDialog()
        $timer.Dispose()
        if ($null -ne $windowIcon) {
            $windowIcon.Dispose()
        }
        $form.Dispose()

        return [pscustomobject]@{
            Closed = $state.Closed
            Cancelled = $state.Cancelled
            TimedOut = $state.TimedOut
        }
    }
    catch {
        Write-Log "WARNING: interactive wait window failed, falling back to background wait: $($_.Exception.Message)"
        $closed = Wait-ForRevitToClose -ProcessId $ProcessId -TimeoutSeconds $TimeoutSeconds
        return [pscustomobject]@{ Closed = $closed; Cancelled = $false; TimedOut = (-not $closed) }
    }
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
        # This is interactive so the user sees why the updater is waiting.
        Write-Log "Waiting for Revit (PID $RevitPid) to close (interactive wait window)..."
        $waitResult = Wait-ForRevitToCloseInteractive -ProcessId $RevitPid

        if ($waitResult.Cancelled) {
            Write-Log "Update cancelled by user while waiting for Revit to close."
            Show-MessageBox `
                -Message "SDX Tools update was cancelled while waiting for Revit to fully close.`n`nYou can start the update again from Preferences." `
                -Title   "SDX Tools Update Aborted" `
                -Icon    "Warning"
            exit 1
        }

        if ($waitResult.TimedOut) {
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
                # Remote assets are flat-named per release (SDX-2025.dll etc.)
                # because GitHub release asset names cannot contain slashes.
                # Local install path keeps the plain file name in the version folder.
                $extension           = [System.IO.Path]::GetExtension($fileName)
                $remoteFileName      = "SDX-$revitVersion$extension"
                $downloadUrl         = "$baseUrl/$remoteFileName"
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
