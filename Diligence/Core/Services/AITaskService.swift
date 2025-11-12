//
//  AITaskService.swift
//  Diligence
//
//  AI Task Creation Service for generating intelligent task suggestions from emails
//  Integrates with Jan.ai local LLM and Apple Intelligence
//

import Foundation
import SwiftUI
import SwiftData
import PDFKit
import Vision
import NaturalLanguage
import UniformTypeIdentifiers
import Combine

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - AI Task Response Models

import Foundation

struct AITaskResponse: Codable {
    let tasks: [AITaskSuggestion]
}

enum AppRecurrencePattern: String, CaseIterable, Codable {
    case never
    case daily
    case weekly
    case biweekly
    case monthly
    case quarterly
    case yearly
    case custom
}

enum AITaskPriority: String, Codable, CaseIterable {
    case low
    case medium
    case high
    case urgent

    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .urgent: return "Urgent"
        }
    }
}

// Optional: typed recurrence with a fallback
enum RecurrenceKind: String, Codable, CaseIterable {
    case daily
    case weekly
    case biweekly
    case monthly
    case quarterly
    case yearly
    case custom

    init(fromRaw raw: String) {
        self = RecurrenceKind(rawValue: raw.lowercased()) ?? .custom
    }
}

struct AITaskSuggestion: Codable, Identifiable {
    // Keep id stable when decoding; generate if not provided
    let id: UUID
    var title: String
    var description: String
    // Keep the original string for API compatibility
    var dueDate: String? // "YYYY-MM-DD" or nil
    var section: String?
    var tags: [String]
    var amount: Double?
    var priority: AITaskPriority?
    var isRecurring: Bool?
    var recurrencePattern: String? // "monthly", "weekly", etc.

    // MARK: - Initializer
    init(
        id: UUID = UUID(),
        title: String,
        description: String,
        dueDate: String? = nil,
        section: String? = nil,
        tags: [String] = [],
        amount: Double? = nil,
        priority: AITaskPriority? = nil,
        isRecurring: Bool? = nil,
        recurrencePattern: String? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.dueDate = dueDate
        self.section = section
        self.tags = tags
        self.amount = amount
        self.priority = priority
        self.isRecurring = isRecurring
        self.recurrencePattern = recurrencePattern
    }

    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case dueDate
        case section
        case tags
        case amount
        case priority
        case isRecurring
        case recurrencePattern
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.title = try c.decode(String.self, forKey: .title)
        self.description = try c.decode(String.self, forKey: .description)
        self.dueDate = try c.decodeIfPresent(String.self, forKey: .dueDate)
        self.section = try c.decodeIfPresent(String.self, forKey: .section)
        self.tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        self.amount = try c.decodeIfPresent(Double.self, forKey: .amount)
        self.priority = try c.decodeIfPresent(AITaskPriority.self, forKey: .priority)
        self.isRecurring = try c.decodeIfPresent(Bool.self, forKey: .isRecurring)
        self.recurrencePattern = try c.decodeIfPresent(String.self, forKey: .recurrencePattern)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(description, forKey: .description)
        try c.encodeIfPresent(dueDate, forKey: .dueDate)
        try c.encodeIfPresent(section, forKey: .section)
        try c.encode(tags, forKey: .tags)
        try c.encodeIfPresent(amount, forKey: .amount)
        try c.encodeIfPresent(priority, forKey: .priority)
        try c.encodeIfPresent(isRecurring, forKey: .isRecurring)
        try c.encodeIfPresent(recurrencePattern, forKey: .recurrencePattern)
    }

    // MARK: - Helpers

    // Parse "YYYY-MM-DD" into a Date at midnight UTC
    var dueDateAsDate: Date? {
        guard let dueDate else { return nil }
        return Self.yyyyMMdd.date(from: dueDate)
    }

    // Normalized tags: trimmed, lowercase, deduplicated
    var normalizedTags: [String] {
        Array(Set(tags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })).sorted()
    }

    // Optional: map the string recurrence into a typed enum
    var recurrenceKind: RecurrenceKind? {
        guard let recurrencePattern else { return nil }
        return RecurrenceKind(fromRaw: recurrencePattern)
    }

    private static let yyyyMMdd: DateFormatter = {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .iso8601)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()
}

// MARK: - AI Task Service

@MainActor
class AITaskService: ObservableObject {
    // MARK: - Dependencies
    
    private let gmailService: GmailService
    private let aiService: EnhancedAIEmailService
    
