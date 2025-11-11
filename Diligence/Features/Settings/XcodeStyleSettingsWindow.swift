//
//  XcodeStyleSettingsWindow.swift
//  Diligence
//
//  Simplified Settings Window Implementation for Natural macOS Behavior
//

import SwiftUI
import AppKit

// MARK: - Settings Window Controller

class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()
    
    private init() {
        // Create window with standard settings window style
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        super.init(window: window)
        
        configureWindow()
        setupContent()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func configureWindow() {
        guard let window = window else { return }
        
        window.title = "Diligence Settings"
        window.center()
        
        // Set reasonable size constraints
        window.minSize = NSSize(width: 600, height: 400)
        window.maxSize = NSSize(width: 1200, height: 800)
        
        // Enable automatic window restoration
        window.setFrameAutosaveName("DiligenceSettingsWindow")
        window.isRestorable = true
    }
    
    private func setupContent() {
        guard let window = window else { return }
        
        let settingsView = DiligenceSettingsView()
        let hostingView = NSHostingView(rootView: settingsView)
        
        window.contentView = hostingView
    }
    
    func showWindow() {
        if let window = window {
            if window.isVisible {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            } else {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
    
    // Static method for easy access
    static func openSettings() {
        SettingsWindowController.shared.showWindow()
    }
}

// MARK: - Settings Categories

enum SettingsCategory: String, CaseIterable, Identifiable {
    case general = "general"
    case accounts = "accounts"
    case tasks = "tasks"
    case aiLLM = "ai"
    case appearance = "appearance"
    case advanced = "advanced"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .general: return "General"
        case .accounts: return "Accounts"
        case .tasks: return "Tasks"
        case .aiLLM: return "AI & LLM"
        case .appearance: return "Appearance"
        case .advanced: return "Advanced"
        }
    }
    
    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .accounts: return "person.crop.circle"
        case .tasks: return "checklist"
        case .aiLLM: return "brain.head.profile"
        case .appearance: return "paintbrush"
        case .advanced: return "wrench.and.screwdriver"
        }
    }
    
    var description: String {
        switch self {
        case .general: return "App behavior and startup preferences"
        case .accounts: return "Gmail, Calendar, and other integrations"
        case .tasks: return "Task management and Reminders sync"
        case .aiLLM: return "AI assistant and language model settings"
        case .appearance: return "Theme, font size, and UI preferences"
        case .advanced: return "Debug options and advanced features"
        }
    }
}

// MARK: - Main Settings View

struct DiligenceSettingsView: View {
    @State private var selectedCategory: SettingsCategory = .general
    
    var body: some View {
        HSplitView {
            // Sidebar
            SettingsSidebar(selectedCategory: $selectedCategory)
                .frame(minWidth: 200, idealWidth: 220, maxWidth: 280)
            
            // Detail view
            SettingsDetailView(category: selectedCategory)
                .frame(minWidth: 400, maxWidth: .infinity)
        }
        .frame(minWidth: 600, idealWidth: 800, maxWidth: .infinity,
               minHeight: 400, idealHeight: 600, maxHeight: .infinity)
    }
}

// MARK: - Settings Sidebar

struct SettingsSidebar: View {
    @Binding var selectedCategory: SettingsCategory
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Sidebar Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Diligence Preferences")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
            
            // Categories List
            List(SettingsCategory.allCases, id: \.id, selection: $selectedCategory) { category in
                SettingsCategoryRow(
                    category: category,
                    isSelected: selectedCategory == category
                )
                .tag(category)
            }
            .listStyle(SidebarListStyle())
        }
    }
}

// MARK: - Category Row

struct SettingsCategoryRow: View {
    let category: SettingsCategory
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: category.icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isSelected ? .accentColor : .primary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(category.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isSelected ? .primary : .primary)
                
                Text(category.description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - Settings Detail View

struct SettingsDetailView: View {
    let category: SettingsCategory
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Image(systemName: category.icon)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.accentColor)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(category.title)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            
                            Text(category.description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.bottom)
                
                // Content based on category
                switch category {
                case .general:
                    GeneralSettingsView()
                case .accounts:
                    AccountsSettingsView()
                case .tasks:
                    TasksSettingsView()
                case .aiLLM:
                    AILLMSettingsView()
                case .appearance:
                    AppearanceSettingsView()
                case .advanced:
                    AdvancedSettingsView()
                }
                
                Spacer(minLength: 50)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Settings Row Component

struct ModernSettingsRow<Content: View>: View {
    let title: String
    let description: String?
    let content: () -> Content
    
    init(title: String, description: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.description = description
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                    
                    if let description = description {
                        Text(description)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                
                Spacer()
                
                content()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
        }
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Settings Section Component

struct ModernSettingsSection<Content: View>: View {
    let title: String
    let content: () -> Content
    
    init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, 4)
            
            VStack(spacing: 1) {
                content()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    DiligenceSettingsView()
}
