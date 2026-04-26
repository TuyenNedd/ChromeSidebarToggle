#!/usr/bin/swift

import AppKit
import ApplicationServices
import Foundation

// Use Set instead of Array for faster lookup (O(1) lookup)
let targetTitles: Set<String> = [
    "Expand Tabs", "Collapse Tabs", 
]

guard let frontmostApp = NSWorkspace.shared.frontmostApplication,
      frontmostApp.bundleIdentifier == "com.google.Chrome" else {
    exit(0)
}

let appElement = AXUIElementCreateApplication(frontmostApp.processIdentifier)

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
    // Use an index pointer instead of queue.removeFirst() to avoid array shifting (O(1) pop)
    var headIndex = 0 
    
    while headIndex < queue.count {
        let current = queue[headIndex]
        headIndex += 1
        
        let element = current.element
        let depth = current.depth
        
        // Stop searching if depth exceeds 7
        if depth > 7 { continue }
        
        var role: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role) != .success {
            continue
        }
        
        // Avoid expensive type casting if not necessary
        guard let roleStr = role as? String else { continue }
        
        // Skip web content to save thousands of IPC calls
        if roleStr == "AXWebArea" { continue }
        
        // kAXButtonRole is "AXButton"
        if roleStr == "AXButton" { 
            // Reduce IPC calls. Fetch and check Title first.
            var title: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &title) == .success,
               let titleStr = title as? String,
               targetTitles.contains(titleStr) {
                return element
            }
            
            // Only if Title doesn't match, make the expensive API call to get Description
            var desc: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &desc) == .success,
               let descStr = desc as? String,
               targetTitles.contains(descStr) {
                return element
            }
        }
        
        // Add children to the queue for BFS traversal
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

// Search with a smart retry mechanism
let maxRetries = 3
let retryDelayMicroseconds: useconds_t = 50_000
var targetButton: AXUIElement? = nil

for _ in 0..<maxRetries {
    // Iterate through all existing Chrome windows (fixes the input focus bug)
    for window in windows {
        if let found = findButtonBFS(startElement: window) {
            targetButton = found
            break
        }
    }
    // If the button is found, immediately exit the retry loop
    if targetButton != nil { break }
    
    usleep(retryDelayMicroseconds)
}

guard let button = targetButton else {
    exit(0)
}

AXUIElementPerformAction(button, kAXPressAction as CFString)