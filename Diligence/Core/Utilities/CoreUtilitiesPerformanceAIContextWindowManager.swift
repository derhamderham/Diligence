//
//  AIContextWindowManager.swift
//  Diligence
//
//  Optimization 3: AI context window management and query optimization
//

import Foundation
import Combine
import SwiftUI

// MARK: - AI Context Window Manager

/// Manages AI context windows and optimizes email content for AI queries
@MainActor
final class AIContextWindowManager {
    
    // MARK: - Configuration
    
    struct ContextWindowLimits: Sendable {
        let maxTokens: Int
        let maxEmails: Int
        let maxEmailBodyLength: Int
        let estimatedTokensPerChar: Double
        
        nonisolated(unsafe) static let appleIntelligence = ContextWindowLimits(
            maxTokens: 4000,
            maxEmails: 50,
            maxEmailBodyLength: 2000,
            estimatedTokensPerChar: 0.25
        )
        
        nonisolated(unsafe) static let janAI = ContextWindowLimits(
            maxTokens: 8000,
            maxEmails: 100,
            maxEmailBodyLength: 4000,
            estimatedTokensPerChar: 0.25
        )
    }
    
    // MARK: - Properties
    
    private let limits: ContextWindowLimits
    
    // MARK: - Initialization
    
    init(limits: ContextWindowLimits = .appleIntelligence) {
        self.limits = limits
    }
    
    // MARK: - Context Window Optimization
    
    /// Optimize emails for AI context window
    func optimizeEmailsForContext(
        _ emails: [ProcessedEmail],
        query: String
    ) async -> OptimizedEmailContext {
        return await PerformanceMonitor.shared.measure("ai_context_optimization") {
            // Step 1: Rank emails by relevance to query
            let rankedEmails = rankEmailsByRelevance(emails, query: query)
            
            // Step 2: Progressive truncation until we fit
            var selectedEmails: [ProcessedEmail] = []
            var estimatedTokens = estimateTokens(for: query)
            
            for email in rankedEmails {
                let emailTokens = estimateTokens(for: email)
                
                if estimatedTokens + emailTokens <= limits.maxTokens &&
                   selectedEmails.count < limits.maxEmails {
                    selectedEmails.append(email)
                    estimatedTokens += emailTokens
                } else {
                    // Try truncated version
                    if let truncated = truncateEmail(email, maxLength: limits.maxEmailBodyLength) {
                        let truncatedTokens = estimateTokens(for: truncated)
                        
                        if estimatedTokens + truncatedTokens <= limits.maxTokens {
                            selectedEmails.append(truncated)
                            estimatedTokens += truncatedTokens
                        } else {
                            // Can't fit any more emails
                            break
                        }
                    }
                }
            }
            
            return OptimizedEmailContext(
                query: query,
                emails: selectedEmails,
                originalCount: emails.count,
                estimatedTokens: estimatedTokens,
                wasTruncated: selectedEmails.count < emails.count
            )
        }
    }
    
    // MARK: - Relevance Ranking
    
    private func rankEmailsByRelevance(
        _ emails: [ProcessedEmail],
        query: String
    ) -> [ProcessedEmail] {
        let queryTerms = query.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        let scoredEmails = emails.map { email -> (email: ProcessedEmail, score: Double) in
            let score = calculateRelevanceScore(
                email: email,
                queryTerms: queryTerms
            )
            return (email, score)
        }
        
        return scoredEmails
            .sorted { $0.score > $1.score }
            .map { $0.email }
    }
    
    private func calculateRelevanceScore(
        email: ProcessedEmail,
        queryTerms: [String]
    ) -> Double {
        var score: Double = 0.0
        
        let subject = email.subject.lowercased()
        let body = email.body.lowercased()
        let sender = email.sender.lowercased()
        
        for term in queryTerms {
            // Subject matches are worth more
            if subject.contains(term) {
                score += 10.0
            }
            
            // Body matches
            if body.contains(term) {
                score += 5.0
            }
            
            // Sender matches
            if sender.contains(term) {
                score += 3.0
            }
        }
        
        // Recent emails get a slight boost
        let daysSinceReceived = Date().timeIntervalSince(email.receivedDate) / 86400
        let recencyBoost = max(0, 5.0 - daysSinceReceived * 0.5)
        score += recencyBoost
        
        // Emails with attachments might be more important
        if email.hasAttachments {
            score += 2.0
        }
        
        return score
    }
    
    // MARK: - Token Estimation
    
    private func estimateTokens(for text: String) -> Int {
        let charCount = text.count
        return Int(Double(charCount) * limits.estimatedTokensPerChar)
    }
    
