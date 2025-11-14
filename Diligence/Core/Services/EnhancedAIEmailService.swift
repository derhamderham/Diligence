//
//  EnhancedAIEmailService.swift
//  Diligence
//
//  Enhanced AI Email Assistant supporting both Apple Intelligence and Jan.ai
//

import Foundation
import SwiftUI
import FoundationModels
import Combine

@MainActor
class EnhancedAIEmailService: ObservableObject {
    
    // MARK: - AI Service Selection
    
    public enum AIProvider: String, CaseIterable {
        case appleIntelligence = "apple"
        case janAI = "jan"
        
        public var id: Self { self }
        
        public var displayName: String {
            switch self {
            case .appleIntelligence:
                return "Apple Intelligence"
            case .janAI:
                return "Jan.ai (Local)"
            }
        }
        
        public var icon: String {
            switch self {
            case .appleIntelligence:
                return "apple.logo"
            case .janAI:
                return "server.rack"
            }
        }
        
        public var description: String {
            switch self {
            case .appleIntelligence:
                return "On-device Apple Intelligence (Private & Fast)"
            case .janAI:
                return "Local Jan.ai server (Customizable)"
            }
        }
    }
    
    // MARK: - Services
    
    private let appleIntelligenceService = AppleIntelligenceService()
    private let janAIService = LLMService()
    
    // MARK: - Published Properties
    
    @Published var selectedProvider: AIProvider {
        didSet {
            UserDefaults.standard.set(selectedProvider.rawValue, forKey: "AIEmailProvider")
            UserDefaults.standard.set(true, forKey: "llmFeatureEnabled")
        }
    }
    
    @Published var isAppleIntelligenceAvailable = false
    @Published var isJanAIAvailable = false
    @Published var isInitializing = true
    
    // MARK: - Computed Properties
    
    var availableProviders: [AIProvider] {
        return AIProvider.allCases.filter { provider in
            switch provider {
            case .appleIntelligence:
                return isAppleIntelligenceAvailable
            case .janAI:
                return isJanAIAvailable
            }
        }
    }
    
    var currentServiceStatus: String {
        switch selectedProvider {
        case .appleIntelligence:
            return appleIntelligenceService.status.displayText
        case .janAI:
            return isJanAIAvailable ? "Jan.ai connected" : "Jan.ai not available"
        }
    }
    
    var currentServiceColor: Color {
        switch selectedProvider {
        case .appleIntelligence:
            return Color(appleIntelligenceService.status.color)
        case .janAI:
            return isJanAIAvailable ? .green : .orange
        }
    }
    
    var hasAvailableService: Bool {
        return !availableProviders.isEmpty
    }
    
    // MARK: - Initialization
    
    init() {
        // Load saved provider preference
        let savedProvider = UserDefaults.standard.string(forKey: "AIEmailProvider") ?? AIProvider.appleIntelligence.rawValue
        self.selectedProvider = AIProvider(rawValue: savedProvider) ?? .appleIntelligence
    }
    
    func initialize() async {
        print("🤖 Initializing Enhanced AI Email Service...")
        isInitializing = true
        
        // Initialize both services concurrently
        async let appleInit: () = appleIntelligenceService.initialize()
        async let janInit: () = janAIService.initialize()
        
        await appleInit
        await janInit
        
        // Check availability
        isAppleIntelligenceAvailable = await appleIntelligenceService.checkAvailability()
        isJanAIAvailable = await janAIService.checkServiceAvailability()
        
        // Warm up the selected provider to ensure it's truly ready
        // This prevents the "no response on first click" issue
        await warmUpServices()
        
        // Auto-select best available provider
        if !availableProviders.contains(selectedProvider) {
            if let firstAvailable = availableProviders.first {
                selectedProvider = firstAvailable
                print("🤖 Auto-selected available provider: \(selectedProvider.displayName)")
            }
        }
        
        isInitializing = false
        
        print("🤖 Enhanced AI Email Service initialized")
        print("🤖 Apple Intelligence: \(isAppleIntelligenceAvailable ? "✅" : "❌")")
        print("🤖 Jan.ai: \(isJanAIAvailable ? "✅" : "❌")")
        print("🤖 Selected provider: \(selectedProvider.displayName)")
    }
    
