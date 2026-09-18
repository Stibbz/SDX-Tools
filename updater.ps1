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
    [int]    $RevitPid,
    [string] $FilesBaseUrl,
    [string] $RevitAddinsFolder,
    [string] $NewVersion,
    [switch] $TestWaitWindow,
    [int]    $TestWaitSeconds = 20,
    [switch] $Standalone,
    [switch] $Install,
    [switch] $Update,
    [ValidateSet("Stable", "Preview")]
    [string] $Channel = "Stable",
    [string] $ManifestUrl,
    [string] $StandaloneFilesBaseUrl,
    [string] $StandaloneVersion,
    [string[]] $StandaloneRevitVersions
)

$ErrorActionPreference = "Stop"

# The two files that are replaced for each Revit version.
$FilesToUpdate = @("SDX.dll", "SDX.addin")

# The Revit versions SDX Tools supports. Only versions actually installed on this
# machine (i.e. the folder exists) will be updated.
$SupportedRevitVersions = @("2024", "2025", "2026", "2027")

$StableManifestUrl = "https://stibbz.github.io/SDX-Tools/version.json"
$PreviewManifestUrl = "https://stibbz.github.io/SDX-Tools/version-preview.json"

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

function Assert-MainParameters {
    if ($RevitPid -le 0) {
        throw "Missing or invalid parameter: -RevitPid"
    }

    if ([string]::IsNullOrWhiteSpace($FilesBaseUrl)) {
        throw "Missing required parameter: -FilesBaseUrl"
    }

    if ([string]::IsNullOrWhiteSpace($RevitAddinsFolder)) {
        throw "Missing required parameter: -RevitAddinsFolder"
    }

    if ([string]::IsNullOrWhiteSpace($NewVersion)) {
        throw "Missing required parameter: -NewVersion"
    }
}

function Test-HasAnyMainParameter {
    if ($RevitPid -gt 0) {
        return $true
    }

    if (-not [string]::IsNullOrWhiteSpace($FilesBaseUrl)) {
        return $true
    }

    if (-not [string]::IsNullOrWhiteSpace($RevitAddinsFolder)) {
        return $true
    }

    return -not [string]::IsNullOrWhiteSpace($NewVersion)
}

function Test-ShouldRunStandalone {
    if ($Standalone -or $Install -or $Update) {
        return $true
    }

    return -not (Test-HasAnyMainParameter)
}

function Get-ManifestUrlForChannel {
    param([string] $ChannelName)

    if ($ChannelName -ieq "Preview") {
        return $PreviewManifestUrl
    }

    return $StableManifestUrl
}

function Test-CanUseInteractiveConsole {
    try {
        if ([Console]::IsInputRedirected) { return $false }
        if ([Console]::IsOutputRedirected) { return $false }
        $null = [Console]::CursorTop
        return $true
    }
    catch {
        return $false
    }
}

function Wait-ForExitConfirmation {
    if (-not (Test-CanUseInteractiveConsole)) {
        return
    }

    Write-Host ""
    Write-Host "Press Enter to exit." -ForegroundColor DarkGray
    [void][Console]::ReadLine()
}

function Complete-Run {
    param(
        [bool] $Success,
        [string] $Message,
        [int] $ExitCode
    )

    $color = if ($Success) { "Green" } else { "Red" }
    Write-Host ""
    Write-Host $Message -ForegroundColor $color
    Wait-ForExitConfirmation
    exit $ExitCode
}

function Read-ArrowMenuChoice {
    param(
        [string] $Title,
        [string[]] $Options,
        [int] $DefaultIndex = 0
    )

    if ($null -eq $Options -or $Options.Count -eq 0) {
        throw "Menu options cannot be empty."
    }

    if ($DefaultIndex -lt 0 -or $DefaultIndex -ge $Options.Count) {
        $DefaultIndex = 0
    }

    $selectedIndex = $DefaultIndex
    while ($true) {
        Clear-Host
        Write-Host "SDX Updater" -ForegroundColor Cyan
        Write-Host $Title -ForegroundColor White
        Write-Host "Use Up/Down arrows and press Enter." -ForegroundColor DarkGray
        Write-Host ""

        for ($index = 0; $index -lt $Options.Count; $index++) {
            $option = $Options[$index]
            if ($index -eq $selectedIndex) {
                Write-Host ("> " + $option) -ForegroundColor Yellow
            } else {
                Write-Host ("  " + $option) -ForegroundColor Gray
            }
        }

        $key = [Console]::ReadKey($true).Key
        if ($key -eq [ConsoleKey]::UpArrow) {
            if ($selectedIndex -gt 0) {
                $selectedIndex--
            }
            continue
        }

        if ($key -eq [ConsoleKey]::DownArrow) {
            if ($selectedIndex -lt ($Options.Count - 1)) {
                $selectedIndex++
            }
            continue
        }

        if ($key -eq [ConsoleKey]::Enter) {
            return $Options[$selectedIndex]
        }
    }
}