    // MARK: - Published Properties
    
    @Published var isProcessing = false
    @Published var processingProgress: Double = 0.0
    @Published var processingStatus = "Ready"
    @Published var lastError: String?
    
    // MARK: - Private Properties
    
    private let documentProcessor = DocumentProcessor()
    
    // MARK: - Initialization
    
    init(aiService: EnhancedAIEmailService, gmailService: GmailService) {
        self.aiService = aiService
        self.gmailService = gmailService
        
        // Initialize with safe default values
        self.processingProgress = 0.0
        self.isProcessing = false
        self.processingStatus = "Ready"
        self.lastError = nil
    }
    
    // MARK: - Main Task Creation Method
    
    func createAITaskSuggestions(for email: ProcessedEmail, availableSections: [TaskSection]) async throws -> [AITaskSuggestion] {
        guard aiService.hasAvailableService else {
            throw AITaskError.serviceUnavailable("No AI services available")
        }
        
        isProcessing = true
        processingProgress = 0.0
        lastError = nil
        
        defer {
            isProcessing = false
            processingProgress = 1.0
        }
        
        do {
            // Step 1: Process email content and attachments
            processingStatus = "Analyzing email content..."
            processingProgress = 0.1
            
            let emailContext = try await buildEmailContext(for: email)
            processingProgress = 0.3
            
            // Step 2: Extract attachment content
            processingStatus = "Processing attachments..."
            let attachmentContent = await extractAttachmentContent(from: email.attachments)
            processingProgress = 0.5
            
            // Step 3: Build AI prompt
            processingStatus = "Generating task suggestions..."
            let prompt = buildTaskCreationPrompt(
                emailContext: emailContext,
                attachmentContent: attachmentContent,
                availableSections: availableSections
            )
            processingProgress = 0.7
            
            // Step 4: Query AI service
            let response = try await aiService.queryEmails(query: prompt, emails: [email])
            processingProgress = 0.9
            
            // Debug: Log the response for troubleshooting
            print("🤖 AI Service Response:")
            print("📄 Response length: \(response.count) characters")
            print("📄 First 300 characters: \(response.prefix(300))")
            if response.contains("{") {
                print("✅ Response contains JSON-like structure")
            } else {
                print("❌ Response does not contain JSON structure")
            }
            
            // Step 5: Parse and return suggestions
            processingStatus = "Parsing suggestions..."
            let suggestions = try parseAIResponse(response)
            processingStatus = "Complete"
            
            return suggestions
            
        } catch {
            lastError = error.localizedDescription
            processingStatus = "Error: \(error.localizedDescription)"
            throw error
        }
    }
    
    // MARK: - Email Context Building (Optimized for Context Window)
    
    private func buildEmailContext(for email: ProcessedEmail) async throws -> EmailContext {
        let nlProcessor = NLLanguageRecognizer()
        // Limit content for language processing to save tokens
        let contentForAnalysis = String((email.body + " " + email.subject).prefix(500))
        nlProcessor.processString(contentForAnalysis)
        let language = nlProcessor.dominantLanguage?.rawValue ?? "en"
        
        // Enhanced entity extraction with specific focus on business details
        let combinedText = String((email.body + " " + email.subject).prefix(800))
        let dateMatches = extractDatesFromText(combinedText)
        let amountMatches = extractAmountsFromText(combinedText)
        let entities = extractNamedEntities(from: combinedText)
        let companyNames = extractCompanyNames(from: combinedText)
        let personNames = extractPersonName(from: combinedText)
        
        // Add extracted details to the context for AI processing
        var enhancedEntities = entities
        companyNames.forEach { enhancedEntities.append("Company: \($0)") }
        if let person = personNames {
            enhancedEntities.append("Person: \(person)")
        }
        
        return EmailContext(
            subject: email.subject,
            body: String(email.body.prefix(1000)), // Limit body content more aggressively
            sender: email.sender,
            senderEmail: email.senderEmail,
            receivedDate: email.receivedDate,
            language: language,
            detectedDates: Array(dateMatches.prefix(3)), // Limit detected items
            detectedAmounts: Array(amountMatches.prefix(3)),
            namedEntities: Array(enhancedEntities.prefix(8)), // Increased limit for enhanced entities
            hasAttachments: !email.attachments.isEmpty,
            attachmentTypes: Array(email.attachments.prefix(3).map { $0.mimeType }) // Limit attachment types
        )
    }
    
