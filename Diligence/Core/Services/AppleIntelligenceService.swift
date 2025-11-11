//
//  AppleIntelligenceService.swift
//  Diligence
//
//  Integration with Apple's on-device Foundation Models
//

import Foundation
import Combine
import FoundationModels
import AppKit

@MainActor
class AppleIntelligenceService: ObservableObject {
    
    // MARK: - Properties
    
    private var languageModelSession: LanguageModelSession?
    private let systemLanguageModel = SystemLanguageModel.default
    
    @Published var isAvailable = false
    @Published var status = ModelStatus.checking
    
    enum ModelStatus {
        case checking
        case available
        case unavailable(SystemLanguageModel.Availability.UnavailableReason)
        
        var displayText: String {
            switch self {
            case .checking:
                return "Checking availability..."
            case .available:
                return "Apple Intelligence ready"
            case .unavailable(let reason):
                return reason.displayText
            }
        }
        
        var color: NSColor {
            switch self {
            case .checking:
                return .secondaryLabelColor
            case .available:
                return .systemGreen
            case .unavailable:
                return .systemOrange
            }
        }
    }
    
    // MARK: - Error Handling
    
    enum AppleIntelligenceError: Error, LocalizedError {
        case modelNotAvailable(SystemLanguageModel.Availability.UnavailableReason)
        case sessionCreationFailed
        case noResponse
        case invalidResponse
        case contextWindowExceeded
        case maxRetriesExceeded
        
        var errorDescription: String? {
            switch self {
            case .modelNotAvailable(let reason):
                return reason.displayText
            case .sessionCreationFailed:
                return "Failed to create language model session"
            case .noResponse:
                return "No response from Apple Intelligence"
            case .invalidResponse:
                return "Invalid response format from Apple Intelligence"
            case .contextWindowExceeded:
                return "Content too large for Apple Intelligence context window (4096 tokens)"
            case .maxRetriesExceeded:
                return "Exceeded maximum retry attempts for context window management"
            }
        }
    }
    
    // MARK: - Initialization
    
    func initialize() async {
        await checkModelAvailability()
    }
    
    private func checkModelAvailability() async {
        switch systemLanguageModel.availability {
        case .available:
            status = .available
            isAvailable = true
            print("✅ Apple Intelligence is available")
            
        case .unavailable(let reason):
            status = .unavailable(reason)
            isAvailable = false
            print("⚠️ Apple Intelligence unavailable: \(reason.displayText)")
        }
    }
    
    // MARK: - Email Querying
    
    /// Query emails using Apple Intelligence Foundation Models with proper context window management
    func queryEmails(query: String, emails: [ProcessedEmail]) async throws -> String {
        print("🧠 Starting Apple Intelligence email query")
        
        // Check availability
        guard isAvailable else {
            if case .unavailable(let reason) = systemLanguageModel.availability {
                throw AppleIntelligenceError.modelNotAvailable(reason)
            } else {
                throw AppleIntelligenceError.sessionCreationFailed
            }
        }
        
        // Detect if this is a task creation request
        if query.contains("JSON FORMAT") || query.contains("actionable tasks") || query.contains("Create actionable") || query.contains("Return ONLY") {
            return try await generateStructuredTaskResponse(query: query, emails: emails)
        } else {
            // Try with progressive content reduction strategies for general queries
            return try await queryWithContextWindowManagement(query: query, emails: emails)
        }
    }
    
    /// Generate structured task response using Apple Intelligence
    private func generateStructuredTaskResponse(query: String, emails: [ProcessedEmail]) async throws -> String {
        return try await generateTasksWithContextManagement(query: query, emails: emails)
    }
    
