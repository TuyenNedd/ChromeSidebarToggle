# ChromeSidebarToggle

A high-performance utility that toggles Google Chrome's tab sidebar / vertical tabs with a single keystroke on macOS.

Chrome's "Expand tabs" / "Collapse tabs" button has no default keyboard shortcut. This tool uses the macOS Accessibility API to find and press it programmatically — no coordinate hacking, works on any screen size or resolution.

---

## Requirements

- macOS 13+ (tested up to macOS 27+)
- Google Chrome with tab sidebar / vertical tabs enabled
- Xcode Command Line Tools (`xcode-select --install`)
- Either **Automator (Built-in macOS)** or **[Raycast](https://www.raycast.com/)**

---

## Build

Compile the Swift source code into a native binary executable:

```bash
swiftc -O toggle-chrome-sidebar.swift -o toggle-chrome-sidebar
```

---

## Setup Options

### Option A: Native macOS Shortcut (Automator Quick Action)

This method requires **no third-party launcher**.

1. **Copy binary**:
   ```bash
   cp toggle-chrome-sidebar ~/Library/Services/
   xattr -c ~/Library/Services/toggle-chrome-sidebar
   ```

2. **Create Quick Action in Automator**:
   - Open **Automator.app** > **New Document** > **Quick Action**.
   - Configure at the top:
     - *Workflow receives*: **no input** in **Google Chrome.app**.
   - Search and add the **Run Shell Script** action from the library:
     - *Shell*: `/bin/zsh`
     - *Pass input*: `to stdin`
     - Script content:
       ```bash
       /Users/<your-username>/Library/Services/toggle-chrome-sidebar
       ```
   - Save the workflow (e.g. `ToggleChromeSideBar`).

3. **Assign Keyboard Shortcut**:
   - Go to **System Settings > Keyboard > Keyboard Shortcuts > Services > General**.
   - Locate `ToggleChromeSideBar` and double-click to assign your shortcut (e.g. `^Z` or `⌘⌥S`).

---

### Option B: Raycast Script Command

1. **Install scripts**:
   ```bash
   ./build.sh
   cp toggle-chrome-sidebar.sh ~/raycast-scripts/
   ```

2. **Configure Raycast**:
   - Add `~/raycast-scripts/` in **Raycast Settings > Extensions > Script Commands > Add Directories**.
   - Search for **"Toggle Chrome Sidebar"** in Raycast or assign a hotkey.

---

## 🔒 Granting Accessibility Permissions (Important)

macOS requires Accessibility permissions to interact with UI elements programmatically. If not granted, the script will prompt for permissions or log `kAXErrorAPIDisabled (-25211)`.

### For Automator / Quick Action Shortcuts
When invoked via a system shortcut, macOS runs the Quick Action through **`WorkflowServiceRunner.xpc`**:

1. Open **System Settings > Privacy & Security > Accessibility**.
2. Click the **`+`** button (authenticate with Touch ID or password).
3. Press **`Cmd + Shift + G`** in the file selector dialog.
4. Paste the exact executable path:
   ```text
   /System/Library/Frameworks/AppKit.framework/Versions/C/XPCServices/WorkflowServiceRunner.xpc/Contents/MacOS/WorkflowServiceRunner
   ```
5. Click **Open** and ensure the toggle is turned **ON (green)**.
6. Also ensure **Google Chrome** and **Automator** are toggled **ON** in the Accessibility list.

> [!TIP]
> **After macOS major updates:** macOS may invalidate existing TCC permissions. If the shortcut stops working after an OS upgrade, toggle **WorkflowServiceRunner** and **Google Chrome** **OFF** and then back **ON** in Accessibility settings.

### For Raycast
1. Open **System Settings > Privacy & Security > Accessibility**.
2. Turn **ON** the toggle for **Raycast**.

---

## How It Works

1. Identifies the active/running Google Chrome instance (`com.google.Chrome`).
2. Traverses Chrome's accessibility hierarchy using BFS (skipping `AXWebArea` to maintain sub-millisecond execution).
3. Matches the tab sidebar toggle button case-insensitively (`"expand tabs"`, `"collapse tabs"`, etc.).
4. Simulates a press event via `AXUIElementPerformAction` (`kAXPressAction`).
5. Displays clear error diagnostics and prompts for permissions if missing.

---

## Files

| File | Description |
|---|---|
| `toggle-chrome-sidebar.swift` | Swift source code with BFS search, error handling, and permission prompts |
| `toggle-chrome-sidebar` | Compiled native binary |
| `build-instructions.md` | Terminal build instructions & deployment notes |
| `build.sh` | Build helper script for Raycast deployment (`~/raycast-scripts/bin/`) |
| `toggle-chrome-sidebar.sh` | Bash wrapper script for Raycast integration |
| `chrome-mouse-offset.swift` | Utility script to inspect mouse offsets relative to Chrome windows |

---

## License

MIT