    // MARK: - Attachment Content Extraction (Optimized)
    
    private func extractAttachmentContent(from attachments: [EmailAttachment]) async -> [AttachmentContent] {
        var contents: [AttachmentContent] = []
        
        // Limit number of attachments processed to save context window space
        let limitedAttachments = Array(attachments.prefix(3))
        
        for attachment in limitedAttachments {
            processingStatus = "Processing \(attachment.filename)..."
            
            guard let fileURL = await gmailService.downloadAttachment(attachment) else {
                print("⚠️ Failed to download attachment: \(attachment.filename)")
                continue
            }
            
            let content = await documentProcessor.extractLimitedContent(from: fileURL, filename: attachment.filename)
            contents.append(content)
        }
        
        return contents
    }
    
    // MARK: - AI Prompt Construction (Optimized for Apple Intelligence Context Window)
    
    private func buildTaskCreationPrompt(
        emailContext: EmailContext,
        attachmentContent: [AttachmentContent],
        availableSections: [TaskSection]
    ) -> String {
        let sectionNames = availableSections.map { $0.title }.joined(separator: ", ")
        let currentDate = ISO8601DateFormatter().string(from: Date()).prefix(10) // YYYY-MM-DD format
        
        // Optimized attachment summary (Apple TN3193: reduce content size)
        let attachmentSummary = attachmentContent.isEmpty ? "" : 
            "Files: " + attachmentContent.map { 
                "\($0.filename): \(String($0.extractedText.prefix(80)))..." 
            }.joined(separator: "; ")
        
        // Truncate email content more aggressively
        let emailBody = String(emailContext.body.prefix(500))
        let emailSubject = String(emailContext.subject.prefix(60))
        
        // Include detected entities for better context
        let detectedInfo = buildDetectedInfoString(from: emailContext)
        
        // Apple TN3193: Use concise, imperative language with clear verbs
        return """
        Analyze this email for actionable tasks. Extract SPECIFIC details from the email content to create precise task titles.

        EMAIL:
        Subject: \(emailSubject)
        From: \(emailContext.sender)
        Date: \(ISO8601DateFormatter().string(from: emailContext.receivedDate).prefix(10))
        Content: \(emailBody)
        \(attachmentSummary)
        
        \(detectedInfo)

        Available sections: \(sectionNames.isEmpty ? "None" : sectionNames)
        Today: \(currentDate)

        CRITICAL: Replace ALL placeholders with ACTUAL details from the email:
        - For bills/invoices: Use the ACTUAL company name and dollar amount from the email
        - For meetings: Use the ACTUAL meeting name/topic and date from the email
        - For people: Use the ACTUAL person's name from the email
        - For dates: Extract the SPECIFIC dates mentioned in the email
        - For amounts: Extract the EXACT dollar amounts from the email

        Task Title Pattern Examples (use ACTUAL details, not placeholders):
        - Bills: "Pay Acme Corp invoice $1,250.00" (NOT "Pay [vendor] invoice $[amount]")
        - Meetings: "Attend Q4 planning meeting on 2025-11-15" (NOT "Attend [meeting] on [date]")
        - OOO: "Note Sarah Johnson out of office Nov 8-12" (NOT "Note [person] out of office [dates]")
        - Documents: "Review Q3 financial report" (NOT "Review [document]")

        Start titles with action verbs: Pay, Review, Schedule, Respond, Complete, Follow up, Note, Plan.

        Return ONLY this JSON format with SPECIFIC details:
        {"tasks":[{"title":"Pay Acme Corp invoice $1,250.00","description":"Monthly service invoice due November 30th","dueDate":"2025-11-30","section":null,"tags":[],"amount":1250.00,"priority":"medium","isRecurring":false,"recurrencePattern":null}]}

        If no tasks needed, return: {"tasks":[]}

        JSON response:
        """
    }
    
    private func buildDetectedInfoString(from context: EmailContext) -> String {
        var infoLines: [String] = []
        
        if !context.detectedAmounts.isEmpty {
            let amounts = context.detectedAmounts.map { formatCurrency($0) }.joined(separator: ", ")
            infoLines.append("Detected amounts: \(amounts)")
        }
        
        if !context.detectedDates.isEmpty {
            let dates = context.detectedDates.map { formatDate($0) }.joined(separator: ", ")
            infoLines.append("Detected dates: \(dates)")
        }
        
        if !context.namedEntities.isEmpty {
            let entities = context.namedEntities.prefix(5).joined(separator: ", ")
            infoLines.append("Detected entities: \(entities)")
        }
        
        return infoLines.isEmpty ? "" : "EXTRACTED DETAILS:\n" + infoLines.joined(separator: "\n")
    }
    