    /// Generate tasks with context window management
    private func generateTasksWithContextManagement(query: String, emails: [ProcessedEmail], retryCount: Int = 0) async throws -> String {
        let strategies = [
            ContextStrategy(name: "Standard", maxEmails: 1, maxCharsPerEmail: 600, useFullInstructions: false),
            ContextStrategy(name: "Reduced", maxEmails: 1, maxCharsPerEmail: 400, useFullInstructions: false),
            ContextStrategy(name: "Minimal", maxEmails: 1, maxCharsPerEmail: 250, useFullInstructions: false)
        ]
        
        guard retryCount < strategies.count else {
            throw AppleIntelligenceError.maxRetriesExceeded
        }
        
        let strategy = strategies[retryCount]
        print("🧠 Task generation attempt \(retryCount + 1) using '\(strategy.name)' strategy")
        
        do {
            // Create very minimal instructions for task generation
            let instructions = "You generate JSON task lists from emails. Respond only with valid JSON."
            
            // Prepare single email context
            let emailContext = prepareSingleEmailContext(
                emails.first ?? emails[0], 
                maxChars: strategy.maxCharsPerEmail
            )
            
            // Create optimized task prompt
            let prompt = buildOptimizedTaskPrompt(query: query, emailContext: emailContext)
            
            // Create new session for this attempt
            let session = LanguageModelSession(instructions: instructions)
            
            print("🧠 Sending task query with \(strategy.name) strategy...")
            let response = try await session.respond(to: prompt)
            print("✅ Apple Intelligence task generation succeeded with \(strategy.name) strategy")
            
            return response.content
            
        } catch let error as LanguageModelSession.GenerationError {
            print("❌ Task strategy '\(strategy.name)' failed: \(error)")
            
            if case .exceededContextWindowSize = error {
                print("📏 Context window exceeded, trying with reduced content...")
                return try await generateTasksWithContextManagement(
                    query: query,
                    emails: emails,
                    retryCount: retryCount + 1
                )
            } else {
                throw error
            }
        } catch {
            print("❌ Unexpected error in task strategy '\(strategy.name)': \(error)")
            throw error
        }
    }
    
    /// Prepare single email context for task generation
    private func prepareSingleEmailContext(_ email: ProcessedEmail, maxChars: Int) -> String {
        let bodyText = truncateEmailContent(email, maxChars: maxChars)
        
        return """
        Subject: \(truncateText(email.subject, maxLength: 60))
        From: \(truncateText(email.sender, maxLength: 25))
        Content: \(bodyText)
        """
    }
    
    /// Build optimized task prompt
    private func buildOptimizedTaskPrompt(query: String, emailContext: String) -> String {
        // Extract the core task creation request from the original query
        return """
        Analyze this email and create actionable tasks. Make task titles action-oriented, not just email subjects.

        Email:
        \(emailContext)

        Guidelines:
        - Start titles with action verbs: "Pay", "Review", "Follow up", "Schedule", "Respond to"
        - For bills: "Pay [vendor] invoice $[amount] - Due [date]"
        - For meetings: "Attend [meeting] on [date]" or "Schedule [meeting]"
        - For OOO/notifications: "Note [person] out of office [date]" or "Plan coverage for [person]"
        - For requests: "Review [request]" or "Respond to [request]"
        - For deadlines: "Complete [task] by [date]"
        - Be specific and actionable

        JSON format: {"tasks":[{"title":"Review team OOO request for Friday 11/7/25","description":"Plan coverage while team member is out","dueDate":"2025-11-06","section":null,"tags":[],"amount":null,"priority":"low","isRecurring":false,"recurrencePattern":null}]}

        If no actionable tasks needed, return: {"tasks":[]}

        JSON response:
        """
    }
    
    /// Implement Apple's TN3193 guidance for context window management
    private func queryWithContextWindowManagement(query: String, emails: [ProcessedEmail], retryCount: Int = 0) async throws -> String {
        _ = 4
        
        // Progressive content reduction strategies (Apple TN3193)
        let strategies = [
            ContextStrategy(name: "Standard", maxEmails: 5, maxCharsPerEmail: 800, useFullInstructions: true),
            ContextStrategy(name: "Reduced", maxEmails: 3, maxCharsPerEmail: 500, useFullInstructions: true),
            ContextStrategy(name: "Minimal", maxEmails: 2, maxCharsPerEmail: 300, useFullInstructions: false),
            ContextStrategy(name: "Essential", maxEmails: 1, maxCharsPerEmail: 200, useFullInstructions: false)
        ]
        
        guard retryCount < strategies.count else {
            throw AppleIntelligenceError.maxRetriesExceeded
        }
        
        let strategy = strategies[retryCount]
        print("🧠 Attempt \(retryCount + 1) using '\(strategy.name)' strategy")
        
        do {
            // Create concise instructions based on strategy
            let instructions = createOptimizedInstructions(useFullInstructions: strategy.useFullInstructions)
            
            // Prepare email context using current strategy
            let emailContext = prepareOptimizedEmailContext(
                emails, 
                maxEmails: strategy.maxEmails,
                maxCharsPerEmail: strategy.maxCharsPerEmail
            )
            
            // Create optimized prompt (Apple TN3193: concise and imperative language)
            let prompt = buildOptimizedPrompt(query: query, emailContext: emailContext)
            
            // Create new session for this attempt
            let session = LanguageModelSession(instructions: instructions)
            
            print("🧠 Sending query with \(strategy.name) strategy...")
            let response = try await session.respond(to: prompt)
            print("✅ Apple Intelligence query succeeded with \(strategy.name) strategy")
            
            return response.content
            
        } catch let error as LanguageModelSession.GenerationError {
            print("❌ Strategy '\(strategy.name)' failed: \(error)")
            
            // Handle context window exceeded error specifically (Apple TN3193)
            if case .exceededContextWindowSize = error {
                print("📏 Context window exceeded, trying with reduced content...")
                
                // Try next strategy with smaller content
                return try await queryWithContextWindowManagement(
                    query: query, 
                    emails: emails, 
                    retryCount: retryCount + 1
                )
            } else {
                // Other errors - rethrow
                throw error
            }
        } catch {
            print("❌ Unexpected error in strategy '\(strategy.name)': \(error)")
            throw error
        }
    }
    
