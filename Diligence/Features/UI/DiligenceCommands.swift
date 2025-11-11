//
//  DiligenceCommands.swift
//  Diligence
//
//  Menu commands for the Diligence app
//

import SwiftUI
import AppKit

struct DiligenceCommands: Commands {
    var body: some Commands {
        // Replace the standard Settings menu item
        CommandGroup(replacing: .appSettings) {
            Button("Settings...") {
                print("🪟 Opening Settings window via menu command")
                SettingsWindowController.openSettings()
            }
            .keyboardShortcut(",", modifiers: .command)
        }
        
        // Add Window menu for settings window management
        CommandGroup(after: .windowArrangement) {
            Button("Settings") {
                print("🪟 Opening Settings window via Window menu")
                SettingsWindowController.openSettings()
            }
            .keyboardShortcut(",", modifiers: [.command, .option])
        }
    }
}
