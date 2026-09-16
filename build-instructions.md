## Build Instructions

To ensure the script runs at maximum speed (under 5ms), compile the Swift source code into a native binary executable using the following Terminal command:

```bash
swiftc -O toggle-chrome-sidebar.swift -o toggle-chrome-sidebar
```

---

### Deployment

#### Option 1: macOS Automator Quick Action (Native macOS Shortcut)
If using macOS Services / Quick Actions:

1. Copy the compiled binary to your Services folder:
   ```bash
   cp toggle-chrome-sidebar ~/Library/Services/
   ```

2. Remove any quarantine flags (Gatekeeper):
   ```bash
   xattr -c ~/Library/Services/toggle-chrome-sidebar
   ```

3. Configure in **Automator**:
   - Create a **Quick Action**.
   - Set *Workflow receives*: `no input` in `Google Chrome.app`.
   - Add a **Run Shell Script** action:
     - Shell: `/bin/zsh`
     - Command: `/Users/<username>/Library/Services/toggle-chrome-sidebar`
   - Save as `ToggleChromeSideBar`.
   - Assign hotkey in **System Settings > Keyboard > Keyboard Shortcuts > Services > General**.

---

#### Option 2: Raycast
If using Raycast:

```bash
mkdir -p ~/raycast-scripts/bin
cp toggle-chrome-sidebar ~/raycast-scripts/bin/
cp toggle-chrome-sidebar.sh ~/raycast-scripts/
```

---

### Accessibility Permissions (Critical)

macOS requires explicit Accessibility permissions to allow controlling Chrome's UI via Accessibility APIs:

1. **For Automator / Quick Action Shortcuts**:
   When triggered via shortcut, macOS executes the script through `WorkflowServiceRunner.xpc`.
   - Open **System Settings > Privacy & Security > Accessibility**.
   - Click the **`+`** button.
   - Press **`Cmd + Shift + G`** and enter the exact executable path:
     ```text
     /System/Library/Frameworks/AppKit.framework/Versions/C/XPCServices/WorkflowServiceRunner.xpc/Contents/MacOS/WorkflowServiceRunner
     ```
   - Click **Open** and ensure the toggle is turned **ON**.
   - *(Optional)* If the toggle was already enabled prior to a macOS update, toggle it **OFF** and back **ON** to refresh permissions.

2. **For Raycast**:
   - Open **System Settings > Privacy & Security > Accessibility**.
   - Enable the toggle for **Raycast**.