    /// Build optimized prompt following Apple TN3193 guidance
    private func buildOptimizedPrompt(query: String, emailContext: String) -> String {
        // Apple TN3193: Use concise and imperative language, clear verbs
        return """
        Analyze the following emails and answer: \(query)
        
        Emails:
        \(emailContext)
        
        Provide a specific, helpful response. Reference relevant emails by subject when appropriate. Keep response under 3 paragraphs.
        """
    }
    
    /// Create optimized instructions following Apple TN3193 guidance
    private func createOptimizedInstructions(useFullInstructions: Bool) -> String {
        if useFullInstructions {
            // Full instructions for better quality when context allows
            return """
            You are an intelligent email assistant. Analyze emails and provide helpful, specific responses.
            
            Guidelines:
            - Reference emails by subject and sender when relevant
            - Be precise and actionable
            - Organize information clearly
            - State limitations if information not found
            """
        } else {
            // Minimal instructions to save tokens (Apple TN3193)
            return "You are an email assistant. Analyze the emails and respond helpfully to user queries."
        }
    }
    
    /// Prepare optimized email context following Apple TN3193 guidance
    private func prepareOptimizedEmailContext(_ emails: [ProcessedEmail], maxEmails: Int, maxCharsPerEmail: Int) -> String {
        // Select most relevant emails first
        let relevantEmails = selectRelevantEmails(emails, limit: maxEmails)
        
        let emailData = relevantEmails.map { email in
            // Aggressive content truncation (Apple TN3193)
            let bodyText = truncateEmailContent(email, maxChars: maxCharsPerEmail)
            
            // Minimal format to save tokens
            return """
            Subject: \(truncateText(email.subject, maxLength: 60))
            From: \(truncateText(email.sender, maxLength: 30))
            Content: \(bodyText)
            """
        }
        
        return emailData.joined(separator: "\n---\n")
    }
    
    /// Select most relevant emails based on recency and content
    private func selectRelevantEmails(_ emails: [ProcessedEmail], limit: Int) -> [ProcessedEmail] {
        // Sort by date (most recent first) and take the limit
        return Array(emails.sorted { $0.receivedDate > $1.receivedDate }.prefix(limit))
    }
    
    /// Truncate email content aggressively to fit context window
    private func truncateEmailContent(_ email: ProcessedEmail, maxChars: Int) -> String {
        let fullContent = email.body.isEmpty ? email.snippet : email.body
        return truncateText(fullContent, maxLength: maxChars)
    }
    
    /// Utility to truncate text cleanly
    private func truncateText(_ text: String, maxLength: Int) -> String {
        if text.count <= maxLength {
            return text
        }
        
        let truncateIndex = text.index(text.startIndex, offsetBy: maxLength - 10)
        return String(text[..<truncateIndex]) + "..."
    }
    
    // MARK: - Context Strategy
    
    private struct ContextStrategy {
        let name: String
        let maxEmails: Int
        let maxCharsPerEmail: Int
        let useFullInstructions: Bool
    }
    
    /// Generate structured email insights using Apple Intelligence with context management
    func generateEmailInsights(emails: [ProcessedEmail]) async throws -> EmailInsights {
        guard isAvailable else {
            if case .unavailable(let reason) = systemLanguageModel.availability {
                throw AppleIntelligenceError.modelNotAvailable(reason)
            } else {
                throw AppleIntelligenceError.sessionCreationFailed
            }
        }
        
        return try await generateInsightsWithContextManagement(emails: emails)
    }
    
