//
//  AppearanceSettingsView.swift
//  Diligence
//
//  App appearance and UI preferences
//

import SwiftUI
import AppKit
import Combine

enum AppTheme: String, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

enum FontSize: String, CaseIterable {
    case small = "small"
    case medium = "medium"
    case large = "large"
    
    var displayName: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }
    
    var scaleFactor: CGFloat {
        switch self {
        case .small: return 0.9
        case .medium: return 1.0
        case .large: return 1.1
        }
    }
}

struct AppearanceSettingsView: View {
    @AppStorage("appTheme") private var appTheme: AppTheme = .system
    @AppStorage("fontSize") private var fontSize: FontSize = .medium
    @AppStorage("showSidebar") private var showSidebar = true
    @AppStorage("compactMode") private var compactMode = false
    @AppStorage("showStatusBar") private var showStatusBar = true
    @AppStorage("animateTransitions") private var animateTransitions = true
    @AppStorage("reduceMotion") private var reduceMotion = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ModernSettingsSection(title: "Theme") {
                ModernSettingsRow(
                    title: "Appearance",
                    description: "Choose the app's color scheme"
                ) {
                    Picker("", selection: $appTheme) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            HStack(spacing: 8) {
                                Image(systemName: themeIcon(for: theme))
                                Text(theme.displayName)
                            }
                            .tag(theme)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                    .controlSize(.small)
                }
            }
            
            ModernSettingsSection(title: "Typography") {
                ModernSettingsRow(
                    title: "Font size",
                    description: "Adjust the overall text size in the app"
                ) {
                    Picker("", selection: $fontSize) {
                        ForEach(FontSize.allCases, id: \.self) { size in
                            Text(size.displayName).tag(size)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                    .controlSize(.small)
                }
            }
            
            ModernSettingsSection(title: "Layout") {
                ModernSettingsRow(
                    title: "Show sidebar",
                    description: "Display the navigation sidebar by default"
                ) {
                    Toggle("", isOn: $showSidebar)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
                
                ModernSettingsRow(
                    title: "Compact mode",
                    description: "Reduce spacing and padding for denser information display"
                ) {
                    Toggle("", isOn: $compactMode)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
                
                ModernSettingsRow(
                    title: "Show status bar",
                    description: "Display status information at the bottom of the window"
                ) {
                    Toggle("", isOn: $showStatusBar)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
            }
            
            ModernSettingsSection(title: "Animation") {
                ModernSettingsRow(
                    title: "Animate transitions",
                    description: "Use smooth animations when navigating between views"
                ) {
                    Toggle("", isOn: $animateTransitions)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
                
                ModernSettingsRow(
                    title: "Reduce motion",
                    description: "Minimize motion effects for better accessibility"
                ) {
                    Toggle("", isOn: $reduceMotion)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
            }
            
            // Preview Section
            ModernSettingsSection(title: "Preview") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sample Text")
                        .font(.system(size: 16 * fontSize.scaleFactor, weight: .medium))
                    
                    Text("This shows how your text will appear with the selected font size.")
                        .font(.system(size: 13 * fontSize.scaleFactor))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        Circle()
                            .fill(.blue)
                            .frame(width: 20, height: 20)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sample Task")
                                .font(.system(size: 14 * fontSize.scaleFactor, weight: .medium))
                            
                            Text("Due tomorrow")
                                .font(.system(size: 12 * fontSize.scaleFactor))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12 * fontSize.scaleFactor))
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
                .padding()
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                )
            }
            
            Spacer()
        }
        .onChange(of: appTheme) { _, newTheme in
            applyTheme(newTheme)
        }
    }
    
    // MARK: - Helper Methods
    
    private func themeIcon(for theme: AppTheme) -> String {
        switch theme {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }
    
    private func applyTheme(_ theme: AppTheme) {
        switch theme {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}

// MARK: - Preview

#Preview {
    AppearanceSettingsView()
        .frame(width: 600, height: 500)
        .padding()
}