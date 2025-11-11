//
//  AIEmailAssistantOverlay.swift
//  Diligence
//
//  AI Email Assistant Overlay for Email Detail View
//  Provides contextual AI assistance for individual emails with Apple Intelligence and Jan.ai support
//

import SwiftUI

struct AIEmailAssistantOverlay: View {
    let email: ProcessedEmail
    @ObservedObject var aiService: EnhancedAIEmailService
    
    @Binding var isVisible: Bool
    
    @State private var queryText: String = ""
    @State private var queryResponse: String = ""
    @State private var isLoading: Bool = false
    @State private var queryError: String? = nil
    @State private var showProviderPicker: Bool = false
    
    @FocusState private var isTextFieldFocused: Bool
    
    // Quick actions for this specific email
    private let quickActions = [
        ("Summarize", "Provide a concise summary of this email"),
        ("Action items", "Extract any action items or tasks from this email"),
        ("Key points", "What are the key points and important details?"),
        ("Response needed", "Does this email require a response or action from me?"),
        ("Categorize", "What type of email is this and how should I categorize it?")
    ]
    
    var body: some View {
        if isVisible {
            overlayContent
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
        }
    }
    
    private var overlayContent: some View {
        HStack(spacing: 0) {
            // Spacer to push overlay to the right
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isVisible = false
                    }
                }
            
