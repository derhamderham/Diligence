//
//  AdvancedSettingsView.swift
//  Diligence
//
//  Advanced settings, debug options, and system management
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct AdvancedSettingsView: View {
    @AppStorage("enableDebugLogging") private var enableDebugLogging = false
    @AppStorage("enableCrashReporting") private var enableCrashReporting = true
    @AppStorage("maxEmailResults") private var maxEmailResults = 100
    @AppStorage("cacheLifetime") private var cacheLifetime = 24 // hours
    @AppStorage("enableExperimentalFeatures") private var enableExperimentalFeatures = false
    
    @State private var showingClearCacheAlert = false
    @State private var showingResetSettingsAlert = false
    @State private var showingDatabaseResetAlert = false
    @State private var cacheSize = "Calculating..."
    @State private var databaseSize = "Calculating..."
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ModernSettingsSection(title: "Email Processing") {
                ModernSettingsRow(
                    title: "Email limit",
                    description: "Maximum number of recent emails to load from Gmail"
                ) {
                    Picker("", selection: $maxEmailResults) {
                        Text("25 emails").tag(25)
                        Text("50 emails").tag(50)
                        Text("100 emails").tag(100)
                        Text("200 emails").tag(200)
                        Text("500 emails").tag(500)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                    .controlSize(.small)
                }
            }
            
            ModernSettingsSection(title: "Performance") {
                ModernSettingsRow(
                    title: "Cache lifetime",
                    description: "How long to keep downloaded email data cached"
                ) {
                    Picker("", selection: $cacheLifetime) {
                        Text("1 hour").tag(1)
                        Text("6 hours").tag(6)
                        Text("24 hours").tag(24)
                        Text("7 days").tag(168)
                        Text("30 days").tag(720)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                    .controlSize(.small)
                }
                
                ModernSettingsRow(
                    title: "Cache size",
                    description: "Current size of cached email data and attachments"
                ) {
                    HStack(spacing: 8) {
                        Text(cacheSize)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        Button("Clear") {
                            showingClearCacheAlert = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                    }
                }
            }
            
            ModernSettingsSection(title: "Database") {
                ModernSettingsRow(
                    title: "Database size",
                    description: "Current size of the task and email database"
                ) {
                    HStack(spacing: 8) {
                        Text(databaseSize)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        Button("Compact") {
                            compactDatabase()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                    }
                }
            }
            
            // Database Actions
            HStack {
                Button("Reset All Data") {
                    showingDatabaseResetAlert = true
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
                
                Spacer()
            }
            .padding(.vertical, 8)
            
            ModernSettingsSection(title: "Debugging") {
                ModernSettingsRow(
                    title: "Debug logging",
                    description: "Enable detailed logging for troubleshooting issues"
                ) {
                    Toggle("", isOn: $enableDebugLogging)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
                
                ModernSettingsRow(
                    title: "Crash reporting",
                    description: "Send anonymous crash reports to help improve the app"
                ) {
                    Toggle("", isOn: $enableCrashReporting)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
            }
            
            // Debug Actions
            HStack {
                Button("Export Logs") {
                    exportLogs()
                }
                .buttonStyle(.bordered)
                
                Button("Show Log Folder") {
                    showLogFolder()
                }
                .buttonStyle(.bordered)
                
                Spacer()
            }
            .padding(.vertical, 8)
            
            ModernSettingsSection(title: "Experimental") {
                ModernSettingsRow(
                    title: "Enable experimental features",
                    description: "⚠️ Enable beta features that may be unstable"
                ) {
                    Toggle("", isOn: $enableExperimentalFeatures)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
                
                if enableExperimentalFeatures {
                    ModernSettingsRow(
                        title: "⚠️ Warning",
                        description: "Experimental features may cause data loss or app crashes. Use with caution."
                    ) {
                        EmptyView()
                    }
                }
            }
            
            // Reset Actions
            HStack {
                Button("Reset All Settings") {
                    showingResetSettingsAlert = true
                }
                .buttonStyle(.bordered)
                .foregroundColor(.orange)
                
                Spacer()
            }
            .padding(.vertical, 8)
            
            Spacer()
        }
        .onAppear {
            calculateCacheSize()
            calculateDatabaseSize()
        }
        .alert("Clear Cache", isPresented: $showingClearCacheAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear Cache", role: .destructive) {
                clearCache()
            }
        } message: {
            Text("This will delete all cached email data and attachments. You'll need to reload emails from Gmail.")
        }
        .alert("Reset All Settings", isPresented: $showingResetSettingsAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset Settings", role: .destructive) {
                resetAllSettings()
            }
        } message: {
            Text("This will reset all app preferences to their default values. Your tasks and email data will not be affected.")
        }
        .alert("Reset All Data", isPresented: $showingDatabaseResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset Data", role: .destructive) {
                resetAllData()
            }
        } message: {
            Text("⚠️ This will permanently delete ALL your tasks, email data, and settings. This cannot be undone.")
        }
    }
    
    // MARK: - Helper Methods
    
    private func calculateCacheSize() {
        _Concurrency.Task {
            // Calculate cache size
            let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            let size = await calculateDirectorySize(cacheURL)
            
            await MainActor.run {
                cacheSize = ByteCountFormatter().string(fromByteCount: size)
            }
        }
    }
    
    private func calculateDatabaseSize() {
        _Concurrency.Task {
            // Calculate database size
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            let dbURL = appSupport?.appendingPathComponent("Diligence")
            let size = await calculateDirectorySize(dbURL)
            
            await MainActor.run {
                databaseSize = ByteCountFormatter().string(fromByteCount: size)
            }
        }
    }
    
    private func calculateDirectorySize(_ url: URL?) async -> Int64 {
        guard let url = url else { return 0 }
        
        do {
            let resourceKeys: [URLResourceKey] = [.fileSizeKey, .isDirectoryKey]
            let directoryContents = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: resourceKeys
            )
            
            var totalSize: Int64 = 0
            
            for fileURL in directoryContents {
                let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
                
                if resourceValues.isDirectory == true {
                    totalSize += await calculateDirectorySize(fileURL)
                } else {
                    totalSize += Int64(resourceValues.fileSize ?? 0)
                }
            }
            
            return totalSize
        } catch {
            return 0
        }
    }
    
    private func clearCache() {
        _Concurrency.Task {
            let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            
            if let cacheURL = cacheURL {
                do {
                    let contents = try FileManager.default.contentsOfDirectory(at: cacheURL, includingPropertiesForKeys: nil)
                    for url in contents {
                        try? FileManager.default.removeItem(at: url)
                    }
                } catch {
                    print("Error clearing cache: \(error)")
                }
            }
            
            await MainActor.run {
                calculateCacheSize()
            }
        }
    }
    
    private func compactDatabase() {
        // Implement database compaction
        _Concurrency.Task {
            // This would typically involve database-specific operations
            await MainActor.run {
                calculateDatabaseSize()
            }
        }
    }
    
    private func resetAllSettings() {
        // Reset all UserDefaults to defaults
        let domain = Bundle.main.bundleIdentifier!
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()
        
        // Reset local state
        enableDebugLogging = false
        enableCrashReporting = true
        maxEmailResults = 100
        cacheLifetime = 24
        enableExperimentalFeatures = false
    }
    
    private func resetAllData() {
        // This would reset the entire app database
        // Implementation would depend on your data storage approach
        resetAllSettings()
        clearCache()
    }
    
    private func exportLogs() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "Diligence-Logs-\(Date().formatted(date: .numeric, time: .omitted)).txt"
        
        savePanel.begin { result in
            if result == .OK, let url = savePanel.url {
                // Export logs to the selected location
                let logContent = "Diligence Debug Logs\n\nGenerated: \(Date())\n\n[Log content would be here]"
                try? logContent.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
    
    private func showLogFolder() {
        let logURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Logs")
            .appendingPathComponent("Diligence")
        
        if let logURL = logURL {
            NSWorkspace.shared.open(logURL)
        }
    }
}

// MARK: - Preview

#Preview {
    AdvancedSettingsView()
        .frame(width: 600, height: 500)
        .padding()
}