    // MARK: - AI Response Parsing
    
    private func parseAIResponse(_ response: String) throws -> [AITaskSuggestion] {
        print("🔍 Parsing AI response...")
        print("📄 Raw response length: \(response.count) characters")
        
        // Clean the response to extract JSON
        let cleanedResponse = extractJSONFromResponse(response)
        print("🧹 Cleaned response: \(cleanedResponse)")
        
        // Check if we found any JSON-like content
        if cleanedResponse == response && !response.contains("{") {
            print("❌ No JSON structure found in response")
            throw AITaskError.noTasksFound("AI response does not contain JSON format: '\(response.prefix(200))...'")
        }
        
        guard let jsonData = cleanedResponse.data(using: .utf8) else {
            throw AITaskError.invalidResponse("Could not encode response as UTF-8")
        }
        
        do {
            let decoder = JSONDecoder()
            let aiResponse = try decoder.decode(AITaskResponse.self, from: jsonData)
            print("✅ Successfully parsed \(aiResponse.tasks.count) tasks")
            
            // Clean and validate all task titles to remove any JSON formatting artifacts
            let cleanedTasks = aiResponse.tasks.map { task in
                var cleanedTask = task
                cleanedTask.title = cleanTaskTitle(task.title)
                return cleanedTask
            }
            
            return cleanedTasks
        } catch {
            print("❌ JSON parsing error: \(error)")
            print("📄 Raw response: \(response.prefix(500))")
            print("🧹 Cleaned response: \(cleanedResponse)")
            
            // Try to extract tasks manually as fallback
            return try parseAIResponseManually(response)
        }
    }
    
    /// Clean task title to remove any JSON formatting artifacts
    private func cleanTaskTitle(_ title: String) -> String {
        var cleaned = title
        
        // Remove common JSON formatting artifacts
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove quotes at the beginning and end if they exist
        if cleaned.hasPrefix("\"") && cleaned.hasSuffix("\"") {
            cleaned = String(cleaned.dropFirst().dropLast())
        }
        
        // Remove any remaining JSON key patterns like "title": 
        cleaned = cleaned.replacingOccurrences(of: #"^"title":\s*"?"#, with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #""title":\s*"?([^"]+)"?.*"#, with: "$1", options: .regularExpression)
        
        // Clean up any remaining JSON artifacts
        cleaned = cleaned.replacingOccurrences(of: #"^["\s]*"#, with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"["\s]*$"#, with: "", options: .regularExpression)
        
        // Remove any remaining JSON escape characters
        cleaned = cleaned.replacingOccurrences(of: "\\\"", with: "\"")
        cleaned = cleaned.replacingOccurrences(of: "\\n", with: " ")
        cleaned = cleaned.replacingOccurrences(of: "\\t", with: " ")
        
        // Clean up multiple spaces
        cleaned = cleaned.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        
        // Final trim
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("🧹 Title cleaned: '\(title)' → '\(cleaned)'")
        return cleaned
    }
    
    private func extractJSONFromResponse(_ response: String) -> String {
        print("🔍 Extracting JSON from response...")
        
        // More comprehensive JSON extraction patterns
        let patterns = [
            #"\{[^{}]*"tasks"[^{}]*:\s*\[[^\]]*\][^{}]*\}"#,  // Simple flat JSON with tasks array
            #"\{[\s\S]*?"tasks"[\s\S]*?\}(?=\s*$)"#,         // JSON object ending the response
            #"\{[\s\S]*?"tasks"[\s\S]*?\}"#,                 // Any JSON with tasks
            #"\{[^{]*\}"#                                     // Any simple JSON object
        ]
        
        for (index, pattern) in patterns.enumerated() {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive])
                let range = NSRange(response.startIndex..., in: response)
                if let match = regex.firstMatch(in: response, range: range) {
                    let jsonString = String(response[Range(match.range, in: response)!])
                    print("✅ Found JSON with pattern \(index + 1): \(jsonString.prefix(100))...")
                    return jsonString
                }
            } catch {
                print("⚠️ Error in regex pattern \(index + 1): \(error)")
            }
        }
        
