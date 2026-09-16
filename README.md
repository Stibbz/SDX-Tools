<div align="center">

# SDX Tools

**A Revit addin for things that should be native, but aren't.**

![Revit 2024](https://img.shields.io/badge/Revit-2024-0696D7?style=flat-square&logo=autodesk&logoColor=white)
![Revit 2025](https://img.shields.io/badge/Revit-2025-0696D7?style=flat-square&logo=autodesk&logoColor=white)
![Revit 2026](https://img.shields.io/badge/Revit-2026-0696D7?style=flat-square&logo=autodesk&logoColor=white)
![Revit 2027](https://img.shields.io/badge/Revit-2027-0696D7?style=flat-square&logo=autodesk&logoColor=white)
![.NET 8 / 10](https://img.shields.io/badge/.NET-8%20%2F%2010-512BD4?style=flat-square)
![Platform](https://img.shields.io/badge/platform-Windows-0078D4?style=flat-square)
![Language](https://img.shields.io/badge/C%23-WPF-239120?style=flat-square)

</div>

---

SDX Tools adds a dedicated **SDX** ribbon tab to Revit with tools that close gaps Autodesk left behind. Built by someone who uses Revit daily on large-scale civil engineering projects.

## Tools

Panels containing only hidden tools auto-hide from the ribbon. Each tool can be shown or hidden individually via Preferences — choices are remembered across updates.

### Manage

| Tool | Description |
|---|---|
| **Preferences** | Configure AutoSync intervals, show or hide individual tools from the ribbon, manage addin tab visibility, view usage statistics, and set the update channel — all in one place. Visibility choices are remembered across updates. |
| **Send Feedback** | Report issues or suggestions directly from inside Revit. |
| **Batch Link Files** | Link every DWG and RVT in a folder in one step, with control over workset assignment and positioning. |
| **Fix Line Patterns** | Corrects imported CAD line pattern segment lengths by reading dash and gap sizes encoded in the pattern name. Lists every pattern and the lengths it will write for confirmation first. |

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
| **Detail Lines Length** | Measures the total length of detail lines in the active view, grouped by line style. Line style and wall height are selectable. |
| **Flip Each Element** | Flips every selected family instance or wall about its hand axis. |
| **Allow / Disallow Join** | Enable or disable wall end joins on all selected walls at once — no need to click each handle individually. |
| **Join All / Unjoin All** | Join every selected element to every other, or strip all joins from a picked element in one operation. |

### Productivity

| Tool | Description |
|---|---|
| **Section Box** | Toggle section box visibility in the active 3D view, even when a view template is applied. |
| **Scope Boxes** | Toggle scope box visibility in the active view, even when a view template is applied. |
| **Free Dims** | Place horizontal, vertical, or aligned dimensions between any two picked points, independent of existing elements. |
| **Find & Replace** | Find and replace text across text notes, tags, and views with a live preview grid before applying changes. Remembers the last-used scope, filters, and options across sessions. |
| **Hide CAD Layer** | Click any line on an imported CAD drawing to hide the entire layer from the view — no layer name lookup needed. |
| **Tag CAD Layers** | Place text note tags on each visible CAD layer in the active view, labelled by layer name. Useful for CAD coordination and layer auditing. |

### View Settings

| Tool | Description |
|---|---|
| **V/G Manager** | Batch manage visibility and graphics overrides across view templates from a single grid. |
| **Copy V/G Settings** | Copy visibility/graphics overrides from the active view to one or more target views. |
| **Perp Sections** | Create perpendicular section views along a selected line or wall. |

### Sheet Tools

| Tool | Description |
|---|---|
| **Level Extents** | Snaps level datum extents to match the crop region of the active section or elevation view, keeping levels tidy without manual dragging. |
| **Match Viewports Vertically** | Align the crop regions of multiple viewports on a sheet to a reference viewport without repositioning them. Optionally aligns to a reference element picked in the model or in a linked file. |
| **Match Sheet Positions** | Copy viewport positions and view assignments from a source sheet to a target sheet. |

### Annotate

| Tool | Description |
|---|---|
| **Slope Lines** | Draw hachure slope lines between a top boundary and a bottom boundary, sized and spaced to the active view scale. |

---

## Getting started

**Requirements:** Revit 2024, 2025, 2026, or 2027

**Build (whole solution):** requires the .NET 10 SDK (builds all four targets in one pass):

```powershell
dotnet build -c Debug "SDX Tools.slnx"
```

Post-build copies each DLL to `deploy/{version}/SDX.dll` automatically.

**Build (individual target):**

```powershell
dotnet build -c Debug "Revit 2025\Revit 2025.csproj"
dotnet build -c Debug "Revit 2026\Revit 2026.csproj"
```

Visual Studio 2022 can open `SDX Tools.slnx` and build the 2024/2025/2026 targets. The Revit 2027 project (net10.0-windows) requires the .NET 10 CLI — VS 2022 tops out at .NET 9.

**Deploy:** Close Revit, then run:

```powershell
.\deploySDX-Tools.ps1
```

Copies `deploy/2024/`, `deploy/2025/`, `deploy/2026/`, and `deploy/2027/` to `%AppData%\Autodesk\Revit\Addins\{version}\`.

**Developing:** Load `bin\Debug\net8.0-windows\SDX.dll` directly via Revit's Addin Manager — this path is never locked by a running Revit instance.

---

## Usage statistics

Usage reporting is optional and can be turned off at any time in Preferences.

I built SDX Tools for myself and gradually started sharing it with colleagues. At some point I realised I had no idea which tools anyone actually used — I was adding features based on gut feel and fixing bugs only when someone mentioned them in passing. Usage statistics fix both of those problems. When I can see that Level Extents runs dozens of times a day and Template Activity Checker has never been touched, I know where to spend time. When I can see a tool failing at twice its usual rate after a release, I know something broke without waiting for a report.

None of this requires knowing who you are or anything about your project. The data is a plain count — tool X ran Y times with Z failures — plus the minimum context needed to make that count meaningful.

**What is sent** — once per day at most, in a single batched request when Revit starts:

| Field | Example | Why |
|-------|---------|-----|
| Tool id and outcome counts | `LevelExtents: 12 succeeded, 1 failed, 3 cancelled` | Which tools are used, and which ones break |
| Install id | a random GUID, generated on your machine | Distinguishes installs so "20 people used this" is separable from "one person used it 20 times" |
| SDX version | `0.4.0-preview` | Correlates failures with releases |
| Revit version | `2026` | Shows which Revit versions are still worth supporting |
| Update channel | `Stable` or `Preview` | Shows whether preview builds are less stable |
| Date | `2026-08-13` | The day the tools were used |

**What is never sent:** user names, machine names, domain names, file paths, project or family names, model contents, or any free text. The install id is a random GUID created locally — it is not derived from your username, machine, domain or hardware, and wiping `%AppData%\SDX\` resets it.

It is sent to `https://telemetry.draak.org/v1/usage`. If that request fails the counts stay on your machine and the addin carries on as normal — telemetry never blocks, delays or interrupts anything.

**Seeing exactly what is sent:** Preferences → Advanced → **Show what is sent** prints the precise payload that would go out on the next start. It is generated by the same code that does the sending, so it cannot drift from reality.

**Turning it on or off (per user):** Preferences → Advanced → **Usage Stats**. Switching it off also discards anything already collected but not yet sent.

**Turning it off (whole machine, for IT):** set a `DisableTelemetry` DWORD to `1` under `HKLM\Software\SDX\Tools`. This overrides the per-user toggle, nothing is collected or sent, and the toggle appears disabled with an explanation. Deploy it with:

```powershell
reg add "HKLM\Software\SDX\Tools" /v DisableTelemetry /t REG_DWORD /d 1 /f
```

The collector is a Cloudflare Worker; its source and the queries run against the data are in [`telemetry/`](telemetry/).

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
Revit 2024/     # Target project for R2024 (net48)
Revit 2025/     # Target project for R2025 (net8.0-windows)
Revit 2026/     # Target project for R2026 (net8.0-windows)
Revit 2027/     # Target project for R2027 (net10.0-windows)
deploy/         # Staging folder for deploySDX-Tools.ps1
```

---

## Release process

The public distribution repo (`Stibbz/SDX-Tools`) is updated automatically by `.github/workflows/release.yml` when a GitHub Release is published here.

**To publish a release:**

1. Bump `<Version>` in `Directory.Build.props` (single source of truth — stamped into `SDX.dll` and `version.json`).
2. Update `CHANGELOG.md` with user-facing changes.
3. Build all four targets and confirm 0 errors.
4. Publish a GitHub Release on this repo. The workflow fires and:
   - Builds all four Revit targets (2024, 2025, 2026, 2027)
   - Copies the built folders to the public repo
   - Generates and pushes `version.json` (including the `updater.ps1` SHA-256) and `updater.ps1`
   - Attaches a `.zip` to the GitHub Release for manual downloads

**Versioning (`MAJOR.MINOR.PATCH`):**

| Part | Bump when |
|------|-----------|
| MAJOR | Breaking change — tool removed, incompatible prefs, behaviour users must relearn |
| MINOR | New feature, backward-compatible |
| PATCH | Bug fix or tweak only |

While MAJOR is `0`: MINOR absorbs features and breaking changes; PATCH is fixes only.

Rules: always bump before releasing; never go backwards; use three parts only (`0.2.0`).

**Preview releases:** append `-preview.N` to the version string. Set the GitHub Release as a prerelease. Only users on the Preview update channel receive the update prompt.

**To test without publishing a release:** go to Actions → "Release SDX Tools" → Run workflow.

---

## Updater internals

`SDX/Update/UpdateService.cs` reads `version.json` from the public repo at startup (rate-limited to once per 6 hours). If a newer version is found, it prompts the user and sets a deferred flag. On Revit shutdown, it downloads `updater.ps1` to `%TEMP%\SdxUpdate\`, **verifies it against the `updaterSha256` in the manifest**, and only then launches it with:

```
powershell.exe -NoProfile -ExecutionPolicy Bypass -File updater.ps1 `
    -RevitPid <pid> -FilesBaseUrl <url> -RevitAddinsFolder <%AppData%\Autodesk\Revit\Addins>
```

`updater.ps1` waits for Revit to exit, re-checks the installed version, waits for `SDX.dll` to unlock, then downloads the flat per-Revit-version release assets (`SDX-2025.dll`, `SDX-2025.addin`, ...) from `$FilesBaseUrl` into each installed version folder. Log: `%AppData%\SDX\updater.log`.

The script runs with `-ExecutionPolicy Bypass`, so it is hashed before it runs. A mismatch **or a manifest with no `updaterSha256`** aborts the update and logs an error — refusing to update is always safer than running an unverified script. The release workflow hashes the exact `updater.ps1` it publishes, so this needs no manual step.

**`version.json` fields** (deserialized by `UpdateManifest.cs`):

| Key | Meaning |
|-----|---------|
| `version` | Latest published version |
| `filesBaseUrl` | Release download base — `updater.ps1` appends `/SDX-{revitVersion}.dll` etc. |
| `updaterUrl` | Direct URL to `updater.ps1` |
| `updaterSha256` | SHA-256 of `updater.ps1`, verified before it is executed. Required |
| `downloadPageUrl` | Fallback landing page if updater launch fails |
| `notes` | Release notes shown in the Revit toast |

**Update channels:** Preferences → Advanced → **Update channel**. `Stable` (default) only prompts for full releases. `Preview` also prompts for `-preview.N` builds. Switching from Preview back to Stable will offer a downgrade if the current installed version is a preview.

**One-time GitHub setup:** Create `Stibbz/SDX-Tools` with GitHub Pages on `main`/root. Generate a PAT with `repo` scope and add it as an Actions secret named `PAGES_DEPLOY_PAT` on this repo.
