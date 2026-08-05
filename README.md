<div align="center">

# SDX Tools

**A productivity addin for Autodesk Revit — things that should be included natively, but aren't.**

![Revit 2025](https://img.shields.io/badge/Revit-2025-0696D7?style=flat-square&logo=autodesk&logoColor=white)
![Revit 2026](https://img.shields.io/badge/Revit-2026-0696D7?style=flat-square&logo=autodesk&logoColor=white)
![.NET 8](https://img.shields.io/badge/.NET-8.0-512BD4?style=flat-square)
![Platform](https://img.shields.io/badge/platform-Windows-0078D4?style=flat-square)
![Language](https://img.shields.io/badge/C%23-WPF-239120?style=flat-square)

</div>

---

SDX Tools adds a dedicated **SDX** ribbon tab to Revit with tools across selection, geometry, view settings, link management, and session management. Created by someone who uses the software daily — feedback on bugs, improvements, and missing functionality is welcome.

---

## Tools

### Manage

| Tool | Description |
|---|---|
| **Addin Manager** | Show or hide any of Revit's ribbon tabs to reduce clutter. Visibility settings persist across sessions. |
| **AutoSync** | Automatically saves and syncs-to-central on configurable intervals. A subtle toast notification keeps you aware of when it fires. |
| **Usage Counter** | Tracks how many times each SDX tool has been run, so you know which ones are actually pulling their weight. |

### Selection

| Tool | Description |
|---|---|
| **Select by Parameter** | Pick any parameter, enter a value, and select every matching element in the model — no filter setup required. |
| **Filter by Parameter** | Select some elements, choose one of their parameters, and instantly create a view filter rule. Skips the multi-step Visibility/Graphics workflow. |
| **Select by Family** | Pick any placed element and select everything else in the model that shares the same family. |

### Geometry

| Tool | Description |
|---|---|
| **Move Geo** | Move selected elements by precise X/Y/Z offsets in millimetres, with a live preview before committing. |
| **Unhide All** | Unhides every hidden element in the active view in one click. |
| **Detail Lines Length** | Totals the length of all detail lines in the active view, broken down by line style. |
| **Allow / Disallow Join** | Enable or disable wall end joins on all selected walls simultaneously — no need to click each wall handle one at a time. |
| **Join All / Unjoin All** | Join every selected element to every other, or strip all joins from a picked element at once. |

### View Settings

| Tool | Description |
|---|---|
| **V/G Manager** | Edit Visibility/Graphics overrides across multiple view templates in a single grid interface. Far faster than opening each template individually. |
| **Copy V/G Settings** | Copy the V/G overrides from the active view to any number of target views or templates in one operation. |
| **Level Extents** | Snaps level datum extents to match the crop region of the active section or elevation view, keeping levels tidy without manual dragging. |

### Links

| Tool | Description |
|---|---|
| **Batch Link Files** | Point it at a folder and it links every DWG and RVT inside — with workset and positioning options — in one step. |
| **Tag CAD Layers** | Places text note tags on each visible CAD layer in the active view, labelled by layer name. Handy for CAD coordination and layer auditing. |
| **Hide CAD Layer** | Click any line on an imported CAD drawing and the entire layer disappears from the view. No layer name lookup needed. |

---

## Installation

### First-time setup

1. Close Revit.
2. Download `SDX.dll` and `SDX.addin` from the `2025` or `2026` folder above (matching your Revit version).
3. Copy both files to:
   ```
   %AppData%\Autodesk\Revit\Addins\2025\
   ```
   or
   ```
   %AppData%\Autodesk\Revit\Addins\2026\
   ```
4. Open Revit. The SDX tab will appear on the ribbon.

### Automatic updates

Once installed, SDX Tools keeps itself up to date automatically:

1. When Revit starts, SDX Tools silently checks `version.json` in this repository.
2. If a newer version is available, a notification appears inside Revit.
3. If you agree to update, the add-in downloads `updater.ps1` and launches it when Revit closes.
4. The script waits for Revit to fully exit, then downloads `SDX.dll` and `SDX.addin` directly from this repository and copies them into your Revit Addins folder.
5. No admin rights required. A log is written to `%AppData%\SDX\updater.log`.

You can inspect `updater.ps1` above to see exactly what it does before anything runs.
