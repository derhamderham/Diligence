//
//  AIServiceProtocol.swift
//  Diligence
//
//  Protocol definitions for AI service implementations
//

import Foundation

// MARK: - AI Service Protocol

/// Protocol defining the contract for AI service implementations
///
/// AI services provide natural language processing capabilities for
/// analyzing emails, generating tasks, and providing intelligent suggestions.
///
/// ## Topics
///
/// ### Availability
/// - ``isAvailable``
/// - ``checkAvailability()``
///
/// ### Task Generation
/// - ``generateTasks(from:preferences:)``
/// - ``generateTask(from:)``
///
/// ### Content Analysis
/// - ``summarizeEmail(_:)``
/// - ``extractActionItems(from:)``
/// - ``classifyEmail(_:)``
///
/// ### Configuration
/// - ``configure(_:)``
@MainActor
protocol AIServiceProtocol: AnyObject {
    /// The AI provider type
    var provider: AIProvider { get }
    
    /// Whether the service is currently available
    var isAvailable: Bool { get }
    
    /// Current service status
    var status: AIServiceStatus { get }
    
    /// Configures the AI service with necessary settings
    ///
    /// - Parameter configuration: The AI service configuration
    /// - Throws: ``AIServiceError`` if configuration fails
    func configure(_ configuration: AIServiceConfiguration) throws
    
    /// Checks if the AI service is available and ready
    ///
    /// - Returns: `true` if the service is available
    func checkAvailability() async -> Bool
    
    /// Generates tasks from a collection of emails
    ///
    /// - Parameters:
    ///   - emails: The emails to analyze
    ///   - preferences: User preferences for task generation
    /// - Returns: An array of generated tasks
    /// - Throws: ``AIServiceError`` if generation fails
    func generateTasks(
        from emails: [ProcessedEmail],
        preferences: TaskGenerationPreferences?
    ) async throws -> [GeneratedTask]
    
    /// Generates a single task from an email
    ///
    /// - Parameter email: The email to analyze
    /// - Returns: A generated task
    /// - Throws: ``AIServiceError`` if generation fails
    func generateTask(from email: ProcessedEmail) async throws -> GeneratedTask
    
    /// Summarizes an email's content
    ///
    /// - Parameter email: The email to summarize
    /// - Returns: A brief summary of the email
    /// - Throws: ``AIServiceError`` if summarization fails
    func summarizeEmail(_ email: ProcessedEmail) async throws -> String
    
    /// Extracts action items from email content
    ///
    /// - Parameter email: The email to analyze
    /// - Returns: A list of action items
    /// - Throws: ``AIServiceError`` if extraction fails
    func extractActionItems(from email: ProcessedEmail) async throws -> ActionItemList
    
    /// Classifies an email by category
    ///
    /// - Parameter email: The email to classify
    /// - Returns: The email category
    /// - Throws: ``AIServiceError`` if classification fails
    func classifyEmail(_ email: ProcessedEmail) async throws -> EmailCategoryResult
}

// MARK: - AI Service Configuration

/// Configuration settings for AI services
struct AIServiceConfiguration {
    /// Service-specific configuration
    let provider: AIProvider
    
    /// API base URL (for remote services)
    let baseURL: String?
    
    /// API key or authentication token
    let apiKey: String?
    
    /// Model identifier to use
    let modelId: String?
    
    /// LLM parameters
    let llmConfiguration: LLMRequestConfiguration
    
    /// Request timeout in seconds
    let timeout: TimeInterval
    
    /// Enable streaming responses
    let streamingEnabled: Bool
    
    /// Enable debug logging
    let debugLogging: Bool
    
    /// Default configuration for Apple Intelligence
    static let appleIntelligence = AIServiceConfiguration(
        provider: .appleIntelligence,
        baseURL: nil,
        apiKey: nil,
        modelId: nil,
        llmConfiguration: .taskGeneration,
        timeout: 30,
        streamingEnabled: false,
        debugLogging: false
    )
    
    /// Default configuration for Jan.ai
    static func janAI(baseURL: String, model: String) -> AIServiceConfiguration {
        return AIServiceConfiguration(
            provider: .janAI,
            baseURL: baseURL,
            apiKey: nil,
            modelId: model,
            llmConfiguration: .taskGeneration,
            timeout: 120,
            streamingEnabled: true,
            debugLogging: true
        )
    }
}

// MARK: - AI Service Error

/// Errors that can occur during AI service operations
enum AIServiceError: LocalizedError {
    /// Service is not available
    case notAvailable
    
    /// Service is not configured
    case notConfigured
    
    /// Model not loaded or not found
    case modelNotFound(String)
    
    /// Invalid request parameters
    case invalidRequest(String)
    
    /// Network request failed
    case networkError(Error)
    
    /// Invalid response from service
    case invalidResponse
    
    /// Server returned an error
    case serverError(statusCode: Int, message: String?)
    
    /// Rate limit exceeded
    case rateLimitExceeded(retryAfter: TimeInterval?)
    
    /// Token limit exceeded
    case tokenLimitExceeded(limit: Int, actual: Int)
    