            // Main overlay panel
            VStack(spacing: 0) {
                // Header
                overlayHeader
                
                Divider()
                
                // Content
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Provider selection (if expanded)
                        if showProviderPicker {
                            providerPickerSection
                        }
                        
                        // Response section
                        responseSection
                        
                        // Query input section
                        queryInputSection
                        
                        // Quick actions section
                        quickActionsSection
                        
                        // Email context section
                        emailContextSection
                    }
                    .padding()
                }
                
                Divider()
                
                // Footer with status
                overlayFooter
            }
            .frame(width: 400)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.1), radius: 10, x: -5, y: 0)
            .padding(.trailing, 20)
            .padding(.vertical, 20)
        }
        .onAppear {
            _Concurrency.Task {
                await aiService.refreshAvailability()
            }
        }
    }
    
    // MARK: - Header Section
    
    private var overlayHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.accentColor)
                        .font(.title2)
                    
                    Text("AI Email Assistant")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: aiService.selectedProvider.icon)
                            .font(.caption)
                        Text(aiService.selectedProvider.displayName)
                            .font(.caption)
                    }
                    .foregroundColor(aiService.currentServiceColor)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    
                    Text(aiService.currentServiceStatus)
                        .font(.caption)
                        .foregroundColor(aiService.currentServiceColor)
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                // Provider picker toggle
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showProviderPicker.toggle()
                    }
                }) {
                    Image(systemName: showProviderPicker ? "gearshape.fill" : "gearshape")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
                .help("AI Provider Settings")
                
                // Close button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isVisible = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title2)
                }
                .buttonStyle(.borderless)
                .help("Close Assistant")
            }
        }
        .padding()
    }
    
    // MARK: - Provider Picker Section
    
    private var providerPickerSection: some View {
        VStack(spacing: 8) {
            AIProviderPicker(aiService: aiService)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }
    
    // MARK: - Response Section
    
    @ViewBuilder
    private var responseSection: some View {
        if !queryResponse.isEmpty || queryError != nil {
            VStack(alignment: .leading, spacing: 8) {
                if let error = queryError {
                    errorResponseView(error: error)
                } else if !queryResponse.isEmpty {
                    successResponseView(response: queryResponse)
                }
            }
            .padding()
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
            )
        }
    }
    
    private func errorResponseView(error: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                
                Text("Analysis Failed")
                    .font(.headline)
                    .foregroundColor(.red)
                
                Spacer()
                
                Button("Dismiss") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        queryError = nil
                    }
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
            }
            
            Text(error)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
    
    private func successResponseView(response: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: aiService.selectedProvider == .appleIntelligence ? "apple.logo" : "brain.filled.head.profile")
                        .foregroundColor(.accentColor)
                    
                    Text("\(aiService.selectedProvider.displayName) Analysis")
                        .font(.headline)
                        .foregroundColor(.accentColor)
                }
                
                Spacer()
                
                Button("Clear") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        queryResponse = ""
                        queryError = nil
                    }
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
            }
            
            Text(response)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    // MARK: - Query Input Section
    
    private var queryInputSection: some View {
        VStack(spacing: 8) {
            HStack {
                TextField("Ask about this email...", text: $queryText)
                    .textFieldStyle(.roundedBorder)
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        submitQuery()
                    }
                    .disabled(isLoading || !aiService.hasAvailableService)
                
                Button(action: submitQuery) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: "paperplane.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || 
                         isLoading || !aiService.hasAvailableService)
            }
        }
    }
    
    // MARK: - Quick Actions Section
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Actions")
                .font(.headline)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ], spacing: 8) {
                ForEach(Array(quickActions.enumerated()), id: \.offset) { index, action in
                    Button(action: {
                        executeQuickAction(action.1)
                    }) {
                        Text(action.0)
                            .font(.caption)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.accentColor.opacity(0.1))
                            .foregroundColor(.accentColor)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help(action.1)
                    .disabled(isLoading || !aiService.hasAvailableService)
                }
            }
        }
    }
    
    // MARK: - Email Context Section
    
    private var emailContextSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Email Context")
                .font(.headline)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 6) {
                emailInfoRow(icon: "envelope", title: "Subject", value: email.subject)
                emailInfoRow(icon: "person", title: "From", value: email.sender)
                emailInfoRow(icon: "calendar", title: "Date", value: formatDate(email.receivedDate))
                
                if !email.attachments.isEmpty {
                    emailInfoRow(
                        icon: "paperclip", 
                        title: "Attachments", 
                        value: "\(email.attachments.count) file\(email.attachments.count > 1 ? "s" : "")"
                    )
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .cornerRadius(8)
        }
    }
    
    private func emailInfoRow(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .font(.caption)
                .frame(width: 16)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.caption)
                    .lineLimit(nil)
            }
            
            Spacer(minLength: 0)
        }
    }
    
    // MARK: - Footer Section
    
    private var overlayFooter: some View {
        HStack {
            Group {
                if !aiService.hasAvailableService {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No AI services available")
                            .font(.caption)
                            .foregroundColor(.orange)
                        
                        if !aiService.isAppleIntelligenceAvailable && !aiService.isJanAIAvailable {
                            Text("Enable Apple Intelligence or start Jan.ai server")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    HStack(spacing: 4) {
                        Text("Powered by")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 2) {
                            Image(systemName: aiService.selectedProvider.icon)
                            Text(aiService.selectedProvider.displayName)
                        }
                        .font(.caption)
                        .foregroundColor(aiService.currentServiceColor)
                        .fontWeight(.medium)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Helper Methods
    
    private func submitQuery() {
        let trimmedQuery = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty && !isLoading && aiService.hasAvailableService else { return }
        
        executeQuery(trimmedQuery)
    }
    
    private func executeQuickAction(_ query: String) {
        guard !isLoading && aiService.hasAvailableService else { return }
        executeQuery(query)
    }
    
    private func executeQuery(_ query: String) {
        queryError = nil
        queryResponse = ""
        isLoading = true
        
        // Clear any existing text field focus
        isTextFieldFocused = false
        
        _Concurrency.Task {
            do {
                // Use single email context for the query
                let response = try await aiService.queryEmails(query: query, emails: [email])
                
                await MainActor.run {
                    queryResponse = response
                    isLoading = false
                    queryText = "" // Clear input after successful query
                }
            } catch {
                await MainActor.run {
                    queryError = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Quick Query Button Component

struct QuickQueryButton: View {
    let title: String
    let query: String
    let action: (String) -> Void
    
    var body: some View {
        Button(title) {
            action(query)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .font(.caption)
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var isVisible = true
    let sampleEmail = ProcessedEmail(
        id: "sample123",
        threadId: "thread123",
        subject: "Important Project Update - Q4 Deadlines",
        sender: "Sarah Johnson",
        senderEmail: "sarah.johnson@company.com",
        body: """
        Hi Team,
        
        I wanted to provide an update on our Q4 project deadlines and deliverables. We have several critical milestones coming up:
        
        1. Final design review - Due October 30th
        2. Development completion - Due November 15th
        3. Testing phase - November 16th - December 1st
        4. Launch preparation - December 2nd - December 10th
        
        Please review your assigned tasks and let me know if you anticipate any blockers. We need to ensure we stay on track for the December launch.
        
        Best regards,
        Sarah
        """,
        snippet: "I wanted to provide an update on our Q4 project deadlines...",
        receivedDate: Date(),
        gmailURL: URL(string: "https://mail.google.com/mail/u/0/#inbox/sample123")!,
        attachments: [
            EmailAttachment(
                id: "att1",
                filename: "Q4-Timeline.pdf",
                mimeType: "application/pdf",
                size: 1048576,
                messageId: "sample123"
            )
        ]
    )
    
    ZStack {
        Color.gray.opacity(0.1)
            .ignoresSafeArea()
        
        Text("Email Detail View Background")
            .font(.title)
            .foregroundColor(.secondary)
        
        AIEmailAssistantOverlay(
            email: sampleEmail,
            aiService: EnhancedAIEmailService(),
            isVisible: $isVisible
        )
    }
}