    /// Warm up AI services with a minimal test request to ensure they're truly ready
    /// This prevents the "no response on first request" issue
    private func warmUpServices() async {
        print("🔥 Warming up AI services...")
        
        // Warm up Apple Intelligence if available
        if isAppleIntelligenceAvailable {
            do {
                print("🔥 Warming up Apple Intelligence...")
                // Create a minimal test session to initialize the language model
                let testSession = LanguageModelSession(instructions: "You are a helpful assistant.")
                _ = try await testSession.respond(to: "Hi")
                print("✅ Apple Intelligence warmed up successfully")
            } catch {
                print("⚠️ Apple Intelligence warm-up failed (non-critical): \(error.localizedDescription)")
                // Don't mark as unavailable - it might still work for actual requests
            }
        }
        
        // Warm up Jan.ai if available
        if isJanAIAvailable {
            do {
                print("🔥 Warming up Jan.ai...")
                // Make a minimal test request to ensure the connection is established
                // This also ensures the model is loaded
                try await janAIService.warmUp()
                print("✅ Jan.ai warmed up successfully")
            } catch {
                print("⚠️ Jan.ai warm-up failed (non-critical): \(error.localizedDescription)")
                // Don't mark as unavailable - it might still work for actual requests
            }
        }
    }
                print("⚠️ Jan.ai warm-up failed (non-critical): \(error.localizedDescription)")
                // Don't mark as unavailable - it might still work for actual requests
            }
        }
    }
    
    // MARK: - Email Querying
    
    /// Query emails using the selected AI provider
    func queryEmails(query: String, emails: [ProcessedEmail]) async throws -> String {
        switch selectedProvider {
        case .appleIntelligence:
            guard isAppleIntelligenceAvailable else {
                throw EnhancedAIError.serviceUnavailable("Apple Intelligence is not available")
            }
            // Try progressively smaller datasets until it works
            return try await queryAppleIntelligenceWithFallback(query: query, emails: emails)
            
        case .janAI:
            guard isJanAIAvailable else {
                throw EnhancedAIError.serviceUnavailable("Jan.ai service is not available")
            }
            return try await janAIService.queryEmails(query: query, emails: emails)
        }
    }
    
    /// Query Apple Intelligence with proper context window management
    private func queryAppleIntelligenceWithFallback(query: String, emails: [ProcessedEmail]) async throws -> String {
        // Use the improved AppleIntelligenceService which now handles context window management internally
        return try await appleIntelligenceService.queryEmails(query: query, emails: emails)
    }
    
    /// Check service availability
    func checkServiceAvailability() async -> Bool {
        switch selectedProvider {
        case .appleIntelligence:
            return await appleIntelligenceService.checkAvailability()
        case .janAI:
            return await janAIService.checkServiceAvailability()
        }
    }
    
    /// Refresh service availability
    func refreshAvailability() async {
        isAppleIntelligenceAvailable = await appleIntelligenceService.checkAvailability()
        isJanAIAvailable = await janAIService.checkServiceAvailability()
    }
    
    // MARK: - Advanced Features (Apple Intelligence Only)
    
    /// Generate structured email insights (Apple Intelligence only)
    func generateEmailInsights(emails: [ProcessedEmail]) async throws -> EmailInsights {
        guard isAppleIntelligenceAvailable else {
            throw EnhancedAIError.featureUnavailable("Email insights require Apple Intelligence")
        }
        return try await appleIntelligenceService.generateEmailInsights(emails: emails)
    }
    
    /// Extract action items from emails (Apple Intelligence only)
    func extractActionItems(from emails: [ProcessedEmail]) async throws -> [ActionItem] {
        guard isAppleIntelligenceAvailable else {
            throw EnhancedAIError.featureUnavailable("Action item extraction requires Apple Intelligence")
        }
        return try await appleIntelligenceService.extractActionItems(from: emails)
    }
    
    /// Categorize an email (Apple Intelligence only)
    func categorizeEmail(_ email: ProcessedEmail) async throws -> EmailCategory {
        guard isAppleIntelligenceAvailable else {
            throw EnhancedAIError.featureUnavailable("Email categorization requires Apple Intelligence")
        }
        return try await appleIntelligenceService.categorizeEmail(email)
    }
    
    /// Summarize an email (Apple Intelligence only)
    func summarizeEmail(_ email: ProcessedEmail) async throws -> String {
        guard isAppleIntelligenceAvailable else {
            throw EnhancedAIError.featureUnavailable("Email summarization requires Apple Intelligence")
        }
        return try await appleIntelligenceService.summarizeEmail(email)
    }
    
    // MARK: - Provider Management
    
    func switchProvider(_ provider: AIProvider) {
        guard availableProviders.contains(provider) else {
            print("⚠️ Provider \(provider.displayName) is not currently available")
            print("   Tip: Make sure Jan.ai server is running or Apple Intelligence is enabled")
            return
        }
        selectedProvider = provider
        print("🔄 Switched to \(provider.displayName)")
    }
    
    /// Force switch to a provider even if not currently available (useful for settings)
    func forceSwitchProvider(_ provider: AIProvider) {
        selectedProvider = provider
        print("🔄 Force-switched to \(provider.displayName)")
    }
    
    // MARK: - Error Handling
    
    enum EnhancedAIError: Error, LocalizedError {
        case serviceUnavailable(String)
        case featureUnavailable(String)
        case noProvidersAvailable
        
        var errorDescription: String? {
            switch self {
            case .serviceUnavailable(let message):
                return message
            case .featureUnavailable(let message):
                return message
            case .noProvidersAvailable:
                return "No AI providers are currently available"
            }
        }
    }
}

