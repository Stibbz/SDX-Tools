<div align="center">

# SDX Tools

**A Revit addin for things that should be native, but aren't.**

![Revit 2025](https://img.shields.io/badge/Revit-2025-0696D7?style=flat-square&logo=autodesk&logoColor=white)
![Revit 2026](https://img.shields.io/badge/Revit-2026-0696D7?style=flat-square&logo=autodesk&logoColor=white)
![.NET 8](https://img.shields.io/badge/.NET-8.0-512BD4?style=flat-square)
![Platform](https://img.shields.io/badge/platform-Windows-0078D4?style=flat-square)
![Language](https://img.shields.io/badge/C%23-WPF-239120?style=flat-square)

</div>

---

SDX Tools adds a dedicated **SDX** ribbon tab to Revit with tools that close gaps Autodesk left behind. Built by someone who uses Revit daily on large-scale civil engineering projects.

## Tools

### Manage

| Tool | Description |
|---|---|
| **Preferences** | Configure AutoSync intervals, show or hide individual tools from the ribbon, manage addin tab visibility, and view usage statistics — all in one place. |
| **Send Feedback** | Report issues or suggestions directly from inside Revit. |
| **Batch Link Files** | Link every DWG and RVT in a folder in one step, with control over workset assignment and positioning. |
| **Fix Line Patterns** | Corrects imported CAD line pattern segment lengths by reading dash and gap sizes encoded in the pattern name. |

### Selection

| Tool | Description |
|---|---|
| **Select by Parameter** | Choose any parameter and a value to select every matching element in the model — no filter setup required. |
| **Filter by Parameter** | Select elements, pick one of their parameters, and create a view filter rule instantly — skips the multi-step Visibility/Graphics workflow. |
| **Select by Family** | Pick any placed element to select everything in the model that shares the same family. |

### Geometry

| Tool | Description |
|---|---|
| **Move Geo** | Move selected elements by precise X/Y/Z offsets in millimetres, with a live preview before committing. |
| **Unhide All** | Unhides every individually hidden element in the active view in one click. |
| **Allow / Disallow Join** | Enable or disable wall end joins on all selected walls at once — no need to click each handle individually. |
| **Join All / Unjoin All** | Join every selected element to every other, or strip all joins from a picked element in one operation. |

### Productivity

| Tool | Description |
|---|---|
| **Section Box** | Toggle section box and scope box visibility in the active 3D view, even when a view template is applied. |
| **Free Dims** | Place horizontal, vertical, or aligned dimensions between any two picked points, independent of existing elements. |
| **Find & Replace** | Find and replace text across text notes, tags, and views with a live preview grid before applying changes. |
| **Hide CAD Layer** | Click any line on an imported CAD drawing to hide the entire layer from the view — no layer name lookup needed. |
| **Tag CAD Layers** | Place text note tags on each visible CAD layer in the active view, labelled by layer name. Useful for CAD coordination and layer auditing. |

### Sheet Tools

| Tool | Description |
|---|---|
| **Level Extents** | Snaps level datum extents to match the crop region of the active section or elevation view, keeping levels tidy without manual dragging. |
| **Match Viewports** | Align the crop regions of multiple viewports on a sheet to a reference viewport without repositioning them. |
| **Match Sheet Positions** | Copy viewport positions and view assignments from a source sheet to a target sheet. |

---

## Getting started

**Requirements:** Revit 2025 or 2026 · Visual Studio 2022+

**Build:** Open `SDX Tools.slnx` in Visual Studio. Post-build copies the DLL to `deploy/{version}/SDX.dll` automatically.

Alternatively, build each target directly with the .NET CLI:

```powershell
dotnet build -c Debug "Revit 2025\Revit 2025.csproj"
dotnet build -c Debug "Revit 2026\Revit 2026.csproj"
```

**Deploy:** Close Revit, then run:

```powershell
.\deploySDX-Tools.ps1
```

Copies `deploy/2025/` and `deploy/2026/` to `%AppData%\Autodesk\Revit\Addins\{version}\`.

**Developing:** Load `bin\Debug\net8.0-windows\SDX.dll` directly via Revit's Addin Manager — this path is never locked by a running Revit instance.

---

## Project structure

```
SDX/            # Shared project — all tool source
  Shared/       # Cross-tool infrastructure
    Core/       # Utilities, settings, toast, debug logging
    Dialogs/    # Shared WPF dialogs
    Styles/     # Shared WPF resource dictionary
    Controls/   # Shared WPF controls
  Ribbon/       # IExternalApplication entry point
  {ToolName}/   # One folder per tool
Revit 2025/     # Target project for R2025
Revit 2026/     # Target project for R2026
deploy/         # Staging folder for deploySDX-Tools.ps1
```

---

## Release process

The public distribution repo (`Stibbz/SDX-Tools`) is updated automatically by `.github/workflows/release.yml` when a GitHub Release is published here.

**To publish a release:**

1. Bump `<Version>` in `Directory.Build.props` (single source of truth — stamped into `SDX.dll` and `version.json`).
2. Publish a GitHub Release on this repo. The workflow fires and:
   - Builds both Revit 2025 and 2026 targets
   - Copies the built `2025/` and `2026/` folders to the public repo
   - Generates and pushes `version.json` and `updater.ps1`
   - Attaches a `.zip` to the GitHub Release for manual downloads

**Versioning (`MAJOR.MINOR.PATCH`):**

| Part | Bump when |
|------|-----------|
| MAJOR | Breaking change — tool removed, incompatible prefs, behaviour users must relearn |
| MINOR | New feature, backward-compatible |
| PATCH | Bug fix or tweak only |

While MAJOR is `0`: MINOR absorbs features and breaking changes; PATCH is fixes only.

Rules: always bump before releasing; never go backwards; use three parts only (`0.2.0`).

**To test without publishing a release:** go to Actions → "Release SDX Tools" → Run workflow.

---

## Updater internals

`SDX/Update/UpdateService.cs` checks `version.json` on the public Pages site at startup (rate-limited to once per 6 hours). If a newer version is found, it prompts the user and sets a deferred flag. On Revit shutdown, it downloads `updater.ps1` to `%TEMP%\SdxUpdate\` and launches it with:

```
powershell.exe -NoProfile -ExecutionPolicy Bypass -File updater.ps1 `
    -RevitPid <pid> -FilesBaseUrl <url> -RevitAddinsFolder <%AppData%\Autodesk\Revit\Addins>
```

`updater.ps1` waits for Revit to exit, waits for `SDX.dll` to unlock, then downloads `SDX.dll` and `SDX.addin` from `$FilesBaseUrl/{version}/` into each installed version folder. Log: `%AppData%\SDX\updater.log`.

**`version.json` fields** (deserialized by `UpdateManifest.cs`):

| Key | Meaning |
|-----|---------|
| `version` | Latest published version |
| `filesBaseUrl` | Base URL — append `/{version}/SDX.dll` etc. |
| `updaterUrl` | Direct URL to `updater.ps1` |
| `downloadPageUrl` | Fallback landing page if updater launch fails |
| `notes` | Release notes shown in the Revit toast |

**One-time GitHub setup:** Create `Stibbz/SDX-Tools` with GitHub Pages on `main`/root. Generate a PAT with `repo` scope and add it as an Actions secret named `PAGES_DEPLOY_PAT` on this repo.
