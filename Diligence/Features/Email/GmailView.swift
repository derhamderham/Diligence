//
//  GmailView.swift
//  Diligence
//
//  Created by Michael Thomas Derham on 10/24/25.
//

import SwiftUI
import SwiftData
import AppKit

// MARK: - HTML to Attributed String Helper
extension String {
    func htmlToAttributedString() -> AttributedString {
        guard let data = self.data(using: .utf8) else {
            return AttributedString(self.formatPlainText())
        }
        
        do {
            let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ]
            
            let nsAttributedString = try NSAttributedString(
                data: data,
                options: options,
                documentAttributes: nil
            )
            
            // Convert to AttributedString with basic formatting
            return AttributedString(nsAttributedString)
            
        } catch {
            // If HTML parsing fails, return formatted plain text
            return AttributedString(self.formatPlainText())
        }
    }

}

// MARK: - Enhanced Text View for Email Content
struct RTFTextView: View {
    let htmlContent: String
    
    var body: some View {
        Group {
            if htmlContent.contains("<") && htmlContent.contains(">") {
                // HTML content
                Text(htmlContent.htmlToAttributedString())
                    .textSelection(.enabled)
                    .lineSpacing(4)
                    .foregroundColor(.primary)
            } else {
                // Plain text content - preserve line breaks and formatting
                Text(htmlContent.formatPlainText())
                    .textSelection(.enabled)
                    .lineSpacing(4)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Attachment Views
struct AttachmentView: View {
    let attachment: EmailAttachment
    let gmailService: GmailService
    
    @State private var isDownloading = false
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: attachment.systemIconName)
                .foregroundColor(.blue)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.filename)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(formatFileSize(attachment.size))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isDownloading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button("Open") {
                    downloadAndOpenAttachment()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
    }
    
    private func formatFileSize(_ size: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
    
    private func downloadAndOpenAttachment() {
        guard !isDownloading else { return }
        
        isDownloading = true
        
        _Concurrency.Task {
            if let fileURL = await gmailService.downloadAttachment(attachment) {
                await MainActor.run {
                    isDownloading = false
                    NSWorkspace.shared.open(fileURL)
                }
            } else {
                await MainActor.run {
                    isDownloading = false
                    // Could add error handling UI here
                    print("Failed to download attachment: \(attachment.filename)")
                }
            }
        }
    }
}

struct AttachmentsListView: View {
    let attachments: [EmailAttachment]
    let gmailService: GmailService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "paperclip")
                    .foregroundColor(.secondary)
                Text("Attachments (\(attachments.count))")
                    .font(.headline)
            }
            
            ForEach(attachments) { attachment in
                AttachmentView(attachment: attachment, gmailService: gmailService)
            }
        }
    }
}

struct GmailView: View {
    @StateObject private var gmailService = GmailService()
    @StateObject private var llmService: LLMService = .init()
    @State private var selectedEmail: ProcessedEmail?
    @State private var selectedEmails = Set<ProcessedEmail.ID>()
    @State private var triggerTaskCreation = false
    
    // Email query interface state
    @State private var queryText = ""
    @State private var queryResponse = ""
    @State private var isQueryLoading = false
    @State private var queryError: String?
    @State private var showQueryInterface = false
    
    // Diagnostic state
    @State private var showDiagnostics = false
    @State private var diagnosticResults = ""
    @State private var isRunningDiagnostics = false
    
