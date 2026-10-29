#!/usr/bin/swift

import AppKit
import ApplicationServices
import Foundation

// Check Accessibility permissions with auto-prompt
let promptOption = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
if !AXIsProcessTrustedWithOptions(promptOption) {
    fputs("Error: Accessibility permission is not granted. Please allow it in System Settings > Privacy & Security > Accessibility.\n", stderr)
    exit(1)
}

// Check for Google Chrome (supports active app or fallback to running instance)
let chromeApp: NSRunningApplication
if let frontmost = NSWorkspace.shared.frontmostApplication,
   frontmost.bundleIdentifier == "com.google.Chrome" {
    chromeApp = frontmost
} else if let running = NSRunningApplication.runningApplications(withBundleIdentifier: "com.google.Chrome").first {
    chromeApp = running
} else {
    exit(0)
}

let appElement = AXUIElementCreateApplication(chromeApp.processIdentifier)

var windowsValue: CFTypeRef?
let winStatus = AXUIElementCopyAttributeValue(
    appElement,
    kAXWindowsAttribute as CFString,
    &windowsValue
)

guard winStatus == .success,
      let windows = windowsValue as? [AXUIElement],
      !windows.isEmpty else {
    fputs("Error: Could not retrieve Chrome windows (AXError: \(winStatus.rawValue)).\n", stderr)
    exit(1)
}

func isTargetButton(text: String) -> Bool {
    let lower = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if lower.isEmpty { return false }
    if lower == "expand tabs" || lower == "collapse tabs" ||
       lower == "expand tab strip" || lower == "collapse tab strip" ||
       lower == "expand vertical tabs" || lower == "collapse vertical tabs" {
        return true
    }
    if lower.contains("expand tab") || lower.contains("collapse tab") ||
       (lower.contains("expand") && lower.contains("tab")) ||
       (lower.contains("collapse") && lower.contains("tab")) ||
       lower.contains("mở rộng thẻ") || lower.contains("thu gọn thẻ") {
        return true
    }
    return false
}

func findButtonBFS(startElement: AXUIElement, collectDebugButtons: inout [String]?) -> AXUIElement? {
    var queue: [(element: AXUIElement, depth: Int)] = [(startElement, 0)]
    var headIndex = 0 
    
    while headIndex < queue.count {
        let current = queue[headIndex]
        headIndex += 1
        
        let element = current.element
        let depth = current.depth
        
        // Extended depth limit for modern Chrome UI layouts
        if depth > 12 { continue }
        
        var role: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role) != .success {
            continue
        }
        
        guard let roleStr = role as? String else { continue }
        
        // Skip web content to avoid unnecessary IPC overhead
        if roleStr == "AXWebArea" { continue }
        
        if roleStr == "AXButton" { 
            var title: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &title) == .success,
               let titleStr = title as? String, !titleStr.isEmpty {
                if isTargetButton(text: titleStr) { return element }
                collectDebugButtons?.append("title='\(titleStr)' (d=\(depth))")
            }
            
            var desc: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &desc) == .success,
               let descStr = desc as? String, !descStr.isEmpty {
                if isTargetButton(text: descStr) { return element }
                collectDebugButtons?.append("desc='\(descStr)' (d=\(depth))")
            }

            var help: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXHelpAttribute as CFString, &help) == .success,
               let helpStr = help as? String, !helpStr.isEmpty {
                if isTargetButton(text: helpStr) { return element }
                collectDebugButtons?.append("help='\(helpStr)' (d=\(depth))")
            }
        }
        
        var children: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children) == .success,
           let childArray = children as? [AXUIElement] {
            for child in childArray {
                queue.append((child, depth + 1))
            }
        }
    }
    return nil
}

// Search with retry mechanism
let maxRetries = 3
let retryDelayMicroseconds: useconds_t = 50_000
var targetButton: AXUIElement? = nil
var noDebug: [String]? = nil

for _ in 0..<maxRetries {
    for window in windows {
        if let found = findButtonBFS(startElement: window, collectDebugButtons: &noDebug) {
            targetButton = found
            break
        }
    }
    if targetButton != nil { break }
    usleep(retryDelayMicroseconds)
}

guard let button = targetButton else {
    var debugButtons: [String]? = []
    for window in windows {
        _ = findButtonBFS(startElement: window, collectDebugButtons: &debugButtons)
    }
    let foundList = (debugButtons ?? []).joined(separator: ", ")
    fputs("Error: Expand/Collapse tabs button not found in Chrome UI. Found buttons: [\(foundList)]\n", stderr)
    exit(1)
}

let actionResult = AXUIElementPerformAction(button, kAXPressAction as CFString)
if actionResult != .success {
    fputs("Error: Failed to press button (AXError: \(actionResult.rawValue)).\n", stderr)
    exit(1)
}