function Read-ArrowMultiSelect {
    param(
        [string] $Title,
        [string[]] $Options,
        [string[]] $DefaultSelected
    )

    if ($null -eq $Options -or $Options.Count -eq 0) {
        throw "Multi-select options cannot be empty."
    }

    $selectedLookup = New-Object System.Collections.Generic.HashSet[string] ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($defaultItem in $DefaultSelected) {
        if ($Options -contains $defaultItem) {
            [void]$selectedLookup.Add($defaultItem)
        }
    }

    if ($selectedLookup.Count -eq 0) {
        foreach ($item in $Options) {
            [void]$selectedLookup.Add($item)
        }
    }

    $cursorIndex = 0
    while ($true) {
        Clear-Host
        Write-Host "SDX Updater" -ForegroundColor Cyan
        Write-Host $Title -ForegroundColor White
        Write-Host "Use Up/Down arrows, Space to toggle, A for all, Enter to continue." -ForegroundColor DarkGray
        Write-Host ""

        for ($index = 0; $index -lt $Options.Count; $index++) {
            $option = $Options[$index]
            $isChecked = $selectedLookup.Contains($option)
            $check = if ($isChecked) { "[x]" } else { "[ ]" }

            if ($index -eq $cursorIndex) {
                Write-Host ("> " + $check + " " + $option) -ForegroundColor Yellow
            } elseif ($isChecked) {
                Write-Host ("  " + $check + " " + $option) -ForegroundColor Green
            } else {
                Write-Host ("  " + $check + " " + $option) -ForegroundColor Gray
            }
        }

        $key = [Console]::ReadKey($true).Key
        if ($key -eq [ConsoleKey]::UpArrow) {
            if ($cursorIndex -gt 0) {
                $cursorIndex--
            }
            continue
        }

        if ($key -eq [ConsoleKey]::DownArrow) {
            if ($cursorIndex -lt ($Options.Count - 1)) {
                $cursorIndex++
            }
            continue
        }

        if ($key -eq [ConsoleKey]::Spacebar) {
            $current = $Options[$cursorIndex]
            if ($selectedLookup.Contains($current)) {
                if ($selectedLookup.Count -gt 1) {
                    [void]$selectedLookup.Remove($current)
                }
            } else {
                [void]$selectedLookup.Add($current)
            }
            continue
        }

        if ($key -eq [ConsoleKey]::A) {
            if ($selectedLookup.Count -eq $Options.Count) {
                $selectedLookup.Clear()
                [void]$selectedLookup.Add($Options[0])
            } else {
                $selectedLookup.Clear()
                foreach ($item in $Options) {
                    [void]$selectedLookup.Add($item)
                }
            }
            continue
        }

        if ($key -eq [ConsoleKey]::Enter) {
            if ($selectedLookup.Count -eq 0) {
                [void]$selectedLookup.Add($Options[0])
            }

            $result = @()
            foreach ($option in $Options) {
                if ($selectedLookup.Contains($option)) {
                    $result += $option
                }
            }

            return $result
        }
    }
}