    // AI Task Creation state
    @State private var showingAITaskSuggestions = false
    @State private var aiTaskSuggestions: [AITaskSuggestion] = []
    @State private var isGeneratingAITasks = false
    @State private var aiTaskError: String?
    @Query(sort: [SortDescriptor(\TaskSection.sortOrder)]) private var sections: [TaskSection]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dependencyContainer) private var container
    
    var body: some View {
        NavigationSplitView(sidebar: {
            mainSidebarContent
                .navigationSplitViewColumnWidth(min: 300, ideal: 400, max: 500)
        }, detail: {
            detailContent
        })
        .sheet(isPresented: $showingAITaskSuggestions) {
            if let email = selectedEmail {
                AITaskSuggestionsView(
                    email: email,
                    suggestions: aiTaskSuggestions,
                    availableSections: sections,
                    onTasksCreated: { tasks in
                        handleAITasksCreated(tasks)
                    },
                    onCancel: {
                        showingAITaskSuggestions = false
                        aiTaskSuggestions = []
                    }
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            handleAppBecameActive()
        }
        .onAppear {
            handleViewAppear()
        }
        .onChange(of: gmailService.isAuthenticated) { _, isAuthenticated in
            handleAuthenticationChange(isAuthenticated)
        }
    }
    
    // MARK: - Main Sidebar Content
    
    @ViewBuilder
    private var mainSidebarContent: some View {
        VStack {
            if !gmailService.isAuthenticated {
                authenticationView
            } else {
                authenticatedContentView
            }
            
            errorMessageView
            diagnosticsView
        }
    }
    
    // MARK: - Authentication View
    
    @ViewBuilder
    private var authenticationView: some View {
        VStack(spacing: 16) {
            Text("Connect to Gmail")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Sign in to your Gmail account to access your recent emails and create tasks from them.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button("Sign in to Gmail") {
                print("🔐 Starting OAuth flow...")
                gmailService.startOAuthFlow()
            }
            .buttonStyle(.borderedProminent)
            
            if let error = gmailService.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Authenticated Content
    
    @ViewBuilder
    private var authenticatedContentView: some View {
        VStack(spacing: 0) {
            emailListHeader
            Divider()
            emailListContent
            queryInterfaceView
        }
    }
    
    // MARK: - Email List Header
    
    @ViewBuilder
    private var emailListHeader: some View {
        HStack {
            headerLeftSection
            Spacer()
            headerRightSection
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    @ViewBuilder
    private var headerLeftSection: some View {
        HStack(spacing: 8) {
            Text("Recent Emails")
                .font(.title2)
                .fontWeight(.medium)
            
            // AI Email Query button
            if gmailService.isAuthenticated && UserDefaults.standard.llmFeatureEnabled {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showQueryInterface.toggle()
                    }
                }) {
                    Image(systemName: showQueryInterface ? "brain.filled.head.profile" : "brain.head.profile")
                        .foregroundColor(.accentColor)
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .help("AI Email Query")
            }
        }
    }
    
    @ViewBuilder
    private var headerRightSection: some View {
        HStack(spacing: 8) {
            // Remove Selected button
            if gmailService.isAuthenticated && !selectedEmails.isEmpty {
                Button("Remove (\(selectedEmails.count))") {
                    removeBatchEmails()
                }
                .foregroundColor(.red)
                .buttonStyle(.borderless)
            }
            
            refreshButton
        }
    }
    
    @ViewBuilder
    private var aiQueryButton: some View {
        if UserDefaults.standard.llmFeatureEnabled {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showQueryInterface.toggle()
                }
            }) {
                Image(systemName: showQueryInterface ? "brain.filled.head.profile" : "brain.head.profile")
                    .foregroundColor(.accentColor)
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .help("AI Email Query")
        }
    }
    
    @ViewBuilder
    private var selectionControls: some View {
        if !gmailService.emails.isEmpty {
            HStack(spacing: 8) {
                if selectedEmails.count > 0 {
                    Button("Clear Selection") {
                        selectedEmails.removeAll()
                        selectedEmail = nil
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
                
                Button(selectedEmails.count == gmailService.emails.count ? "Deselect All" : "Select All") {
                    toggleSelectAll()
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
        }
    }
    
    @ViewBuilder
    private var refreshButton: some View {
        Button(action: { 
            loadEmailsAsync(forceRefresh: true)
        }) {
            Image(systemName: "arrow.clockwise")
                .foregroundColor(.primary)
        }
        .buttonStyle(.borderless)
        .disabled(gmailService.isLoading)
    }
    
    // MARK: - Email List Content
    
    @ViewBuilder
    private var emailListContent: some View {
        if gmailService.isLoading {
            loadingView
        } else if gmailService.emails.isEmpty {
            emptyEmailsView
        } else {
            emailListView
        }
    }
    
    @ViewBuilder
    private var loadingView: some View {
        VStack {
            ProgressView()
                .controlSize(.regular)
            Text("Loading emails...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var emptyEmailsView: some View {
        VStack(spacing: 8) {
            Text("No emails found")
                .font(.title3)
                .foregroundColor(.secondary)
            
            Text("Try refreshing to load your recent emails")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var emailListView: some View {
        List(selection: $selectedEmails) {
            ForEach(gmailService.emails, id: \.id) { email in
                EmailRowView(
                    email: email,
                    isSelected: selectedEmails.contains(email.id),
                    onSelectionToggle: {
                        toggleEmailSelection(email)
                    }
                )
                .padding(.vertical, 4)
                .onTapGesture {
                    selectedEmail = email
                }
                .contextMenu {
                    emailContextMenu(for: email)
                }
                .tag(email.id)
            }
        }
        .listStyle(.sidebar)
        .animation(.easeInOut(duration: 0.2), value: gmailService.emails.count)
    }
    
    // MARK: - Query Interface
    
    @ViewBuilder
    private var queryInterfaceView: some View {
        if showQueryInterface && UserDefaults.standard.llmFeatureEnabled {
            EmailQueryInterface(
                queryText: $queryText,
                queryResponse: $queryResponse,
                isLoading: $isQueryLoading,
                queryError: $queryError,
                emails: gmailService.emails,
                llmService: llmService
            )
            .transition(AnyTransition.move(edge: .bottom).combined(with: .opacity))
        }
    }
    
    // MARK: - Error Message View
    
    @ViewBuilder
    private var errorMessageView: some View {
        if let errorMessage = gmailService.errorMessage {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Connection Issue")
                        .font(.headline)
                        .foregroundColor(.red)
                    
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                    
                    errorActionButton(for: errorMessage)
                }
                
                Spacer()
                
                Button("Dismiss") {
                    gmailService.errorMessage = nil
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
            }
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(8)
            .padding()
        }
    }
    
    @ViewBuilder
    private func errorActionButton(for errorMessage: String) -> some View {
        HStack(spacing: 8) {
            if errorMessage.contains("Session expired") || errorMessage.contains("Token refresh failed") {
                Button("Sign In Again") {
                    gmailService.signOut()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        gmailService.startOAuthFlow()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            } else {
                Button("Retry") {
                    loadEmailsAsync(forceRefresh: true)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            Button("Diagnostics") {
                runDiagnostics()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(isRunningDiagnostics)
        }
    }
    
    // MARK: - Diagnostics View
    
    @ViewBuilder
    private var diagnosticsView: some View {
        if showDiagnostics {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Gmail Connection Diagnostics")
                        .font(.headline)
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Button("Hide") {
                        showDiagnostics = false
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }
                
                if isRunningDiagnostics {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Running diagnostics...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if !diagnosticResults.isEmpty {
                    ScrollView {
                        Text(diagnosticResults)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 200)
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                    )
                    
                    HStack {
                        Button("Copy Results") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(diagnosticResults, forType: .string)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Spacer()
                        
                        Button("Run Again") {
                            runDiagnostics()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(isRunningDiagnostics)
                    }
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
            .padding()
        }
    }
    
    // MARK: - Context Menu
    
    @ViewBuilder
    private func emailContextMenu(for email: ProcessedEmail) -> some View {
        Button("AI Task") {
            generateAITaskSuggestions(for: email)
        }
        
        Button("Create Task") {
            showCreateTaskView(for: email)
        }
        
        Divider()
        
        Button("Select and View Email") {
            selectedEmail = email
        }
        
        Button("Open in Gmail") {
            if let url = URL(string: email.gmailURL.absoluteString) {
                NSWorkspace.shared.open(url)
            }
        }
        
        Divider()
        
        Button(selectedEmails.contains(email.id) ? "Deselect" : "Select") {
            toggleEmailSelection(email)
        }
        
        Button("Remove", role: .destructive) {
            removeEmailFromList(email)
        }
    }
    
    // MARK: - Detail Content
    
    @ViewBuilder
    private var detailContent: some View {
        if let selectedEmail = selectedEmail {
            EmailDetailView(
                email: selectedEmail, 
                onCreateTask: {
                    // Task creation now handled inline - no action needed
                }, 
                onEmailRemoved: {
                    handleEmailRemoved(selectedEmail)
                }, 
                gmailService: gmailService,
                triggerTaskCreation: $triggerTaskCreation,
                isGeneratingAITasks: $isGeneratingAITasks,
                aiTaskError: $aiTaskError,
                onGenerateAITasks: {
                    generateAITaskSuggestions(for: selectedEmail)
                }
            )
        } else {
            emptyDetailView
        }
    }
    
    @ViewBuilder
    private var emptyDetailView: some View {
        VStack {
            Text("Select an email")
                .font(.title2)
                .foregroundColor(.secondary)
            
            if gmailService.isAuthenticated && !gmailService.emails.isEmpty {
                Text("Choose an email from the list to view its details and create a task from it.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Helper Methods
    
    private func toggleSelectAll() {
        if selectedEmails.count == gmailService.emails.count {
            selectedEmails.removeAll()
            selectedEmail = nil
        } else {
            selectedEmails = Set(gmailService.emails.map { $0.id })
        }
    }
    
    private func handleAppBecameActive() {
        _Concurrency.Task {
            await gmailService.validateAndRefreshSession()
            
            if gmailService.isAuthenticated {
                await gmailService.loadRecentEmails()
            }
        }
    }
    
    private func handleViewAppear() {
        if gmailService.isAuthenticated {
            loadEmailsAsync()
        }
    }
    
    private func handleAuthenticationChange(_ isAuthenticated: Bool) {
        if isAuthenticated {
            loadEmailsAsync()
        }
    }
    
    // MARK: - AI Task Generation Methods
    
    /// Generate AI task suggestions for the given email
    private func generateAITaskSuggestions(for email: ProcessedEmail) {
        guard !isGeneratingAITasks else { return }
        
        isGeneratingAITasks = true
        aiTaskError = nil
        
        _Concurrency.Task { @MainActor in
            do {
                print("🤖 Starting AI task generation for email: \(email.subject)")
                
                // Use the shared AI service from DependencyContainer
                guard let aiService = container.enhancedAIService else {
                    throw NSError(domain: "GmailView", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "AI service not available. Please restart the app."
                    ])
                }
                
                let aiTaskService = AITaskService(aiService: aiService, gmailService: gmailService)
                print("🔗 Using shared Enhanced AI Email Service (already initialized at launch)")
                
                // Generate suggestions using the AI service
                let suggestions = try await aiTaskService.createAITaskSuggestions(
                    for: email,
                    availableSections: sections
                )
                
                print("✅ Generated \(suggestions.count) task suggestions")
                aiTaskSuggestions = suggestions
                isGeneratingAITasks = false
                
                // Show the suggestions view if we have any
                if !suggestions.isEmpty {
                    showingAITaskSuggestions = true
                } else {
                    aiTaskError = "No actionable tasks found in this email. The email may not contain specific tasks or action items."
                }
                
            } catch let error as AITaskError {
                isGeneratingAITasks = false
                let errorMessage = error.localizedDescription
                aiTaskError = errorMessage
                print("❌ AI task generation error: \(errorMessage)")
            } catch {
                isGeneratingAITasks = false
                aiTaskError = "Failed to generate task suggestions: \(error.localizedDescription)"
                print("❌ Unexpected error during AI task generation: \(error)")
            }
        }
    }
    
    /// Handle tasks created from AI suggestions
    private func handleAITasksCreated(_ tasks: [DiligenceTask]) {
        print("✅ Created \(tasks.count) tasks from AI suggestions")
        
        // Save to model context
        for task in tasks {
            modelContext.insert(task)
        }
        
        do {
            try modelContext.save()
            print("✅ Successfully saved \(tasks.count) tasks to database")
        } catch {
            print("❌ Failed to save tasks: \(error)")
            aiTaskError = "Failed to save tasks: \(error.localizedDescription)"
        }
        
        // Close the suggestions sheet
        showingAITaskSuggestions = false
        aiTaskSuggestions = []
        
        // Optionally show a success message or navigate to tasks
        // You could post a notification here to refresh the tasks list
        NotificationCenter.default.post(name: Notification.Name("TriggerRemindersSync"), object: nil)
    }
    
    private func loadEmailsAsync(forceRefresh: Bool = false) {
       _Concurrency.Task {
            // First validate and refresh session if needed
            await gmailService.validateAndRefreshSession()
            
            // If still authenticated after validation, load emails
            if gmailService.isAuthenticated {
                await gmailService.loadRecentEmails(forceRefresh: forceRefresh)
            }
        }
    }
    
    private func toggleEmailSelection(_ email: ProcessedEmail) {
        if selectedEmails.contains(email.id) {
            selectedEmails.remove(email.id)
            print("📱 Deselected email: \(email.subject)")
        } else {
            selectedEmails.insert(email.id)
            print("📱 Selected email: \(email.subject)")
        }
        print("📱 Total selected emails: \(selectedEmails.count)")
    }
    
    private func handleEmailRemoved(_ email: ProcessedEmail) {
        // Clear single selection since the email is being removed
        if selectedEmail?.id == email.id {
            selectedEmail = nil
        }
        
        // Remove from batch selection as well
        selectedEmails.remove(email.id)
    }
    
    private func removeEmailFromList(_ email: ProcessedEmail) {
        // If this email is currently selected, clear the selection
        if selectedEmail?.id == email.id {
            selectedEmail = nil
        }
        
        // Remove from batch selection as well
        selectedEmails.remove(email.id)
        
        gmailService.removeEmailFromList(email)
    }
    
    private func removeBatchEmails() {
        let emailIdsToRemove = selectedEmails
        let emailsToRemove = gmailService.emails.filter { emailIdsToRemove.contains($0.id) }
        
        print("🗑️ Attempting to remove \(emailIdsToRemove.count) selected emails")
        print("🗑️ Found \(emailsToRemove.count) emails to remove from service")
        
        // Clear single selection if it's being removed
        if let selectedEmail = selectedEmail, emailIdsToRemove.contains(selectedEmail.id) {
            self.selectedEmail = nil
        }
        
        // Remove all selected emails in one batch operation
        gmailService.removeBatchEmailsFromList(emailsToRemove)
        
        // Now clear batch selection after successful removal
        selectedEmails.removeAll()
        
        print("🗑️ Batch removal completed, selection cleared")
    }
    
    private func showCreateTaskView(for email: ProcessedEmail) {
        // Select the email to show in detail view
        selectedEmail = email
        
        // Trigger task creation in the detail view
        DispatchQueue.main.async {
            self.triggerTaskCreation = true
        }
    }
    
    private func runDiagnostics() {
        guard !isRunningDiagnostics else { return }
        
        isRunningDiagnostics = true
        showDiagnostics = true
        diagnosticResults = ""
        
        _Concurrency.Task {
            let results = await gmailService.runConnectivityDiagnostics()
            
            await MainActor.run {
                diagnosticResults = results
                isRunningDiagnostics = false
            }
        }
    }
}

struct EmailRowView: View {
    let email: ProcessedEmail
    let isSelected: Bool
    let onSelectionToggle: () -> Void
    
    // Pre-computed formatted strings to reduce view updates
    private let formattedTime: String
    private let formattedDate: String
    
    init(email: ProcessedEmail, isSelected: Bool, onSelectionToggle: @escaping () -> Void) {
        self.email = email
        self.isSelected = isSelected
        self.onSelectionToggle = onSelectionToggle
        
        // Pre-compute date strings to avoid formatter calls during view updates
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        self.formattedTime = timeFormatter.string(from: email.receivedDate)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd-MMM-yy"
        self.formattedDate = dateFormatter.string(from: email.receivedDate)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Checkbox for selection
            Button(action: onSelectionToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .help("Select email")
            
            // Email content
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(email.subject)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    Spacer(minLength: 8)
                    
                    HStack(spacing: 4) {
                        Text(formattedTime)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formattedDate)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .fixedSize()
                }
                
                Text("From: \(email.sender)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                Text(email.snippet)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
                
                // Attachment indicator
                if !email.attachments.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "paperclip")
                            .foregroundColor(.blue)
                            .font(.caption2)
                        
                        Text("\(email.attachments.count) attachment\(email.attachments.count > 1 ? "s" : "")")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                    .fixedSize()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(4)
        .contentShape(Rectangle()) // Improves tap handling
    }
}

struct EmailDetailView: View {
    let email: ProcessedEmail
    let onCreateTask: () -> Void
    let onEmailRemoved: () -> Void
    let gmailService: GmailService
    @Binding var triggerTaskCreation: Bool
    
    // AI Task state bindings
    @Binding var isGeneratingAITasks: Bool
    @Binding var aiTaskError: String?
    let onGenerateAITasks: () -> Void
    
    @Environment(\.modelContext) private var modelContext
    @State private var showTaskCreation = false
    @State private var taskTitle: String = ""
    @State private var taskDescription: String = ""
    @State private var dueDate: Date = Date().addingTimeInterval(86400) // Default to tomorrow
    @State private var hasDueDate: Bool = false
    
    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: email.receivedDate)
    }
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MMM-yy"
        return formatter.string(from: email.receivedDate)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Email header
                VStack(alignment: .leading, spacing: 8) {
                    Text(email.subject)
                        .font(.title)
                        .fontWeight(.medium)
                    
                    HStack {
                        Text("From: \(email.sender)")
                            .font(.subheadline)
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Text(formattedTime)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formattedDate)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                
                Divider()
                
                // Actions
                HStack(spacing: 16) {
                    // AI Task button
                    Button(action: {
                        onGenerateAITasks()
                    }) {
                        HStack(spacing: 6) {
                            if isGeneratingAITasks {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "brain.head.profile")
                            }
                            Text("AI Task")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isGeneratingAITasks)
                    .help("Generate intelligent task suggestions using AI")
                    
                    Button("Create Task") {
                        startTaskCreation()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Open in Gmail") {
                        NSWorkspace.shared.open(email.gmailURL)
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("Remove") {
                        removeEmail()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                }
                
                // AI Task error display
                aiTaskErrorView
                
                // Task Creation Section (moved here from bottom)
                if showTaskCreation {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Create Task")
                                .font(.title2)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Button("Cancel") {
                                cancelTaskCreation()
                            }
                            .buttonStyle(.borderless)
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Task Title")
                                    .font(.headline)
                                TextField("Enter task title", text: $taskTitle)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Description (optional)")
                                    .font(.headline)
                                TextEditor(text: $taskDescription)
                                    .frame(minHeight: 80, maxHeight: 120)
                                    .padding(4)
                                    .background(Color(NSColor.textBackgroundColor))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                                    )
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Toggle("Set Due Date", isOn: $hasDueDate)
                                    .toggleStyle(.switch)
                                
                                if hasDueDate {
                                    DatePicker("Due Date", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                                        .datePickerStyle(.field)
                                }
                            }
                        }
                        
                        HStack(spacing: 12) {
                            Button("Create Task") {
                                createTaskFromEmail()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            
                            Button("Cancel") {
                                cancelTaskCreation()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                    )
                }
                
                Divider()
                
                // Email body
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email Content")
                        .font(.headline)
                    
                    RTFTextView(htmlContent: email.body.isEmpty ? email.snippet : email.body)
                        .font(.body)
                        .padding(16)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                        )
                }
                
                // Attachments section
                if !email.attachments.isEmpty {
                    Divider()
                    
                    AttachmentsListView(attachments: email.attachments, gmailService: gmailService)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24) // Balanced horizontal padding
            .padding(.vertical, 16)   // Comfortable vertical padding
        }
        .navigationTitle("Email Details")
        .onAppear {
            // Pre-populate task title when view appears
            if taskTitle.isEmpty {
                taskTitle = email.subject
            }
        }
        .onChange(of: triggerTaskCreation) { _, shouldTrigger in
            if shouldTrigger {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showTaskCreation = true
                }
                triggerTaskCreation = false // Reset the trigger
                // Pre-populate task title
                if taskTitle.isEmpty {
                    taskTitle = email.subject
                }
            }
        }
    }
    
    // MARK: - AI Task Error Display
    
    @ViewBuilder
    private var aiTaskErrorView: some View {
        if let error = aiTaskError {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Task Generation Failed")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Dismiss") {
                    aiTaskError = nil
                }
                .buttonStyle(.borderless)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    
    private func startTaskCreation() {
        showTaskCreation = true
        // Pre-populate with email subject if not already set
        if taskTitle.isEmpty {
            taskTitle = email.subject
        }
    }
    
    private func cancelTaskCreation() {
        showTaskCreation = false
        taskTitle = email.subject // Reset to original
        taskDescription = ""
        hasDueDate = false
        dueDate = Date().addingTimeInterval(86400)
    }
    
    private func createTaskFromEmail() {
        let trimmedTitle = taskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        
        let newTask = Diligence.Task(
            title: trimmedTitle,
            taskDescription: taskDescription,
            isCompleted: false,
            createdDate: Date(),
            dueDate: hasDueDate ? dueDate : nil,
            emailID: email.id,
            emailSubject: email.subject,
            emailSender: email.sender,
            gmailURL: email.gmailURL.absoluteString
        )
        
        modelContext.insert(newTask)
        
        do {
            try modelContext.save()
            // Reset form and hide task creation
            showTaskCreation = false
            taskTitle = email.subject // Reset to original
            taskDescription = ""
            hasDueDate = false
            dueDate = Date().addingTimeInterval(86400)
        } catch {
            print("Failed to save task: \(error)")
        }
    }
    
    private func removeEmail() {
        gmailService.removeEmailFromList(email)
        onEmailRemoved()
    }
}

// MARK: - Email Query Interface

struct EmailQueryInterface: View {
    @Binding var queryText: String
    @Binding var queryResponse: String
    @Binding var isLoading: Bool
    @Binding var queryError: String?
    
    let emails: [ProcessedEmail]
    let llmService: LLMService
    
    @State private var isServiceAvailable: Bool? = nil
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            VStack(spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.accentColor)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("AI Email Assistant")
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        Text(serviceStatusText)
                            .font(.caption)
                            .foregroundColor(serviceStatusColor)
                    }
                    
                    Spacer()
                }
                
                // Response area (shown when there's a response or error)
                if !queryResponse.isEmpty || queryError != nil {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            if let error = queryError {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Query Failed")
                                            .font(.headline)
                                            .foregroundColor(.red)
                                        
                                        Text(error)
                                            .font(.body)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Button("Dismiss") {
                                        queryError = nil
                                    }
                                    .buttonStyle(.borderless)
                                    .controlSize(.small)
                                }
                            } else if !queryResponse.isEmpty {
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "brain.filled.head.profile")
                                        .foregroundColor(.accentColor)
                                        .font(.title3)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("AI Response")
                                            .font(.headline)
                                            .foregroundColor(.accentColor)
                                        
                                        Text(queryResponse)
                                            .font(.body)
                                            .textSelection(.enabled)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    
                                    Spacer()
                                    
                                    Button("Clear") {
                                        queryResponse = ""
                                        queryError = nil
                                    }
                                    .buttonStyle(.borderless)
                                    .controlSize(.small)
                                }
                            }
                        }
                        .padding()
                    }
                    .frame(maxHeight: 200)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                    )
                }
                
                // Query input area
                VStack(spacing: 8) {
                    HStack {
                        TextField("Ask about your emails (e.g., \"what invoices are due this week?\")", text: $queryText)
                            .textFieldStyle(.roundedBorder)
                            .focused($isTextFieldFocused)
                            .onSubmit {
                                submitQuery()
                            }
                            .disabled(isLoading || emails.isEmpty)
                        
                        Button(action: submitQuery) {
                            if isLoading {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "paperplane.fill")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                        .disabled(queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading || emails.isEmpty)
                    }
                    
                    // Quick action buttons
                    if !emails.isEmpty && queryResponse.isEmpty && queryError == nil {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                QuickQueryButton(title: "Recent invoices", query: "Show me any recent invoices or bills") {
                                    setQuery($0)
                                }
                                
                                QuickQueryButton(title: "Urgent emails", query: "Which emails seem urgent or require immediate action?") {
                                    setQuery($0)
                                }
                                
                                QuickQueryButton(title: "Meeting requests", query: "Find any meeting requests or calendar invites") {
                                    setQuery($0)
                                }
                                
                                QuickQueryButton(title: "From today", query: "Summarize emails from today") {
                                    setQuery($0)
                                }
                                
                                QuickQueryButton(title: "With attachments", query: "List emails that have attachments") {
                                    setQuery($0)
                                }
                            }
                            .padding(.horizontal, 1)
                        }
                    }
                }
                
                // Help text
                if emails.isEmpty {
                    Text("Load some emails first to start querying")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                } else if isServiceAvailable == false {
                    VStack(spacing: 4) {
                        Text("Jan.ai service not available")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text("Make sure Jan.ai is running on localhost:1337")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .multilineTextAlignment(.center)
                } else {
                    Text("Ask questions about your \(emails.count) loaded email\(emails.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        }
        .onAppear {
            checkServiceAvailability()
        }
    }
    
    private var serviceStatusText: String {
        guard let isAvailable = isServiceAvailable else {
            return "Checking connection..."
        }
        return isAvailable ? "Connected to Jan.ai" : "Jan.ai not available"
    }
    
    private var serviceStatusColor: Color {
        guard let isAvailable = isServiceAvailable else {
            return .secondary
        }
        return isAvailable ? .green : .orange
    }
    
    private func setQuery(_ query: String) {
        queryText = query
        isTextFieldFocused = true
    }
    
    private func submitQuery() {
        let trimmedQuery = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty && !emails.isEmpty && !isLoading else { return }
        
        queryError = nil
        queryResponse = ""
        isLoading = true
        
        _Concurrency.Task {
            do {
                let response = try await llmService.queryEmails(query: trimmedQuery, emails: emails)
                
                await MainActor.run {
                    queryResponse = response
                    isLoading = false
                    queryText = "" // Clear the input after successful query
                }
            } catch {
                await MainActor.run {
                    queryError = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
    
    private func checkServiceAvailability() {
        _Concurrency.Task {
            let available = await llmService.checkServiceAvailability()
            await MainActor.run {
                isServiceAvailable = available
            }
        }
    }
}



#Preview {
    GmailView()
}