    private func generateInsightsWithContextManagement(emails: [ProcessedEmail], retryCount: Int = 0) async throws -> EmailInsights {
        let maxRetries = 3
        guard retryCount < maxRetries else {
            throw AppleIntelligenceError.maxRetriesExceeded
        }
        
        // Progressive reduction strategies
        let emailLimits = [8, 5, 3]
        let charLimits = [600, 400, 200]
        
        let maxEmails = emailLimits[retryCount]
        let maxChars = charLimits[retryCount]
        
        do {
            let instructions = "Analyze emails and extract structured insights about urgent items, actions, and deadlines."
            let session = LanguageModelSession(instructions: instructions)
            
            let emailContext = prepareOptimizedEmailContext(emails, maxEmails: maxEmails, maxCharsPerEmail: maxChars)
            let prompt = "Generate insights from:\n\n\(emailContext)"
            
            let response = try await session.respond(to: prompt, generating: EmailInsights.self)
            return response.content
            
        } catch let error as LanguageModelSession.GenerationError {
            if case .exceededContextWindowSize = error {
                return try await generateInsightsWithContextManagement(emails: emails, retryCount: retryCount + 1)
            } else {
                throw error
            }
        }
    }
    
    /// Summarize a single email using Apple Intelligence with context management
    func summarizeEmail(_ email: ProcessedEmail) async throws -> String {
        guard isAvailable else {
            if case .unavailable(let reason) = systemLanguageModel.availability {
                throw AppleIntelligenceError.modelNotAvailable(reason)
            } else {
                throw AppleIntelligenceError.sessionCreationFailed
            }
        }
        
        return try await summarizeEmailWithContextManagement(email: email)
    }
    
    private func summarizeEmailWithContextManagement(email: ProcessedEmail, retryCount: Int = 0) async throws -> String {
        let maxRetries = 3
        guard retryCount < maxRetries else {
            throw AppleIntelligenceError.maxRetriesExceeded
        }
        
        // Progressive content limits
        let contentLimits = [1200, 800, 400]
        let maxChars = contentLimits[retryCount]
        
        do {
            let instructions = "Provide concise, actionable email summaries focusing on key points and required actions."
            let session = LanguageModelSession(instructions: instructions)
            
            let emailContent = """
            Subject: \(truncateText(email.subject, maxLength: 80))
            From: \(truncateText(email.sender, maxLength: 40))
            Date: \(formatDate(email.receivedDate))
            
            Body: \(truncateText(email.body.isEmpty ? email.snippet : email.body, maxLength: maxChars))
            """
            
            let prompt = "Summarize this email in 2-3 sentences:\n\n\(emailContent)"
            
            let response = try await session.respond(to: prompt)
            return response.content
            
        } catch let error as LanguageModelSession.GenerationError {
            if case .exceededContextWindowSize = error {
                return try await summarizeEmailWithContextManagement(email: email, retryCount: retryCount + 1)
            } else {
                throw error
            }
        }
    }
    
    /// Extract action items from emails using Apple Intelligence with context management
    func extractActionItems(from emails: [ProcessedEmail]) async throws -> [ActionItem] {
        guard isAvailable else {
            if case .unavailable(let reason) = systemLanguageModel.availability {
                throw AppleIntelligenceError.modelNotAvailable(reason)
            } else {
                throw AppleIntelligenceError.sessionCreationFailed
            }
        }
        
        return try await extractActionItemsWithContextManagement(emails: emails)
    }
    
    private func extractActionItemsWithContextManagement(emails: [ProcessedEmail], retryCount: Int = 0) async throws -> [ActionItem] {
        let maxRetries = 3
        guard retryCount < maxRetries else {
            throw AppleIntelligenceError.maxRetriesExceeded
        }
        
        let emailLimits = [6, 4, 2]
        let charLimits = [500, 300, 150]
        
        let maxEmails = emailLimits[retryCount]
        let maxChars = charLimits[retryCount]
        
        do {
            let instructions = "Extract specific, actionable tasks and deadlines from emails. Focus on items requiring recipient action."
            let session = LanguageModelSession(instructions: instructions)
            
            let emailContext = prepareOptimizedEmailContext(emails, maxEmails: maxEmails, maxCharsPerEmail: maxChars)
            let prompt = "Extract action items from:\n\n\(emailContext)"
            
            let response = try await session.respond(to: prompt, generating: ActionItemList.self)
            return response.content.items
            
        } catch let error as LanguageModelSession.GenerationError {
            if case .exceededContextWindowSize = error {
                return try await extractActionItemsWithContextManagement(emails: emails, retryCount: retryCount + 1)
            } else {
                throw error
            }
        }
    }
    
    // MARK: - Smart Email Categorization
    