function Read-StandalonePlanInteractive {
    param([string] $DefaultAddinsRoot)

    if (-not [string]::IsNullOrWhiteSpace($RevitAddinsFolder)) {
        $DefaultAddinsRoot = $RevitAddinsFolder
    }

    $selectedChannel = if ($Channel -ieq "Preview") { "Preview" } else { "Stable" }
    $defaultManifestUrl = Get-ManifestUrlForChannel -ChannelName $selectedChannel
    $manifestUrlToUse = if ([string]::IsNullOrWhiteSpace($ManifestUrl)) { $defaultManifestUrl } else { $ManifestUrl }

    $defaultsFromArguments = @()
    if ($null -ne $StandaloneRevitVersions -and $StandaloneRevitVersions.Count -gt 0) {
        foreach ($candidateRaw in $StandaloneRevitVersions) {
            if ($null -eq $candidateRaw) {
                continue
            }

            $candidate = $candidateRaw.ToString().Trim()
            if ($SupportedRevitVersions -contains $candidate) {
                $defaultsFromArguments += $candidate
            }
        }
    }

    $defaultVersions = if ($defaultsFromArguments.Count -gt 0) {
        @($defaultsFromArguments | Sort-Object -Unique)
    } else {
        @($SupportedRevitVersions)
    }

    if (-not (Test-CanUseInteractiveConsole)) {
        return [pscustomobject]@{
            Channel = $selectedChannel
            RevitAddinsFolder = $DefaultAddinsRoot
            ManifestUrl = $manifestUrlToUse
            FilesBaseUrlOverride = $StandaloneFilesBaseUrl
            VersionOverride = $StandaloneVersion
            RevitVersions = $defaultVersions
        }
    }

    $channelDefaultIndex = 0
    if ($selectedChannel -eq "Preview") {
        $channelDefaultIndex = 1
    }

    $channelChoice = Read-ArrowMenuChoice -Title "Select update channel" -Options @("Stable", "Preview") -DefaultIndex $channelDefaultIndex
    $selectedChannel = $channelChoice

    $versionPickerOptions = @("All") + $SupportedRevitVersions
    $versionPickerDefaults = @("All") + $defaultVersions
    $selectedVersionChoices = Read-ArrowMultiSelect -Title "Select Revit versions to install/update" -Options $versionPickerOptions -DefaultSelected $versionPickerDefaults

    if ($selectedVersionChoices -contains "All") {
        $selectedVersions = @($SupportedRevitVersions)
    } else {
        $selectedVersions = @($selectedVersionChoices | Where-Object { $SupportedRevitVersions -contains $_ } | Sort-Object -Unique)
    }

    if ($selectedVersions.Count -eq 0) {
        $selectedVersions = @($SupportedRevitVersions)
    }

    $defaultManifestUrl = Get-ManifestUrlForChannel -ChannelName $selectedChannel
    if ([string]::IsNullOrWhiteSpace($ManifestUrl)) {
        $manifestUrlToUse = $defaultManifestUrl
    } else {
        $manifestUrlToUse = $ManifestUrl
    }

    $summaryLines = @(
        "Channel: $selectedChannel",
        "Versions: $($selectedVersions -join ', ')",
        "Addins path: $DefaultAddinsRoot",
        "Manifest URL: $manifestUrlToUse"
    )

    if (-not [string]::IsNullOrWhiteSpace($StandaloneFilesBaseUrl)) {
        $summaryLines += "FilesBaseUrl override: $StandaloneFilesBaseUrl"
    }
    if (-not [string]::IsNullOrWhiteSpace($StandaloneVersion)) {
        $summaryLines += "Version override: $StandaloneVersion"
    }

    while ($true) {
        Clear-Host
        Write-Host "SDX Updater" -ForegroundColor Cyan
        Write-Host "Review and confirm" -ForegroundColor White
        Write-Host ""
        foreach ($line in $summaryLines) {
            Write-Host $line -ForegroundColor Gray
        }
        Write-Host ""
        $confirmationChoice = Read-ArrowMenuChoice -Title "Continue with this setup?" -Options @("Install/Update now", "Cancel") -DefaultIndex 0
        if ($confirmationChoice -eq "Install/Update now") {
            break
        }

        throw "Standalone install/update cancelled by user."
    }

    return [pscustomobject]@{
        Channel = $selectedChannel
        RevitAddinsFolder = $DefaultAddinsRoot
        ManifestUrl = $manifestUrlToUse
        FilesBaseUrlOverride = $StandaloneFilesBaseUrl
        VersionOverride = $StandaloneVersion
        RevitVersions = @($selectedVersions | Sort-Object -Unique)
    }
}

