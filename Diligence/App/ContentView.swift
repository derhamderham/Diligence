//
//  ContentView.swift
//  Diligence
//
//  Created by derham on 11/10/25.
//  Updated to include sidebar navigation with Settings button
//

import SwiftUI
import SwiftData
import Combine

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dependencyContainer) private var container
    @Environment(\.openSettings) private var openSettings
    
    // Sidebar navigation
    @State private var selectedView: NavigationItem? = .tasks
    
    enum NavigationItem: String, CaseIterable, Identifiable {
        case tasks = "Tasks"
        case gmail = "Gmail"
        case settings = "Settings"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .tasks: return "checkmark.circle"
            case .gmail: return "envelope"
            case .settings: return "gearshape"
            }
        }
    }
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(selection: $selectedView) {
                Section("Navigation") {
                    ForEach([NavigationItem.tasks, NavigationItem.gmail], id: \.self) { item in
                        NavigationLink(value: item) {
                            Label(item.rawValue, systemImage: item.icon)
                        }
                    }
                }
                
                Section("Configuration") {
                    Button(action: {
                        openSettings()
                    }) {
                        Label("Settings", systemImage: "gearshape")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Diligence")
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 300)
        } detail: {
            // Detail view based on selection
            Group {
                switch selectedView {
                case .tasks:
                    TaskListView()
                case .gmail:
                    GmailView()
                case .settings, .none:
                    placeholderView
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
    
    @ViewBuilder
    private var placeholderView: some View {
        VStack(spacing: 16) {
            Image(systemName: "sidebar.left")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("Select an item from the sidebar")
                .font(.title3)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [DiligenceTask.self, TaskSection.self], inMemory: true)
}