    /// Service timeout
    case timeout
    
    /// Content filtering triggered
    case contentFiltered(String)
    
    /// Insufficient system resources
    case insufficientResources
    
    /// Unknown error
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "AI service is not available. Please check system requirements."
        case .notConfigured:
            return "AI service is not configured. Please configure the service before use."
        case .modelNotFound(let model):
            return "AI model '\(model)' not found or not loaded."
        case .invalidRequest(let message):
            return "Invalid request: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from AI service."
        case .serverError(let statusCode, let message):
            let msg = message ?? "Unknown server error"
            return "Server error (\(statusCode)): \(msg)"
        case .rateLimitExceeded(let retryAfter):
            if let retry = retryAfter {
                return "Rate limit exceeded. Try again in \(Int(retry)) seconds."
            }
            return "Rate limit exceeded. Please try again later."
        case .tokenLimitExceeded(let limit, let actual):
            return "Token limit exceeded: \(actual) tokens (limit: \(limit))."
        case .timeout:
            return "AI service request timed out."
        case .contentFiltered(let reason):
            return "Content was filtered: \(reason)"
        case .insufficientResources:
            return "Insufficient system resources to process request."
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .notAvailable:
            return "Check that your device supports AI features and that they are enabled in System Settings."
        case .notConfigured:
            return "Configure the AI service in Settings."
        case .modelNotFound:
            return "Select a different model or ensure the model is downloaded and loaded."
        case .tokenLimitExceeded:
            return "Reduce the amount of content in your request."
        case .timeout:
            return "Try again with a smaller request or increase the timeout."
        case .rateLimitExceeded:
            return "Wait a few moments before making another request."
        default:
            return "Please try again or contact support if the problem persists."
        }
    }
}

// MARK: - Supporting Types

/// Email category classification result
enum EmailCategoryResult: String, Codable, CaseIterable {
    /// Actionable task or request
    case task
    
    /// Financial or billing related
    case financial
    
    /// Newsletter or promotional
    case newsletter
    
    /// Personal communication
    case personal
    
    /// Work or professional
    case work
    
    /// Travel related
    case travel
    
    /// Shopping or order confirmation
    case shopping
    
    /// Social network notification
    case social
    
    /// Spam or unwanted
    case spam
    
    /// Other or unknown
    case other
    
    /// Human-readable name
    var displayName: String {
        switch self {
        case .task: return "Task"
        case .financial: return "Financial"
        case .newsletter: return "Newsletter"
        case .personal: return "Personal"
        case .work: return "Work"
        case .travel: return "Travel"
        case .shopping: return "Shopping"
        case .social: return "Social"
        case .spam: return "Spam"
        case .other: return "Other"
        }
    }
    
    /// SF Symbol icon
    var icon: String {
        switch self {
        case .task: return "checklist"
        case .financial: return "dollarsign.circle"
        case .newsletter: return "envelope.open"
        case .personal: return "person"
        case .work: return "briefcase"
        case .travel: return "airplane"
        case .shopping: return "cart"
        case .social: return "bubble.left.and.bubble.right"
        case .spam: return "trash"
        case .other: return "questionmark.circle"
        }
    }
}

// MARK: - AI Context Protocol

/// Protocol for managing AI conversation context
protocol AIContextProtocol {
    /// Adds a message to the context
    ///
    /// - Parameter message: The message to add
    func addMessage(_ message: AIMessage)
    
    /// Clears the context history
    func clearContext()
    
    /// Gets the current context as a formatted string
    ///
    /// - Returns: The formatted context
    func getFormattedContext() -> String
    
    /// Token count for current context
    var tokenCount: Int { get }
}

/// A message in an AI conversation
struct AIMessage: Codable {
    /// The role of the message sender
    let role: AIMessageRole
    
    /// The message content
    let content: String
    
    /// Timestamp when the message was created
    let timestamp: Date
}

/// Role of a message in an AI conversation
enum AIMessageRole: String, Codable {
    /// System prompt or instruction
    case system
    
    /// User input
    case user
    
    /// AI assistant response
    case assistant
}

// MARK: - AI Analytics Protocol

/// Protocol for tracking AI service usage and performance
protocol AIAnalyticsProtocol {
    /// Records a successful AI request
    ///
    /// - Parameters:
    ///   - provider: The AI provider used
    ///   - tasksGenerated: Number of tasks generated
    ///   - averageConfidence: Average confidence score
    ///   - duration: Request duration in seconds
    func recordSuccess(
        provider: AIProvider,
        tasksGenerated: Int,
        averageConfidence: Double,
        duration: TimeInterval
    )
    
    /// Records a failed AI request
    ///
    /// - Parameters:
    ///   - provider: The AI provider used
    ///   - error: The error that occurred
    func recordFailure(provider: AIProvider, error: AIServiceError)
    
    /// Gets current analytics data
    ///
    /// - Returns: The analytics data
    func getAnalytics() -> AIAnalytics
    
    /// Resets analytics data
    func resetAnalytics()
}