    private func estimateTokens(for email: ProcessedEmail) -> Int {
        let subjectTokens = estimateTokens(for: email.subject)
        let bodyTokens = estimateTokens(for: email.body)
        let senderTokens = estimateTokens(for: email.sender)
        
        // Add some overhead for formatting
        let formattingOverhead = 50
        
        return subjectTokens + bodyTokens + senderTokens + formattingOverhead
    }
    
    // MARK: - Email Truncation
    
    private func truncateEmail(
        _ email: ProcessedEmail,
        maxLength: Int
    ) -> ProcessedEmail? {
        guard email.body.count > maxLength else {
            return email
        }
        
        // Truncate body intelligently at sentence or paragraph boundaries
        let truncatedBody = intelligentTruncate(
            email.body,
            maxLength: maxLength
        )
        
        // Create a new ProcessedEmail with truncated body
        return ProcessedEmail(
            id: email.id,
            threadId: email.threadId,
            subject: email.subject,
            sender: email.sender,
            senderEmail: email.senderEmail,
            body: truncatedBody,
            snippet: email.snippet,
            receivedDate: email.receivedDate,
            gmailURL: email.gmailURL,
            attachments: email.attachments
        )
    }
    
    private func intelligentTruncate(_ text: String, maxLength: Int) -> String {
        guard text.count > maxLength else {
            return text
        }
        
        let truncateAt = maxLength
        let substring = String(text.prefix(truncateAt))
        
        // Try to find the last sentence boundary
        let sentenceBreaks = [".", "!", "?"]
        for breakChar in sentenceBreaks {
            if let lastBreak = substring.lastIndex(of: Character(breakChar)) {
                let endIndex = substring.index(after: lastBreak)
                return String(substring[..<endIndex]) + "..."
            }
        }
        
        // Try to find the last paragraph break
        if let lastNewline = substring.lastIndex(of: "\n") {
            return String(substring[..<lastNewline]) + "..."
        }
        
        // Fall back to word boundary
        if let lastSpace = substring.lastIndex(of: " ") {
            return String(substring[..<lastSpace]) + "..."
        }
        
        // Last resort: hard truncate
        return substring + "..."
    }
    
    // MARK: - Batch Processing
    
    /// Process emails in batches to avoid overwhelming the context window
    func createBatches(
        from emails: [ProcessedEmail],
        maxBatchSize: Int? = nil
    ) -> [[ProcessedEmail]] {
        let batchSize = maxBatchSize ?? limits.maxEmails
        var batches: [[ProcessedEmail]] = []
        
        var currentBatch: [ProcessedEmail] = []
        var currentTokens = 0
        
        for email in emails {
            let emailTokens = estimateTokens(for: email)
            
            if currentTokens + emailTokens > limits.maxTokens ||
               currentBatch.count >= batchSize {
                // Start new batch
                if !currentBatch.isEmpty {
                    batches.append(currentBatch)
                }
                currentBatch = [email]
                currentTokens = emailTokens
            } else {
                currentBatch.append(email)
                currentTokens += emailTokens
            }
        }
        
        // Add remaining batch
        if !currentBatch.isEmpty {
            batches.append(currentBatch)
        }
        
        return batches
    }
}

// MARK: - Optimized Email Context

struct OptimizedEmailContext {
    let query: String
    let emails: [ProcessedEmail]
    let originalCount: Int
    let estimatedTokens: Int
    let wasTruncated: Bool
    
    var compressionRatio: Double {
        guard originalCount > 0 else { return 1.0 }
        return Double(emails.count) / Double(originalCount)
    }
    
    var description: String {
        if wasTruncated {
            return "Using \(emails.count) of \(originalCount) emails (~\(estimatedTokens) tokens)"
        } else {
            return "Using all \(emails.count) emails (~\(estimatedTokens) tokens)"
        }
    }
}

// MARK: - Enhanced AI Email Service with Optimization

extension EnhancedAIEmailService {
    
    /// Query emails with automatic context window management
    func queryEmailsOptimized(
        query: String,
        emails: [ProcessedEmail]
    ) async throws -> String {
        return try await PerformanceMonitor.shared.measure("ai_query_optimized") {
            // Create context window manager for current provider
            let limits: AIContextWindowManager.ContextWindowLimits
            switch selectedProvider {
            case .appleIntelligence:
                limits = .appleIntelligence
            case .janAI:
                limits = .janAI
            }
            
            let contextManager = AIContextWindowManager(limits: limits)
            
            // Optimize emails for context window
            let optimizedContext = await contextManager.optimizeEmailsForContext(
                emails,
                query: query
            )
            
            print("🤖 \(optimizedContext.description)")
            
            // Query with optimized context
            return try await queryEmails(
                query: query,
                emails: optimizedContext.emails
            )
        }
    }
    