function Get-StandaloneManifest {
    param([string] $ManifestUrlToUse)

    $client = New-Object System.Net.WebClient
    try {
        $manifestJson = $client.DownloadString($ManifestUrlToUse)
    }
    finally {
        $client.Dispose()
    }

    $manifest = $manifestJson | ConvertFrom-Json
    if ($null -eq $manifest) {
        throw "Could not parse version manifest."
    }

    return $manifest
}

function Invoke-StandaloneInstall {
    $defaultRevitAddinsFolder = Join-Path $env:APPDATA "Autodesk\Revit\Addins"
    $plan = Read-StandalonePlanInteractive -DefaultAddinsRoot $defaultRevitAddinsFolder

    if ([string]::IsNullOrWhiteSpace($plan.RevitAddinsFolder)) {
        throw "Addins folder cannot be empty."
    }

    $filesBaseUrlToUse = $plan.FilesBaseUrlOverride
    $targetVersionToUse = $plan.VersionOverride

    if ([string]::IsNullOrWhiteSpace($filesBaseUrlToUse) -or [string]::IsNullOrWhiteSpace($targetVersionToUse)) {
        if ([string]::IsNullOrWhiteSpace($plan.ManifestUrl)) {
            throw "Manifest URL is required unless both FilesBaseUrl and Version overrides are set."
        }

        $manifest = Get-StandaloneManifest -ManifestUrlToUse $plan.ManifestUrl
        if ([string]::IsNullOrWhiteSpace($filesBaseUrlToUse)) {
            $filesBaseUrlToUse = [string]$manifest.filesBaseUrl
        }
        if ([string]::IsNullOrWhiteSpace($targetVersionToUse)) {
            $targetVersionToUse = [string]$manifest.version
        }
    }

    if ([string]::IsNullOrWhiteSpace($filesBaseUrlToUse)) {
        throw "Manifest did not provide filesBaseUrl."
    }

    if ([string]::IsNullOrWhiteSpace($targetVersionToUse)) {
        throw "Manifest did not provide version."
    }

    $existingDllPaths = @()
    foreach ($revitVersion in $plan.RevitVersions) {
        $existingDllPath = Join-Path $plan.RevitAddinsFolder "$revitVersion\SDX.dll"
        if (Test-Path $existingDllPath) {
            $existingDllPaths += $existingDllPath
        }
    }

    if ($existingDllPaths.Count -gt 0) {
        $filesAreUnlocked = Wait-ForAllFilesToUnlock -FilePaths $existingDllPaths -TimeoutSeconds 10
        if (-not $filesAreUnlocked) {
            throw "Some target files are locked. Close Revit and run the updater again."
        }
    }

    $baseUrl = $filesBaseUrlToUse.TrimEnd('/')
    $downloadClient = New-Object System.Net.WebClient
    try {
        foreach ($revitVersion in $plan.RevitVersions) {
            $destinationFolder = Join-Path $plan.RevitAddinsFolder $revitVersion
            if (-not (Test-Path $destinationFolder)) {
                New-Item -ItemType Directory -Path $destinationFolder -Force | Out-Null
            }

            Write-Log "Installing SDX for Revit $revitVersion on channel $($plan.Channel)..."
            foreach ($fileName in $FilesToUpdate) {
                $extension = [System.IO.Path]::GetExtension($fileName)
                $remoteFileName = "SDX-$revitVersion$extension"
                $downloadUrl = "$baseUrl/$remoteFileName"
                $destinationFilePath = Join-Path $destinationFolder $fileName

                Write-Log "  Downloading: $downloadUrl"
                $downloadClient.DownloadFile($downloadUrl, $destinationFilePath)
                Write-Log "  Installed to: $destinationFilePath"
            }
        }
    }
    finally {
        $downloadClient.Dispose()
    }

    $versionsText = ($plan.RevitVersions | Sort-Object) -join ", "
    return [pscustomobject]@{
        Version = $targetVersionToUse
        RevitVersions = @($plan.RevitVersions | Sort-Object)
        RevitVersionsText = $versionsText
        RevitAddinsFolder = $plan.RevitAddinsFolder
    }
}

