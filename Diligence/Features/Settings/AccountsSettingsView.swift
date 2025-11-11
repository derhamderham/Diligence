//
//  AccountsSettingsView.swift
//  Diligence
//
//  Account integrations and authentication settings
//

import SwiftUI
import AppKit
import Combine

struct AccountsSettingsView: View {
    @StateObject private var gmailService = GmailService()
    @StateObject private var remindersService = RemindersService()
    
    @State private var showingSignOutAlert = false
    @State private var showingRemindersResetAlert = false
    @State private var diagnosticResults = ""
    
    var body: some View {
        Form {
            gmailSection
            remindersSection
            calendarSection
        }
        .formStyle(.grouped)
        .navigationTitle("Accounts")
        .frame(minWidth: 400, minHeight: 400)
        .alert("Sign Out of Gmail", isPresented: $showingSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                gmailService.signOut()
            }
        } message: {
            Text("This will remove access to your Gmail account. You'll need to sign in again to import emails.")
        }
        .alert("Reset Reminders Authorization", isPresented: $showingRemindersResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                remindersService.resetAuthorization()
            }
        } message: {
            Text("This will reset Reminders authorization. You'll need to grant permission again to continue syncing tasks.")
        }
    }
    
    // MARK: - Section Views
    
    private var gmailSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                gmailHeader
                
                if gmailService.isAuthenticated {
                    gmailAccountInfo
                }
                
                gmailActionButtons
            }
        } header: {
            Label("Gmail", systemImage: "envelope")
        }
    }
    
    private var gmailHeader: some View {
        HStack {
            Image(systemName: "envelope.circle.fill")
                .font(.title2)
                .foregroundColor(gmailService.isAuthenticated ? .green : .orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Gmail Integration")
                    .font(.headline)
                
                Text(gmailService.isAuthenticated ?
                    "Connected and ready to import emails" :
                    "Connect to Gmail to import emails and create tasks")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            ConnectionStatusIndicator(
                isConnected: gmailService.isAuthenticated,
                connectedText: "Connected",
                disconnectedText: "Not Connected"
            )
        }
    }
    
    private var gmailAccountInfo: some View {
        HStack {
            Text("Account:")
                .foregroundColor(.secondary)
            
            Text(gmailService.userEmail ?? "Loading...")
                .fontWeight(.medium)
            
            Spacer()
        }
        .font(.subheadline)
    }
    
    private var gmailActionButtons: some View {
        VStack(spacing: 8) {
            HStack {
                Spacer()
                
                if gmailService.isAuthenticated {
                    Button("Sign Out", role: .destructive) {
                        showingSignOutAlert = true
                    }
                    .controlSize(.regular)
                } else {
                    Button("Sign In to Gmail") {
                        gmailService.startOAuthFlow()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
                
                // Add diagnostic button for troubleshooting
                Button("Run Diagnostics") {
                    runGmailDiagnostics()
                }
                .controlSize(.regular)
                .help("Check Gmail connectivity and configuration")
            }
            
            // Show diagnostic results
            if !diagnosticResults.isEmpty {
                ScrollView {
                    Text(diagnosticResults)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(4)
                }
                .frame(height: 200)
            }
        }
    }
    
    private var remindersSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                remindersHeader
                
                if !remindersService.isAuthorized {
                    remindersInfoMessage
                }
                
                remindersActionButtons
            }
        } header: {
            Label("Reminders", systemImage: "list.bullet")
        }
    }
    
    private var remindersHeader: some View {
        HStack {
            Image(systemName: "list.bullet.circle.fill")
                .font(.title2)
                .foregroundColor(remindersService.isAuthorized ? .green : 
                                (remindersService.syncStatus == .reconnecting ? .blue : .orange))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Reminders Integration")
                    .font(.headline)
                
                Text(getRemindersStatusText())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            ConnectionStatusIndicator(
                isConnected: remindersService.isAuthorized,
                connectedText: "Authorized",
                disconnectedText: getRemindersConnectionStatus(),
                isReconnecting: remindersService.syncStatus == .reconnecting
            )
        }
    }
    
    private var remindersInfoMessage: some View {
        HStack {
            Image(systemName: "info.circle")
                .foregroundColor(.orange)
            
            Text("Diligence needs permission to sync tasks with the Reminders app")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var remindersActionButtons: some View {
        HStack {
            if remindersService.isAuthorized {
                Button("Test Sync") {
                    remindersService.testSync()
                }
                .controlSize(.regular)
                
                Spacer()
                
                Button("Reset Authorization", role: .destructive) {
                    showingRemindersResetAlert = true
                }
                .controlSize(.regular)
            } else {
                Spacer()
                
                Button("Grant Access") {
                    remindersService.requestAccess()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
        }
    }
    
    private var calendarSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "calendar.circle")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Calendar Integration")
                            .font(.headline)
                        
                        Text("Sync task due dates with system Calendar")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("Coming Soon")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary)
                        .foregroundColor(.secondary)
                        .cornerRadius(8)
                }
            }
        } header: {
            Label("Calendar", systemImage: "calendar")
        }
    }
    
    // MARK: - Helper Methods
    
    private func getRemindersStatusText() -> String {
        switch remindersService.syncStatus {
        case .reconnecting:
            return "Reconnecting to Reminders service..."
        case .syncing:
            return "Syncing with Reminders..."
        case .error(let message):
            return message
        default:
            return remindersService.isAuthorized ?
                "Syncing tasks with system Reminders" :
                "Grant access to sync tasks with the Reminders app"
        }
    }
    
    private func getRemindersConnectionStatus() -> String {
        switch remindersService.syncStatus {
        case .reconnecting:
            return "Reconnecting"
        case .error(_):
            return "Error"
        default:
            return "Access Needed"
        }
    }
    
    // MARK: - Helper Functions
    
    private func runGmailDiagnostics() {
        diagnosticResults = "Running diagnostics..."
        
        _Concurrency.Task {
            let results = await gmailService.runConnectivityDiagnostics()
            await MainActor.run {
                diagnosticResults = results
            }
        }
    }
}

// MARK: - Supporting Views

struct ConnectionStatusIndicator: View {
    let isConnected: Bool
    let connectedText: String
    let disconnectedText: String
    let isReconnecting: Bool
    
    init(isConnected: Bool, connectedText: String, disconnectedText: String, isReconnecting: Bool = false) {
        self.isConnected = isConnected
        self.connectedText = connectedText
        self.disconnectedText = disconnectedText
        self.isReconnecting = isReconnecting
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Group {
                if isReconnecting {
                    // Animated reconnecting indicator
                    Circle()
                        .fill(.blue)
                        .frame(width: 8, height: 8)
                        .opacity(0.3)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isReconnecting)
                        .scaleEffect(isReconnecting ? 1.2 : 1.0)
                } else {
                    Circle()
                        .fill(isConnected ? .green : .orange)
                        .frame(width: 8, height: 8)
                }
            }
            
            Text(isReconnecting ? "Reconnecting" : (isConnected ? connectedText : disconnectedText))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isReconnecting ? .blue : (isConnected ? .green : .orange))
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AccountsSettingsView()
    }
    .frame(width: 600, height: 500)
}