    /// Query emails in batches for large datasets
    func queryEmailsInBatches(
        query: String,
        emails: [ProcessedEmail],
        combineResults: Bool = true
    ) async throws -> [String] {
        let limits: AIContextWindowManager.ContextWindowLimits
        switch selectedProvider {
        case .appleIntelligence:
            limits = .appleIntelligence
        case .janAI:
            limits = .janAI
        }
        
        let contextManager = AIContextWindowManager(limits: limits)
        let batches = contextManager.createBatches(from: emails)
        
        var results: [String] = []
        
        for (index, batch) in batches.enumerated() {
            print("🤖 Processing batch \(index + 1) of \(batches.count) (\(batch.count) emails)")
            
            let result = try await queryEmails(
                query: query,
                emails: batch
            )
            
            results.append(result)
            
            // Small delay between batches to avoid rate limiting
            if index < batches.count - 1 {
                try await _Concurrency.Task.sleep(for: .milliseconds(500))
            }
        }
        
        if combineResults && results.count > 1 {
            // Combine results with a summary query
            let combinedText = results.enumerated()
                .map { "Batch \($0 + 1):\n\($1)" }
                .joined(separator: "\n\n")
            
            return [combinedText]
        }
        
        return results
    }
}

// MARK: - Cancellable AI Query Manager

@MainActor
final class CancellableAIQueryManager: ObservableObject {
    
    private var currentTask: _Concurrency.Task<String, Error>?
    
    @Published private(set) var isQuerying = false
    @Published private(set) var progress: Double = 0.0
    
    /// Execute a cancellable AI query
    func executeQuery(
        _ query: String,
        emails: [ProcessedEmail],
        using service: EnhancedAIEmailService
    ) async throws -> String {
        // Cancel any existing query
        cancelCurrentQuery()
        
        isQuerying = true
        progress = 0.0
        defer { 
            isQuerying = false
            progress = 0.0
        }
        
        currentTask = _Concurrency.Task {
            // Simulate progress (in reality, you'd track actual progress)
            let progressTask = _Concurrency.Task {
                while !_Concurrency.Task.isCancelled {
                    await MainActor.run {
                        progress = min(0.9, progress + 0.1)
                    }
                    try? await _Concurrency.Task.sleep(for: .milliseconds(500))
                }
            }
            
            defer { progressTask.cancel() }
            
            let result = try await service.queryEmailsOptimized(
                query: query,
                emails: emails
            )
            
            await MainActor.run {
                progress = 1.0
            }
            
            return result
        }
        
        return try await currentTask!.value
    }
    
    /// Cancel the current query
    func cancelCurrentQuery() {
        currentTask?.cancel()
        currentTask = nil
        isQuerying = false
        progress = 0.0
    }
}

// MARK: - SwiftUI Integration

struct OptimizedAIQueryView: View {
    @StateObject private var queryManager = CancellableAIQueryManager()
    @ObservedObject var aiService: EnhancedAIEmailService
    
    let emails: [ProcessedEmail]
    
    @State private var query = ""
    @State private var response = ""
    @State private var error: Error?
    
    var body: some View {
        VStack(spacing: 16) {
            // Query input
            HStack {
                TextField("Ask about your emails...", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .disabled(queryManager.isQuerying)
                
                if queryManager.isQuerying {
                    Button("Cancel") {
                        queryManager.cancelCurrentQuery()
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button("Query") {
                        performQuery()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(query.isEmpty || emails.isEmpty)
                }
            }
            
            // Progress
            if queryManager.isQuerying {
                VStack(spacing: 8) {
                    ProgressView(value: queryManager.progress)
                    Text("Processing... \(Int(queryManager.progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Response
            if !response.isEmpty {
                ScrollView {
                    Text(response)
                        .textSelection(.enabled)
                        .padding()
                }
                .frame(maxHeight: 300)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)
            }
            
            // Error
            if let error = error {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.red)
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Dismiss") {
                        self.error = nil
                    }
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .trackPerformance("OptimizedAIQuery")
    }
    
    private func performQuery() {
        error = nil
        response = ""
        
        _Concurrency.Task {
            do {
                let result = try await queryManager.executeQuery(
                    query,
                    emails: emails,
                    using: aiService
                )
                
                await MainActor.run {
                    response = result
                }
            } catch {
                await MainActor.run {
                    self.error = error
                }
            }
        }
    }
}
