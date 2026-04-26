#!/usr/bin/swift

import AppKit
import ApplicationServices
import Foundation

let targetTitles = ["Expand Tabs", "Collapse Tabs"]

guard let frontmostApp = NSWorkspace.shared.frontmostApplication,
      frontmostApp.bundleIdentifier == "com.google.Chrome" else {
    exit(0)
}

let appElement = AXUIElementCreateApplication(frontmostApp.processIdentifier)

// Get the full windows array instead of forcing window.first
var windowsValue: CFTypeRef?
guard AXUIElementCopyAttributeValue(
    appElement,
    kAXWindowsAttribute as CFString,
    &windowsValue
) == .success,
let windows = windowsValue as? [AXUIElement] else {
    exit(0)
}

func findButtonBFS(startElement: AXUIElement) -> AXUIElement? {
    var queue: [(element: AXUIElement, depth: Int)] = [(startElement, 0)]
    
    while !queue.isEmpty {
        let current = queue.removeFirst()
        let element = current.element
        let depth = current.depth
        
        if depth > 7 { continue }
        
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        let roleStr = role as? String ?? ""
        
        if roleStr == "AXWebArea" { continue }
        
        if roleStr == (kAXButtonRole as String) {
            var title: CFTypeRef?
            AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &title)
            let titleStr = title as? String ?? ""
            
            var desc: CFTypeRef?
            AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &desc)
            let descStr = desc as? String ?? ""
            
            if targetTitles.contains(titleStr) || targetTitles.contains(descStr) {
                return element
            }
        }
        
        var children: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        
        if let childArray = children as? [AXUIElement] {
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

for _ in 0..<maxRetries {
    // Iterate through all existing Chrome windows
    for window in windows {
        if let found = findButtonBFS(startElement: window) {
            targetButton = found
            break
        }
    }
    // If the button was found in one of the windows, exit the retry loop
    if targetButton != nil { break }
    
    usleep(retryDelayMicroseconds)
}

guard let button = targetButton else {
    exit(0)
}

AXUIElementPerformAction(button, kAXPressAction as CFString)