# Shows a basic console message for completion/warning/error messages.
function Show-MessageBox {
    param(
        [string] $Message,
        [string] $Title,
        [string] $Icon = "Information"
    )

    $border = "=" * 70
    Write-Host ""
    Write-Host $border
    Write-Host "SDX Updater - $Title"
    Write-Host "Status: $Icon"
    Write-Host ""
    Write-Host $Message
    Write-Host $border
    Write-Host ""
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

function Apply-SdxButtonStyle {
    param(
        [System.Windows.Forms.Button] $Button,
        [string] $BackgroundHex,
        [string] $ForegroundHex,
        [string] $BorderHex,
        [string] $HoverHex = "#1084D8",
        [string] $PressedHex = "#006CBF",
        [int] $CornerRadius = 8
    )

    $Button.UseVisualStyleBackColor = $false
    $Button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $Button.FlatAppearance.BorderSize = 1
    $Button.BackColor = [System.Drawing.ColorTranslator]::FromHtml($BackgroundHex)
    $Button.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($ForegroundHex)
    $Button.FlatAppearance.BorderColor = [System.Drawing.ColorTranslator]::FromHtml($BorderHex)
    $Button.FlatAppearance.MouseOverBackColor = [System.Drawing.ColorTranslator]::FromHtml($HoverHex)
    $Button.FlatAppearance.MouseDownBackColor = [System.Drawing.ColorTranslator]::FromHtml($PressedHex)
    $Button.Padding = New-Object System.Windows.Forms.Padding(12, 3, 12, 3)
    $Button.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Point)

    Set-RoundedControlRegion -Control $Button -CornerRadius $CornerRadius
    $Button.Add_Resize({
        Set-RoundedControlRegion -Control $this -CornerRadius $CornerRadius
    })
}

function Set-RoundedControlRegion {
    param(
        [System.Windows.Forms.Control] $Control,
        [int] $CornerRadius = 8
    )

    if ($Control.Width -le 1 -or $Control.Height -le 1) {
        return
    }

    if ($CornerRadius -lt 1) {
        $CornerRadius = 1
    }

    $maxRadius = [Math]::Floor([Math]::Min($Control.Width, $Control.Height) / 2)
    if ($CornerRadius -gt $maxRadius) {
        $CornerRadius = $maxRadius
    }

    $diameter = $CornerRadius * 2
    $width = $Control.Width - 1
    $height = $Control.Height - 1

    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddArc(0, 0, $diameter, $diameter, 180, 90)
    $path.AddArc($width - $diameter, 0, $diameter, $diameter, 270, 90)
    $path.AddArc($width - $diameter, $height - $diameter, $diameter, $diameter, 0, 90)
    $path.AddArc(0, $height - $diameter, $diameter, $diameter, 90, 90)
    $path.CloseFigure()

    $previousRegion = $Control.Region
    $Control.Region = New-Object System.Drawing.Region($path)
    if ($null -ne $previousRegion) {
        $previousRegion.Dispose()
    }
    $path.Dispose()
}

# Console-based interactive wait for the scheduling Revit process.
# Press C to cancel the update or F to force-close Revit.
function Wait-ForRevitToCloseInteractive {
    param([int] $ProcessId, [int] $TimeoutSeconds = 120)

    $alreadyClosed = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
    if ($null -eq $alreadyClosed) {
        return [pscustomobject]@{ Closed = $true; Cancelled = $false; TimedOut = $false }
    }

    try {
        $startedUtc = [DateTime]::UtcNow
        $lastShownSecond = -1

        Write-Host ""
        Write-Host "SDX Tools updater is waiting for Revit (PID $ProcessId) to close."
        Write-Host "Press F to force close Revit, or C to cancel this update."
        Write-Host ""

        while ($true) {
            $running = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
            if ($null -eq $running) {
                return [pscustomobject]@{ Closed = $true; Cancelled = $false; TimedOut = $false }
            }

            $elapsedSeconds = [int]([DateTime]::UtcNow - $startedUtc).TotalSeconds
            if ($elapsedSeconds -ne $lastShownSecond) {
                Write-Host ("Waiting for Revit to close... {0}s elapsed" -f $elapsedSeconds)
                $lastShownSecond = $elapsedSeconds
            }

            if ($elapsedSeconds -ge $TimeoutSeconds) {
                return [pscustomobject]@{ Closed = $false; Cancelled = $false; TimedOut = $true }
            }

            if ([Console]::KeyAvailable) {
                $keyInfo = [Console]::ReadKey($true)
                $key = $keyInfo.Key

                if ($key -eq [ConsoleKey]::C) {
                    Write-Log "Update cancelled by user from console wait prompt."
                    return [pscustomobject]@{ Closed = $false; Cancelled = $true; TimedOut = $false }
                }

                if ($key -eq [ConsoleKey]::F) {
                    Write-Host "Force close requested..."
                    $forced = Try-ForceCloseRevit -ProcessId $ProcessId
                    if ($forced) {
                        Write-Log "Force-close succeeded for Revit (PID $ProcessId)."
                        return [pscustomobject]@{ Closed = $true; Cancelled = $false; TimedOut = $false }
                    }

                    Write-Log "Force-close did not finish Revit (PID $ProcessId)."
                    Write-Host "Force close did not complete. Waiting continues."
                }
            }

            Start-Sleep -Milliseconds 200
        }
    }
    catch {
        Write-Log "WARNING: console interactive wait failed, falling back to background wait: $($_.Exception.Message)"
        $closed = Wait-ForRevitToClose -ProcessId $ProcessId -TimeoutSeconds $TimeoutSeconds
        return [pscustomobject]@{ Closed = $closed; Cancelled = $false; TimedOut = (-not $closed) }
    }
}

