//
//  WindowNotifications.swift
//  Diligence
//
//  Window management notifications and utilities
//

import Foundation
import AppKit

/// Notification names for window management events
extension Notification.Name {
    static let windowShouldReconfigure = Notification.Name("DiligenceWindowShouldReconfigure")
    static let windowStateChanged = Notification.Name("DiligenceWindowStateChanged")
    static let externalWindowEvent = Notification.Name("DiligenceExternalWindowEvent")
}

/// Utilities for triggering window management actions
struct WindowManagementUtility {
    
    /// Call this when the app window is created via external events (email actions, etc.)
    static func handleExternalWindowCreation(reason: String) {
        print("🪟 WindowManagementUtility: External window creation - \(reason)")
        
        DispatchQueue.main.async {
            // Trigger window reconfiguration
            let stateManager = MainWindowStateManager.shared
            stateManager.reconfigureMainWindows()
            
            // Post notification for other components
            NotificationCenter.default.post(
                name: .externalWindowEvent,
                object: nil,
                userInfo: ["reason": reason]
            )
        }
    }
    
    /// Call this to force reconfiguration of main windows
    static func forceReconfigureMainWindows() {
        print("🪟 WindowManagementUtility: Force reconfigure requested")
        
        DispatchQueue.main.async {
            let stateManager = MainWindowStateManager.shared
            stateManager.reconfigureMainWindows()
        }
    }
    
    /// Call this to ensure a specific window is properly sized
    static func ensureWindowProperSize(_ window: NSWindow) {
        print("🪟 WindowManagementUtility: Ensuring proper size for window: \(window.title)")
        
        DispatchQueue.main.async {
            let stateManager = MainWindowStateManager.shared
            stateManager.configureSpecificWindow(window)
        }
    }
    
    /// Get debug information about current window state
    static func getWindowDebugInfo() -> String {
        let stateManager = MainWindowStateManager.shared
        return stateManager.debugCurrentWindowState()
    }
    
    /// Reset all window preferences
    static func resetAllWindowPreferences() {
        print("🪟 WindowManagementUtility: Resetting all window preferences")
        
        let stateManager = MainWindowStateManager.shared
        stateManager.resetWindowState()
        
        let settingsManager = SettingsWindowStateManager.shared
        settingsManager.clearSavedState()
    }
}

/// Extension to help with window detection and management
extension NSWindow {
    
    /// Check if this window is a main Diligence app window
    var isDiligenceMainWindow: Bool {
        return title == "Diligence" || 
               (title.isEmpty && canBecomeMain && level == .normal && 
                styleMask.contains(.titled) && styleMask.contains(.resizable))
    }
    
    /// Check if this window needs size configuration
    var needsSizeConfiguration: Bool {
        let hasAutosaveName = !frameAutosaveName.isEmpty
        let hasDelegate = delegate is MainWindowDelegate
        let hasProperMinSize = minSize.width >= MainWindowStateManager.minimumWindowWidth
        
        return !hasAutosaveName || !hasDelegate || !hasProperMinSize
    }
    
    /// Apply proper window configuration
    func applyDiligenceConfiguration() {
        let stateManager = MainWindowStateManager.shared
        stateManager.configureSpecificWindow(self)
    }
}