// MARK: - SwiftUI Integration
// AIProviderPicker moved to separate AIProviderPicker.swift file

struct EnhancedEmailQueryInterface: View {
    @Binding var queryText: String
    @Binding var queryResponse: String
    @Binding var isLoading: Bool
    @Binding var queryError: String?
    
    let emails: [ProcessedEmail]
    @ObservedObject var aiService: EnhancedAIEmailService
    
    @FocusState private var isTextFieldFocused: Bool
    @State private var showProviderPicker = false
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            VStack(spacing: 12) {
                // Header with provider selection
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.accentColor)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("AI Email Assistant")
                            .font(.headline)
                            .fontWeight(.medium)
                        
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
                    
                    // Provider picker button
                    Button(action: {
                        showProviderPicker.toggle()
                    }) {
                        Image(systemName: "gearshape")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("Change AI provider")
                }
                
                // Provider picker (shown when toggled)
                if showProviderPicker {
                    AIProviderPicker(aiService: aiService)
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                        .transition(.opacity.combined(with: .scale))
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
                                    Image(systemName: aiService.selectedProvider == .appleIntelligence ? "apple.logo" : "brain.filled.head.profile")
                                        .foregroundColor(.accentColor)
                                        .font(.title3)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text("\(aiService.selectedProvider.displayName) Response")
                                                .font(.headline)
                                                .foregroundColor(.accentColor)
                                            
                                            Spacer()
                                        }
                                        
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
                        TextField("Ask about your emails...", text: $queryText)
                            .textFieldStyle(.roundedBorder)
                            .focused($isTextFieldFocused)
                            .onSubmit {
                                submitQuery()
                            }
                            .disabled(isLoading || emails.isEmpty || !aiService.hasAvailableService)
                        
