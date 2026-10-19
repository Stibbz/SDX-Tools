<div align="center">

# SDX Tools

**A Revit add-in for things that should be native, but aren't.**

[Download the latest release](https://github.com/Stibbz/SDX-Tools/releases/latest)

![Revit 2024](https://img.shields.io/badge/Revit-2024-0696D7?style=flat-square&logo=autodesk&logoColor=white)
![Revit 2025](https://img.shields.io/badge/Revit-2025-0696D7?style=flat-square&logo=autodesk&logoColor=white)
![Revit 2026](https://img.shields.io/badge/Revit-2026-0696D7?style=flat-square&logo=autodesk&logoColor=white)
![Revit 2027](https://img.shields.io/badge/Revit-2027-0696D7?style=flat-square&logo=autodesk&logoColor=white)
![Platform](https://img.shields.io/badge/platform-Windows-0078D4?style=flat-square)

</div>

---

SDX Tools adds a dedicated **SDX** ribbon tab to Revit with practical tools for repetitive jobs, missing workflows, CAD coordination, view management, sheets, and annotation.

It supports **Revit 2024, 2025, 2026, and 2027** on Windows.

## Install

### Recommended: SDX Updater

1. Open the [latest release](https://github.com/Stibbz/SDX-Tools/releases/latest).
2. Download and run **`SDX-Updater.exe`**.
   - If needed, use **`SDX-Updater.ps1`** instead.
3. Close Revit when prompted.
4. Choose the Revit versions you want SDX Tools installed for.
5. Choose **Stable** or **Preview**, then select **Install / Update**.

The updater can install SDX Tools without starting Revit first. It also handles later updates and verifies downloaded updater files before running them.

### Manual installation

If you prefer to install files yourself:

1. Close Revit.
2. Download the matching `SDX-<year>.dll` and `SDX-<year>.addin` files from the latest release.
3. Rename them to `SDX.dll` and `SDX.addin`.
4. Copy both files directly into your per-user Revit add-ins folder:

```text
%APPDATA%\Autodesk\Revit\Addins\<year>\
```

For Revit 2026:

```text
%APPDATA%\Autodesk\Revit\Addins\2026\SDX.dll
%APPDATA%\Autodesk\Revit\Addins\2026\SDX.addin
```

Start Revit and look for the SDX ribbon tab.

To update manually, close Revit and replace both files. To uninstall, delete both files.

## Updates

SDX Tools checks for updates when Revit starts and can also be updated through the standalone updater.

- Stable is the default channel and receives completed releases.
- Preview provides early access to upcoming releases.
- Change channels in Preferences, or choose a channel in the standalone updater.

## What’s new

Recent improvements include:

- Find & Replace can now work with writable title-block instance, title-block type, and sheet parameters.
- CAD Layer Manager now supports imported-CAD group visibility, staged graphic overrides, rule expressions, and more predictable group selection.
- Filter by Parameter replaces Create Direct Filter with a guided filter-creation workflow.
- Select by Parameter better supports family parameters, non-filterable parameters, duplicate names, and keyboard-first navigation.
- What’s Changed now renders Markdown release notes with headings, lists, emphasis, code, and links.

See the latest release notes for the full list.

## Tools

Ribbon panels that contain no visible tools are hidden automatically. You can show or hide individual tools in Preferences, and your choices survive updates.

WIP tools are usable but still being refined.
Unfinished tools are hidden by default and should be enabled from Preferences only if you want to try them.

### Manage

| Tool | Description |
|---|---|
| Preferences | Configure SDX Tools, update settings, visibility choices, AutoSync, update channel, usage statistics, and related options. |
| Send Feedback | Send an issue report, suggestion, or feedback directly from Revit. |
| Batch Link Files | Link every DWG and RVT in a folder in one operation, with positioning and workset controls. Supports imported CAD and cloud CAD links, and can save before linking. |
| Fix Line Patterns | Correct imported CAD line-pattern segment lengths from dash and gap values encoded in pattern names. Shows the planned changes before applying them. |
| Template Activity Checker — Unfinished | Inspect whether view templates are actively used. Hidden by default. |
| AutoSync | Configure automatic synchronization and saving intervals. |
| Addins Visibility | Control the visibility of add-in tabs. |
| Usage Counter | View local tool-usage counts and outcomes. |
| Project Tab Colors | Colour Revit document tabs by project. |

### Selection and parameters

| Tool | Description |
|---|---|
| Select by Parameter | Select model elements that match a chosen parameter value. Supports family and non-filterable parameters, with improved handling for duplicate parameter names and types. |
| Filter by Parameter | Create a view filter through a guided workflow: choose categories, select a parameter, configure a rule, and apply the filter. |
| Select by Family | Pick a placed element and select every matching family instance in the model. |
| Phase Parameter Sync | Synchronize the locked SP_PhaseCreated[L] and SP_PhaseDemolished[L] parameters from their source values automatically or with a manual command. |

### CAD and links

| Tool | Description |
|---|---|
| CAD Layer Manager | Manage CAD-layer and imported-CAD-group visibility, search layers, build reusable rule expressions, and stage graphic overrides before applying them to the active view or its template. |
| Hide CAD Layer | Click a line, text object, or point in an imported CAD drawing to hide its entire layer from the current view. |
| Tag CAD Layers — WIP | Place text-note tags for visible CAD layers in the active view, helping with coordination and layer auditing. |
| Batch Link Files | Link multiple DWG and RVT files from a folder with workset and positioning options. |

### Productivity and geometry

| Tool | Description |
|---|---|
| Section / Scope Box | Toggle section-box visibility in active 3D views and scope-box visibility in supported views, including views with templates applied. |
| Free Dims | Place horizontal, vertical, or aligned dimensions between picked points, independently of existing elements. |
| Find & Replace — WIP | Find and replace text, tags, view names, and writable title-block or sheet parameters with an editable preview before applying changes. |
| Move Geo | Move selected elements by precise X/Y/Z offsets in millimetres, with a preview before committing. |
| Unhide All | Unhide every individually hidden element in the active view. |
| Detail Lines Length — Unfinished | Measure total detail-line length in the active view, grouped by line style. Hidden by default. |
| Flip Each Element — WIP | Flip selected family instances or walls around their hand axis. Hidden by default. |
| Allow / Disallow Join | Enable or disable wall-end joins across selected elements. |
| Join Geometry | Join selected elements, or remove joins from a picked element, without repeated manual operations. |

### Views and templates

| Tool | Description |
|---|---|
| V/G Manager — WIP | Batch-manage visibility and graphic overrides across view templates from one grid. Hidden by default. |
| Copy V/G Settings — Unfinished | Copy visibility and graphic overrides from the active view to target views. Hidden by default. |
| Perp Sections — Unfinished | Create perpendicular section views along a selected line or wall. Hidden by default. |
| View Template Diff — WIP | Compare view templates setting by setting and selectively sync differences. Hidden by default. |
| View Template Snapshot — Unfinished | Export view-template settings to JSON and import them into a view or template, with a comparison preview before import. Hidden by default. |

### Sheets and annotation

| Tool | Description |
|---|---|
| Level Extents | Align level datum extents to the crop region of the active section or elevation view. |
| Match Viewports Vertically | Align viewport crop regions on a sheet to a reference viewport without moving the viewports themselves. |
| Match Sheet Positions | Copy viewport positions and view assignments from one sheet to another, with predictable mapped-viewport order. |
| Slope Lines | Draw hachure slope lines between top and bottom boundaries, sized and spaced for the active view scale. |

## Usage statistics and privacy

Usage reporting helps identify which tools are useful and when a release introduces failures. It is designed to collect only the minimum information needed for that purpose.

You can view exactly what would be sent in Preferences → Advanced → Show what is sent, and disable reporting at any time in Preferences → Advanced → Usage Stats.

### What is sent

At most once per day, SDX Tools may send a small batched report containing:

- Tool IDs and success, failure, or cancellation counts
- A random locally generated install ID
- SDX Tools version
- Revit version and build
- Runtime target
- Update channel
- Usage date

### What is never sent

SDX Tools does not send:

- User, machine, or domain names
- File paths
- Project, family, or model names
- Model contents
- Free text or user-entered values

The install ID is a random GUID created on your machine. It is not derived from your username, hardware, machine name, or domain. Removing %AppData%\SDX\ resets it.

If sending fails, the add-in continues normally. Telemetry never blocks or interrupts Revit workflows.

<details>
<summary><strong>IT / managed-device opt-out</strong></summary>

To disable telemetry for every user on a machine, create this registry value:

```powershell
reg add "HKLM\Software\SDX\Tools" /v DisableTelemetry /t REG_DWORD /d 1 /f
```

This overrides the per-user setting, prevents collection and sending, and disables the in-app toggle with an explanation.

</details>

## Feedback

Use SDX → Send Feedback inside Revit to report bugs, request features, or share suggestions.

For release downloads and release notes, visit the SDX Tools releases page.