        // Look for JSON manually by finding braces
        if let startIndex = response.firstIndex(of: "{"),
           let endIndex = response.lastIndex(of: "}") {
            let jsonCandidate = String(response[startIndex...endIndex])
            print("🔍 Manual brace extraction: \(jsonCandidate.prefix(100))...")
            return jsonCandidate
        }
        
        print("❌ No JSON structure found, returning original response")
        return response
    }
    
    private func parseAIResponseManually(_ response: String) throws -> [AITaskSuggestion] {
        print("🛠️ Attempting manual parsing of AI response...")
        
        // Try to create a basic task from the email content if AI didn't return proper JSON
        if response.lowercased().contains("no tasks") || response.lowercased().contains("no actionable") {
            print("ℹ️ AI explicitly indicated no tasks found")
            throw AITaskError.noTasksFound("AI determined no actionable tasks in email")
        }
        
        // Look for task-like patterns in natural language
        var suggestions: [AITaskSuggestion] = []
        
        // Split response into lines and look for task indicators
        let lines = response.components(separatedBy: .newlines)
        var currentTitle: String?
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines and JSON artifacts
            if trimmedLine.isEmpty || trimmedLine == "{" || trimmedLine == "}" || trimmedLine == "\"tasks\": [" {
                continue
            }
            
            // Look for task indicators
            if trimmedLine.contains("Task:") || trimmedLine.contains("Action:") || trimmedLine.contains("TODO:") {
                currentTitle = extractTaskFromLine(trimmedLine)
            } else if trimmedLine.contains("Pay ") || trimmedLine.contains("Review ") || 
                     trimmedLine.contains("Follow up") || trimmedLine.contains("Complete ") ||
                     trimmedLine.contains("Respond to") || trimmedLine.contains("Schedule ") ||
                     trimmedLine.contains("Note ") || trimmedLine.contains("Plan ") {
                currentTitle = trimmedLine
            } else if currentTitle == nil && trimmedLine.count > 10 && !trimmedLine.contains("email") {
                // Convert non-actionable titles to actionable ones
                currentTitle = makeActionable(trimmedLine)
            }
            
            // If we have accumulated a potential task, create it
            if let title = currentTitle, !title.isEmpty {
                let cleanTitle = cleanTaskTitle(title)
                let suggestion = AITaskSuggestion(
                    title: cleanTitle,
                    description: "Generated from email analysis",
                    dueDate: nil,
                    section: nil,
                    tags: [],
                    amount: nil,
                    priority: .medium,
                    isRecurring: false,
                    recurrencePattern: nil
                )
                suggestions.append(suggestion)
                currentTitle = nil
                
                // Only create one task from manual parsing to avoid spam
                break
            }
        }
        
        if suggestions.isEmpty {
            print("❌ Manual parsing found no tasks")
            throw AITaskError.noTasksFound("Could not extract any tasks from AI response: '\(response.prefix(200))...'")
        }
        
        print("✅ Manual parsing created \(suggestions.count) task(s)")
        return suggestions
    }
    
    /// Convert email subjects or descriptions into actionable task titles with specific details
    private func makeActionable(_ text: String) -> String {
        let cleanedText = cleanTaskTitle(text)
        let lowercased = cleanedText.lowercased()
        
        // Extract specific details from the text
        let dateMatches = extractDatesFromText(cleanedText)
        let amountMatches = extractAmountsFromText(cleanedText)
        let companyNames = extractCompanyNames(from: cleanedText)
        
        // Handle common email patterns and convert to actionable tasks with specific details
        if lowercased.contains("ooo") || lowercased.contains("out of office") {
            // Extract person name and dates if possible
            let personName = extractPersonName(from: cleanedText)
            let dateInfo = extractDateRange(from: cleanedText)
            
            if let person = personName, !dateInfo.isEmpty {
                return "Note \(person) out of office \(dateInfo)"
            } else if !dateInfo.isEmpty {
                return "Note team member out of office \(dateInfo)"
            } else {
                return "Review out of office notification"
            }
        } else if lowercased.contains("invoice") || lowercased.contains("bill") || lowercased.contains("payment") {
            // Extract company name and amount
            let company = companyNames.first ?? "vendor"
            let amount = amountMatches.first.map { formatCurrency($0) } ?? ""
            
            if company != "vendor" && !amount.isEmpty {
                return "Pay \(company) invoice \(amount)"
            } else if company != "vendor" {
                return "Pay \(company) invoice"
            } else if !amount.isEmpty {
                return "Pay invoice \(amount)"
            } else {
                return "Review and pay \(cleanedText)"
            }
        } else if lowercased.contains("meeting") || lowercased.contains("call") {
            // Extract meeting topic and date
            let meetingTopic = extractMeetingTopic(from: cleanedText)
            let meetingDate = dateMatches.first.map { formatDate($0) } ?? ""
            
            if !meetingTopic.isEmpty && !meetingDate.isEmpty {
                return "Attend \(meetingTopic) on \(meetingDate)"
            } else if !meetingTopic.isEmpty {
                return "Schedule \(meetingTopic)"
            } else {
                return "Schedule \(cleanedText)"
            }
        } else if lowercased.contains("request") {
            return "Review \(cleanedText)"
        } else if lowercased.contains("deadline") || lowercased.contains("due") {
            let deadline = dateMatches.first.map { formatDate($0) } ?? ""
            if !deadline.isEmpty {
                return "Complete \(cleanedText) by \(deadline)"
            } else {
                return "Complete \(cleanedText)"
            }
        } else if lowercased.contains("follow") {
            let personName = extractPersonName(from: cleanedText)
            let topic = extractTopic(from: cleanedText)
            
            if let person = personName, !topic.isEmpty {
                return "Follow up with \(person) about \(topic)"
            } else if let person = personName {
                return "Follow up with \(person)"
            } else {
                return "Follow up on \(cleanedText)"
            }
        } else if lowercased.contains("document") || lowercased.contains("file") || lowercased.contains("pdf") {
            return "Review \(cleanedText)"
        } else {
            // Default: add "Review" to make it actionable
            return "Review \(cleanedText)"
        }
    }
    
    private func extractTaskFromLine(_ line: String) -> String {
        // Remove common prefixes
        var cleaned = line
        let prefixes = ["Task:", "Action:", "TODO:", "-", "•", "*", "1.", "2.", "3."]
        
        for prefix in prefixes {
            if cleaned.hasPrefix(prefix) {
                cleaned = String(cleaned.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            }
        }
        
        return cleanTaskTitle(cleaned)
    }
    
    private func extractValueFromLine(_ line: String) -> String {
        if let colonIndex = line.firstIndex(of: ":") {
            return String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return line
    }
    
    private func createTaskFromDict(_ dict: [String: String]) -> AITaskSuggestion? {
        guard let title = dict["title"], !title.isEmpty else { return nil }
        
        return AITaskSuggestion(
            title: title,
            description: dict["description"] ?? "",
            dueDate: dict["dueDate"],
            section: dict["section"],
            tags: [],
            amount: nil,
            priority: nil,
            isRecurring: nil,
            recurrencePattern: nil
        )
    }
    
    // MARK: - Helper Methods for Content Analysis
    
    private func extractDatesFromText(_ text: String) -> [Date] {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        let matches = detector?.matches(in: text, range: NSRange(text.startIndex..., in: text)) ?? []
        
        return matches.compactMap { $0.date }
    }
    
    private func extractAmountsFromText(_ text: String) -> [Double] {
        let patterns = [
            #"\$[\d,]+\.?\d*"#,  // $123.45, $1,234
            #"[\d,]+\.?\d*\s*(dollars?|USD|\$)"#,  // 123.45 dollars
            #"(USD|EUR|GBP)\s*[\d,]+\.?\d*"#  // USD 123.45
        ]
        
        var amounts: [Double] = []
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
                for match in matches {
                    let matchString = String(text[Range(match.range, in: text)!])
                    // Extract numeric part
                    let numericString = matchString.replacingOccurrences(of: #"[^\d\.]"#, with: "", options: .regularExpression)
                    if let amount = Double(numericString) {
                        amounts.append(amount)
                    }
                }
            }
        }
        
        return amounts
    }
    
    private func extractNamedEntities(from text: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        
        var entities: [String] = []
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType) { tag, tokenRange in
            if let tag = tag {
                let entity = String(text[tokenRange])
                entities.append("\(tag.rawValue): \(entity)")
            }
            return true
        }
        
        return entities
    }
    
    // MARK: - Specific Detail Extraction Methods
    
    private func extractCompanyNames(from text: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        
        var companies: [String] = []
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType) { tag, tokenRange in
            if tag == .organizationName {
                let company = String(text[tokenRange])
                companies.append(company)
            }
            return true
        }
        
        // Also look for common company patterns
        let companyPatterns = [
            #"\b[A-Z][a-zA-Z]*\s+(Inc|Corp|LLC|Ltd|Company|Co)\b"#,
            #"\b[A-Z][a-zA-Z]*\s*&\s*[A-Z][a-zA-Z]*\b"#
        ]
        
        for pattern in companyPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
                for match in matches {
                    let company = String(text[Range(match.range, in: text)!])
                    companies.append(company)
                }
            }
        }
        
        return companies.unique()
    }
    
    private func extractPersonName(from text: String) -> String? {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        
        var personNames: [String] = []
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType) { tag, tokenRange in
            if tag == .personalName {
                let name = String(text[tokenRange])
                personNames.append(name)
            }
            return true
        }
        
        // Return the first name found, or combine if multiple parts
        return personNames.first
    }
    
    private func extractDateRange(from text: String) -> String {
        let dateMatches = extractDatesFromText(text)
        
        if dateMatches.count >= 2 {
            let startDate = formatDate(dateMatches[0])
            let endDate = formatDate(dateMatches[1])
            return "\(startDate) to \(endDate)"
        } else if let singleDate = dateMatches.first {
            return formatDate(singleDate)
        }
        
        // Look for textual date patterns
        let patterns = [
            #"\b(Mon|Tue|Wed|Thu|Fri|Sat|Sun)\w*\s+\d{1,2}[-/]\d{1,2}\b"#,
            #"\b(January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2}[-,]\s*\d{2,4}\b"#,
            #"\b\d{1,2}[-/]\d{1,2}[-/]\d{2,4}\b"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
                if let match = matches.first {
                    return String(text[Range(match.range, in: text)!])
                }
            }
        }
        
        return ""
    }
    
    private func extractMeetingTopic(from text: String) -> String {
        // Look for meeting-related keywords and extract the topic
        let patterns = [
            #"meeting\s+(?:about\s+|for\s+|on\s+)?([^,\.\n]+)"#,
            #"call\s+(?:about\s+|for\s+|on\s+)?([^,\.\n]+)"#,
            #"discussion\s+(?:about\s+|for\s+|on\s+)?([^,\.\n]+)"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
                if let match = matches.first, match.numberOfRanges > 1 {
                    let topicRange = Range(match.range(at: 1), in: text)!
                    return String(text[topicRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        
        // If no specific pattern found, return cleaned text
        return text.replacingOccurrences(of: #"\b(meeting|call|discussion)\b"#, with: "", options: .regularExpression)
                   .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func extractTopic(from text: String) -> String {
        // Extract the main topic by removing common prefixes and suffixes
        var topic = text
        
        // Remove common email prefixes
        let prefixes = ["re:", "fwd:", "fw:", "follow up on", "regarding", "about"]
        for prefix in prefixes {
            if topic.lowercased().hasPrefix(prefix) {
                topic = String(topic.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // Remove common suffixes
        if let firstSentenceEnd = topic.firstIndex(of: ".") {
            topic = String(topic[..<firstSentenceEnd])
        }
        
        return topic.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Array Extension for Unique Values

extension Array where Element: Hashable {
    func unique() -> [Element] {
        return Array(Set(self))
    }
}

// MARK: - Supporting Data Models

struct EmailContext {
    let subject: String
    let body: String
    let sender: String
    let senderEmail: String
    let receivedDate: Date
    let language: String
    let detectedDates: [Date]
    let detectedAmounts: [Double]
    let namedEntities: [String]
    let hasAttachments: Bool
    let attachmentTypes: [String]
}

struct AttachmentContent {
    let filename: String
    let mimeType: String
    let extractedText: String
    let documentType: DocumentType
    let metadata: [String: Any]
}

enum DocumentType {
    case pdf
    case wordDocument
    case image
    case text
    case spreadsheet
    case unknown
}

// MARK: - Document Processor

class DocumentProcessor {
    
    func extractContent(from fileURL: URL, filename: String) async -> AttachmentContent {
        return await extractLimitedContent(from: fileURL, filename: filename)
    }
    
    /// Extract limited content to save context window space (Apple TN3193)
    func extractLimitedContent(from fileURL: URL, filename: String) async -> AttachmentContent {
        let mimeType = inferMimeType(from: filename)
        let documentType = inferDocumentType(from: mimeType)
        
        var extractedText = ""
        var metadata: [String: Any] = [:]
        
        switch documentType {
        case .pdf:
            (extractedText, metadata) = await extractFromPDF(fileURL, maxLength: 800)
        case .image:
            extractedText = await extractFromImage(fileURL, maxLength: 600)
        case .text:
            extractedText = extractFromTextFile(fileURL, maxLength: 600)
        case .wordDocument:
            extractedText = await extractFromWordDocument(fileURL)
        default:
            extractedText = "Content extraction not supported for this file type."
        }
        
        return AttachmentContent(
            filename: filename,
            mimeType: mimeType,
            extractedText: extractedText,
            documentType: documentType,
            metadata: metadata
        )
    }
    
    private func inferMimeType(from filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        
        switch ext {
        case "pdf": return "application/pdf"
        case "doc": return "application/msword"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "txt": return "text/plain"
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "xls": return "application/vnd.ms-excel"
        case "xlsx": return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        default: return "application/octet-stream"
        }
    }
    
    private func inferDocumentType(from mimeType: String) -> DocumentType {
        switch mimeType {
        case "application/pdf":
            return .pdf
        case let type where type.hasPrefix("image/"):
            return .image
        case "text/plain":
            return .text
        case let type where type.contains("word"):
            return .wordDocument
        case let type where type.contains("spreadsheet") || type.contains("excel"):
            return .spreadsheet
        default:
            return .unknown
        }
    }
    
    private func extractFromPDF(_ fileURL: URL, maxLength: Int = 1500) async -> (String, [String: Any]) {
        guard let document = PDFDocument(url: fileURL) else {
            return ("Could not read PDF document", [:])
        }
        
        var fullText = ""
        var metadata: [String: Any] = [:]
        
        // Extract metadata
        if let title = document.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String {
            metadata["title"] = title
        }
        if let author = document.documentAttributes?[PDFDocumentAttribute.authorAttribute] as? String {
            metadata["author"] = author
        }
        
        // Extract text from pages, but limit total length for context window
        let maxPages = min(document.pageCount, 3) // Limit to first 3 pages
        for pageIndex in 0..<maxPages {
            if let page = document.page(at: pageIndex) {
                if let pageText = page.string {
                    fullText += pageText + "\n"
                    
                    // Stop if we've reached our length limit
                    if fullText.count > maxLength {
                        fullText = String(fullText.prefix(maxLength)) + "... [truncated]"
                        break
                    }
                }
            }
        }
        
        metadata["pageCount"] = document.pageCount
        metadata["pagesProcessed"] = maxPages
        return (fullText, metadata)
    }
    
    private func extractFromImage(_ fileURL: URL, maxLength: Int = 1000) async -> String {
        guard let image = NSImage(contentsOf: fileURL) else {
            return "Could not read image file"
        }
        
        // Convert NSImage to CGImage
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return "Could not process image"
        }
        
        // Use Vision framework for OCR
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        let handler = VNImageRequestHandler(cgImage: cgImage)
        
        do {
            try handler.perform([request])
            
            var extractedText = ""
            for observation in request.results ?? [] {
                extractedText += observation.topCandidates(1).first?.string ?? ""
                extractedText += "\n"
                
                // Limit text length for context window
                if extractedText.count > maxLength {
                    extractedText = String(extractedText.prefix(maxLength)) + "... [truncated]"
                    break
                }
            }
            
            return extractedText.isEmpty ? "No text found in image" : extractedText
        } catch {
            return "OCR failed: \(error.localizedDescription)"
        }
    }
    
    private func extractFromTextFile(_ fileURL: URL, maxLength: Int = 1000) -> String {
        do {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            
            // Limit content length for context window
            if content.count > maxLength {
                return String(content.prefix(maxLength)) + "... [truncated]"
            }
            
            return content
        } catch {
            return "Could not read text file: \(error.localizedDescription)"
        }
    }
    
    private func extractFromWordDocument(_ fileURL: URL) async -> String {
        // For Word documents, we'd need a more sophisticated approach
        // For now, return a placeholder
        return "Word document processing not yet implemented"
    }
}

// MARK: - Error Types

enum AITaskError: LocalizedError {
    case serviceUnavailable(String)
    case invalidResponse(String)
    case noTasksFound(String)
    case processingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .serviceUnavailable(let message): return "AI Service Unavailable: \(message)"
        case .invalidResponse(let message): return "Invalid Response: \(message)"
        case .noTasksFound(let message): return "No Tasks Found: \(message)"
        case .processingFailed(let message): return "Processing Failed: \(message)"
        }
    }
}