                        Button(action: submitQuery) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(0.8)
                                    .frame(width: 16, height: 16, alignment: .center)
                                    .fixedSize()
                                    .fixedSize()
                            } else {
                                Image(systemName: "paperplane.fill")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                        .disabled(queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || 
                                 isLoading || emails.isEmpty || !aiService.hasAvailableService)
                    }
                    
                    // Quick action buttons
                    if !emails.isEmpty && queryResponse.isEmpty && queryError == nil && !showProviderPicker {
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
                                
                                if aiService.selectedProvider == .appleIntelligence && aiService.isAppleIntelligenceAvailable {
                                    QuickQueryButton(title: "Extract actions", query: "Extract any action items from my emails") {
                                        setQuery($0)
                                    }
                                }
                            }
                            .padding(.horizontal, 1)
                        }
                    }
                }
                
                // Status and help text
                Group {
                    if emails.isEmpty {
                        Text("Load some emails first to start querying")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    } else if !aiService.hasAvailableService {
                        VStack(spacing: 4) {
                            Text("No AI services available")
                                .font(.caption)
                                .foregroundColor(.orange)
                            
                            if !aiService.isAppleIntelligenceAvailable && !aiService.isJanAIAvailable {
                                Text("Enable Apple Intelligence in Settings or start Jan.ai server")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
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
                            
                            Text("• \(emails.count) emails loaded")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        }
        .animation(.easeInOut(duration: 0.2), value: showProviderPicker)
        .onAppear {
            _Concurrency.Task {
                await aiService.refreshAvailability()
            }
        }
    }
    private func setQuery(_ query: String) {
        queryText = query
        isTextFieldFocused = true
    }
    
    private func submitQuery() {
        let trimmedQuery = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty && !emails.isEmpty && !isLoading && aiService.hasAvailableService else { return }
        
        queryError = nil
        queryResponse = ""
        isLoading = true
        
        _Concurrency.Task {
            do {
                let response = try await aiService.queryEmails(query: trimmedQuery, emails: emails)
                
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
}

// MARK: - Supporting Views

struct AIProviderPicker: View {
    @ObservedObject var aiService: EnhancedAIEmailService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI Provider")
                .font(.headline)
                .foregroundColor(.primary)
            
            if aiService.availableProviders.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundColor(.orange)
                    
                    Text("No AI providers available")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Enable Apple Intelligence in System Settings or start a Jan.ai server")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                VStack(spacing: 8) {
                    ForEach(EnhancedAIEmailService.AIProvider.allCases, id: \.self) { provider in
                        let isAvailable = aiService.availableProviders.contains(provider)
                        let isSelected = aiService.selectedProvider == provider
                        
                        Button(action: {
                            if isAvailable {
                                aiService.switchProvider(provider)
                            }
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: provider.icon)
                                    .font(.title3)
                                    .foregroundColor(isAvailable ? .accentColor : .secondary)
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(provider.displayName)
                                        .font(.body)
                                        .fontWeight(isSelected ? .semibold : .regular)
                                        .foregroundColor(isAvailable ? .primary : .secondary)
                                    
                                    Text(provider.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if isAvailable {
                                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(isSelected ? .accentColor : .secondary)
                                } else {
                                    Text("Unavailable")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.secondary.opacity(0.1))
                                        .cornerRadius(4)
                                }
                            }
                            .padding(.all, 12)
                            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(!isAvailable)
                    }
                }
            }
        }
    }
}

// MARK: - UserDefaults Extension

extension UserDefaults {
    private enum Keys {
        static let aiEmailProvider = "AIEmailProvider"
    }
    
    var selectedAIProvider: EnhancedAIEmailService.AIProvider {
        get {
            let rawValue = string(forKey: Keys.aiEmailProvider) ?? EnhancedAIEmailService.AIProvider.appleIntelligence.rawValue
            return EnhancedAIEmailService.AIProvider(rawValue: rawValue) ?? .appleIntelligence
        }
        set {
            set(newValue.rawValue, forKey: Keys.aiEmailProvider)
        }
    }
}