function Show-WaitWindowPreview {
    param([int] $PreviewSeconds = 20)

    if ($PreviewSeconds -lt 3) {
        $PreviewSeconds = 3
    }

    $hostExecutable = Join-Path $PSHOME "powershell.exe"
    if (-not (Test-Path $hostExecutable)) {
        $hostExecutable = Join-Path $PSHOME "pwsh.exe"
    }
    if (-not (Test-Path $hostExecutable)) {
        $hostExecutable = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    }

    $dummyArguments = @(
        "-NoProfile",
        "-WindowStyle",
        "Hidden",
        "-Command",
        "Start-Sleep -Seconds $PreviewSeconds"
    )

    Write-Log "Starting updater wait-window preview for $PreviewSeconds second(s)."
    $dummyProcess = Start-Process -FilePath $hostExecutable -ArgumentList $dummyArguments -PassThru -WindowStyle Hidden

    try {
        $previewResult = Wait-ForRevitToCloseInteractive -ProcessId $dummyProcess.Id -TimeoutSeconds ($PreviewSeconds + 30)

        if ($previewResult.Cancelled) {
            Write-Log "Preview window cancelled by user."
            Show-MessageBox -Message "Preview cancelled. No files were changed." -Title "SDX Updater Preview" -Icon "Information"
            return
        }

        if ($previewResult.TimedOut) {
            Write-Log "Preview timed out."
            Show-MessageBox -Message "Preview timed out. No files were changed." -Title "SDX Updater Preview" -Icon "Warning"
            return
        }

        Write-Log "Preview completed normally."
        Show-MessageBox -Message "Preview completed. No files were changed." -Title "SDX Updater Preview" -Icon "Information"
    }
    finally {
        if ($null -ne $dummyProcess) {
            try {
                if (-not $dummyProcess.HasExited) {
                    $dummyProcess.Kill()
                    $dummyProcess.WaitForExit(3000) | Out-Null
                }
            }
            catch { }
            $dummyProcess.Dispose()
        }
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
    if ($TestWaitWindow) {
        Show-WaitWindowPreview -PreviewSeconds $TestWaitSeconds
        exit 0
    }

    try   { $mutexAcquired = $mutex.WaitOne(0) }
    catch [System.Threading.AbandonedMutexException] { $mutexAcquired = $true }

    if (-not $mutexAcquired) {
        Write-Log "Another SDX updater instance is already running. Exiting silently."
        exit 0
    }

    try {
        if (Test-ShouldRunStandalone) {
            Write-Log "Starting standalone install/update flow."
            Write-Log "Channel request  : $Channel"
            $standaloneResult = Invoke-StandaloneInstall
            Complete-Run -Success $true -Message "Installed SDX Tools $($standaloneResult.Version) for Revit $($standaloneResult.RevitVersionsText)." -ExitCode 0
        }

        Assert-MainParameters

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

        if (Test-ShouldRunStandalone) {
            Complete-Run -Success $false -Message "Standalone install/update failed: $($_.Exception.Message)" -ExitCode 1
        }

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