    /// Categorize emails using Apple Intelligence with context management
    func categorizeEmail(_ email: ProcessedEmail) async throws -> EmailCategory {
        guard isAvailable else {
            if case .unavailable(let reason) = systemLanguageModel.availability {
                throw AppleIntelligenceError.modelNotAvailable(reason)
            } else {
                throw AppleIntelligenceError.sessionCreationFailed
            }
        }
        
        return try await categorizeEmailWithContextManagement(email: email)
    }
    
    private func categorizeEmailWithContextManagement(email: ProcessedEmail, retryCount: Int = 0) async throws -> EmailCategory {
        let maxRetries = 2
        guard retryCount < maxRetries else {
            throw AppleIntelligenceError.maxRetriesExceeded
        }
        
        let contentLimits = [800, 400]
        let maxChars = contentLimits[retryCount]
        
        do {
            let instructions = "Categorize emails based on content and context."
            let session = LanguageModelSession(instructions: instructions)
            
            let emailContent = """
            Subject: \(truncateText(email.subject, maxLength: 60))
            From: \(truncateText(email.sender, maxLength: 30))
            Body: \(truncateText(email.body.isEmpty ? email.snippet : email.body, maxLength: maxChars))
            """
            
            let prompt = "Categorize this email:\n\n\(emailContent)"
            
            let response = try await session.respond(to: prompt, generating: EmailCategory.self)
            return response.content
            
        } catch let error as LanguageModelSession.GenerationError {
            if case .exceededContextWindowSize = error {
                return try await categorizeEmailWithContextManagement(email: email, retryCount: retryCount + 1)
            } else {
                throw error
            }
        }
    }
    
    // MARK: - Streaming Support with Context Management
    
    /// Stream email analysis responses with context window management
    func streamEmailAnalysis(query: String, emails: [ProcessedEmail]) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            _Concurrency.Task {
                do {
                    guard isAvailable else {
                        if case .unavailable(let reason) = systemLanguageModel.availability {
                            throw AppleIntelligenceError.modelNotAvailable(reason)
                        } else {
                            throw AppleIntelligenceError.sessionCreationFailed
                        }
                    }
                    
                    // Try streaming with progressive context reduction
                    try await streamWithContextManagement(
                        query: query,
                        emails: emails,
                        continuation: continuation
                    )
                    
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    private func streamWithContextManagement(
        query: String,
        emails: [ProcessedEmail],
        continuation: AsyncThrowingStream<String, Error>.Continuation,
        retryCount: Int = 0
    ) async throws {
        let strategies = [
            ContextStrategy(name: "Standard", maxEmails: 4, maxCharsPerEmail: 600, useFullInstructions: false),
            ContextStrategy(name: "Reduced", maxEmails: 3, maxCharsPerEmail: 400, useFullInstructions: false),
            ContextStrategy(name: "Minimal", maxEmails: 2, maxCharsPerEmail: 250, useFullInstructions: false)
        ]
        
        guard retryCount < strategies.count else {
            throw AppleIntelligenceError.maxRetriesExceeded
        }
        
        let strategy = strategies[retryCount]
        
        do {
            let instructions = createOptimizedInstructions(useFullInstructions: strategy.useFullInstructions)
            let session = LanguageModelSession(instructions: instructions)
            
            let emailContext = prepareOptimizedEmailContext(
                emails,
                maxEmails: strategy.maxEmails,
                maxCharsPerEmail: strategy.maxCharsPerEmail
            )
            
            let prompt = buildOptimizedPrompt(query: query, emailContext: emailContext)
            
            let stream = session.streamResponse(to: prompt)
            
            for try await partial in stream {
                continuation.yield(partial.content)
            }
            
            continuation.finish()
            
        } catch let error as LanguageModelSession.GenerationError {
            if case .exceededContextWindowSize = error {
                // Try again with smaller context
                try await streamWithContextManagement(
                    query: query,
                    emails: emails,
                    continuation: continuation,
                    retryCount: retryCount + 1
                )
            } else {
                throw error
            }
        }
    }
    
    // MARK: - Utility Methods
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // MARK: - Public API
    
    func checkAvailability() async -> Bool {
        await checkModelAvailability()
        return isAvailable
    }
    
    func getStatus() -> ModelStatus {
        return status
    }
}

// MARK: - SystemLanguageModel.Availability.UnavailableReason Extension

extension SystemLanguageModel.Availability.UnavailableReason {
    nonisolated var displayText: String {
        switch self {
        case .deviceNotEligible:
            return "Device not eligible for Apple Intelligence"
        case .appleIntelligenceNotEnabled:
            return "Please enable Apple Intelligence in Settings"
        case .modelNotReady:
            return "Apple Intelligence model not ready"
        @unknown default:
            return "Apple Intelligence unavailable"
        }
    }
}
