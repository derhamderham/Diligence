//
//  SettingsWindowStateManager.swift
//  Diligence
//
//  Manages settings window state persistence
//

import Foundation
import AppKit
import Combine

class SettingsWindowStateManager {
    static let shared = SettingsWindowStateManager()
    
    private let userDefaults = UserDefaults.standard
    
    private enum Keys {
        static let windowFrame = "SettingsWindowFrame"
        static let selectedCategory = "SelectedSettingsCategory"
        static let windowFrameLegacy = "SettingsWindowFrameLegacy" // For migration
    }
    
    private init() {}
    
    // MARK: - Window Frame Persistence
    
    func saveWindowFrame(_ frame: NSRect) {
        print("🪟 SettingsWindowStateManager: Saving frame \(frame)")
        
        // Save as structured data for better reliability
        let frameData = [
            "x": frame.origin.x,
            "y": frame.origin.y,
            "width": frame.size.width,
            "height": frame.size.height
        ]
        
        userDefaults.set(frameData, forKey: Keys.windowFrame)
        
        // Also save as string for compatibility
        let frameString = NSStringFromRect(frame)
        userDefaults.set(frameString, forKey: Keys.windowFrameLegacy)
        
        userDefaults.synchronize() // Force immediate save
    }
    
    func restoreWindowFrame() -> NSRect? {
        print("🪟 SettingsWindowStateManager: Attempting to restore window frame...")
        
        // Try structured data first
        if let frameData = userDefaults.dictionary(forKey: Keys.windowFrame),
           let x = frameData["x"] as? Double,
           let y = frameData["y"] as? Double,
           let width = frameData["width"] as? Double,
           let height = frameData["height"] as? Double {
            
            let frame = NSRect(x: x, y: y, width: width, height: height)
            print("🪟 SettingsWindowStateManager: Restored frame from structured data: \(frame)")
            return frame.isEmpty ? nil : frame
        }
        
        // Fallback to legacy string format
        if let frameString = userDefaults.string(forKey: Keys.windowFrameLegacy) {
            let frame = NSRectFromString(frameString)
            print("🪟 SettingsWindowStateManager: Restored frame from legacy string: \(frame)")
            return frame.isEmpty ? nil : frame
        }
        
        print("🪟 SettingsWindowStateManager: No saved frame found")
        return nil
    }
    
    // MARK: - Selected Category Persistence
    
    func saveSelectedCategory(_ category: SettingsCategory) {
        userDefaults.set(category.rawValue, forKey: Keys.selectedCategory)
    }
    
    func restoreSelectedCategory() -> SettingsCategory {
        guard let categoryString = userDefaults.string(forKey: Keys.selectedCategory),
              let category = SettingsCategory(rawValue: categoryString) else {
            return .general
        }
        return category
    }
    
    // MARK: - Window State Validation
    
    func shouldRestoreWindow() -> Bool {
        return restoreWindowFrame() != nil
    }
    
    func clearSavedState() {
        print("🪟 SettingsWindowStateManager: Clearing saved window state")
        userDefaults.removeObject(forKey: Keys.windowFrame)
        userDefaults.removeObject(forKey: Keys.windowFrameLegacy)
        userDefaults.removeObject(forKey: Keys.selectedCategory)
    }
}
