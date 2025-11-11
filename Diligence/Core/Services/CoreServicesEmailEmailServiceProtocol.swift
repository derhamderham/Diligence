//
//  EmailServiceProtocol.swift
//  Diligence
//
//  Protocol definitions for email service implementations
//

import Foundation

// MARK: - Email Service Protocol

/// Protocol defining the contract for email service implementations
///
/// Email services are responsible for authenticating with email providers,
/// fetching messages, and managing email-related operations.
///
/// ## Topics
///
/// ### Authentication
/// - ``authenticate()``
/// - ``signOut()``
/// - ``refreshToken()``
/// - ``isAuthenticated``
///
/// ### Message Operations
/// - ``fetchMessages(query:maxResults:pageToken:)``
/// - ``getMessage(id:)``
/// - ``getAttachment(messageId:attachmentId:)``
///
/// ### Configuration
/// - ``configure(_:)``
protocol EmailServiceProtocol: AnyObject {
    /// The current authentication state
    var isAuthenticated: Bool { get }
    
    /// The user's email address (if authenticated)
    var userEmail: String? { get }
    
    /// Configures the service with necessary credentials and settings
    ///
    /// - Parameter configuration: The email service configuration
    /// - Throws: ``EmailServiceError`` if configuration fails
    func configure(_ configuration: EmailServiceConfiguration) throws
    
    /// Authenticates the user with the email service
    ///
    /// - Returns: The authenticated user's email address
    /// - Throws: ``EmailServiceError`` if authentication fails
    func authenticate() async throws -> String
    
    /// Signs out the current user
    ///
    /// - Throws: ``EmailServiceError`` if sign out fails
    func signOut() throws
    
    /// Refreshes the current authentication token
    ///
    /// - Returns: `true` if refresh was successful
    /// - Throws: ``EmailServiceError`` if refresh fails
    func refreshToken() async throws -> Bool
    
    /// Fetches messages from the email service
    ///
    /// - Parameters:
    ///   - query: Optional search query to filter messages
    ///   - maxResults: Maximum number of messages to fetch (default: 50)
    ///   - pageToken: Pagination token for fetching next page
    /// - Returns: A response containing messages and pagination info
    /// - Throws: ``EmailServiceError`` if fetch fails
    func fetchMessages(
        query: String?,
        maxResults: Int,
        pageToken: String?
    ) async throws -> GmailMessagesResponse
    
    /// Fetches a single message by ID
    ///
    /// - Parameter id: The message identifier
    /// - Returns: The complete message with all details
    /// - Throws: ``EmailServiceError`` if fetch fails
    func getMessage(id: String) async throws -> GmailMessage
    
    /// Downloads an attachment from a message
    ///
    /// - Parameters:
    ///   - messageId: The message containing the attachment
    ///   - attachmentId: The attachment identifier
    /// - Returns: The attachment data
    /// - Throws: ``EmailServiceError`` if download fails
    func getAttachment(messageId: String, attachmentId: String) async throws -> Data
}

// MARK: - Email Service Configuration

/// Configuration settings for email services
struct EmailServiceConfiguration {
    /// OAuth client ID
    let clientId: String
    
    /// OAuth client secret
    let clientSecret: String?
    
    /// Redirect URI for OAuth flow
    let redirectUri: String
    
    /// Required OAuth scopes
    let scopes: [String]
    
    /// API base URL
    let baseURL: String
    
    /// Default configuration for Gmail
    static let gmail = EmailServiceConfiguration(
        clientId: "", // Set from app config
        clientSecret: nil,
        redirectUri: "com.googleusercontent.apps.YOUR_CLIENT_ID:/oauth2redirect",
        scopes: [
            "https://www.googleapis.com/auth/gmail.readonly",
            "https://www.googleapis.com/auth/gmail.modify"
        ],
        baseURL: "https://gmail.googleapis.com/gmail/v1"
    )
}

// MARK: - Email Service Error

/// Errors that can occur during email service operations
enum EmailServiceError: LocalizedError {
    /// Service is not configured
    case notConfigured
    
    /// User is not authenticated
    case notAuthenticated
    
    /// Authentication failed
    case authenticationFailed(String)
    
    /// Token refresh failed
    case tokenRefreshFailed(String)
    
    /// Network request failed
    case networkError(Error)
    
    /// Invalid response from server
    case invalidResponse
    
    /// Server returned an error
    case serverError(statusCode: Int, message: String?)
    
    /// Message not found
    case messageNotFound(String)
    
    /// Attachment not found
    case attachmentNotFound(String)
    
    /// Rate limit exceeded
    case rateLimitExceeded(retryAfter: TimeInterval?)
    
    /// Invalid configuration
    case invalidConfiguration(String)
    
    /// Unknown error
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Email service is not configured. Please configure the service before use."
        case .notAuthenticated:
            return "You are not authenticated. Please sign in first."
        case .authenticationFailed(let message):
            return "Authentication failed: \(message)"
        case .tokenRefreshFailed(let message):
            return "Failed to refresh token: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server."
        case .serverError(let statusCode, let message):
            let msg = message ?? "Unknown server error"
            return "Server error (\(statusCode)): \(msg)"
        case .messageNotFound(let id):
            return "Message not found: \(id)"
        case .attachmentNotFound(let id):
            return "Attachment not found: \(id)"
        case .rateLimitExceeded(let retryAfter):
            if let retry = retryAfter {
                return "Rate limit exceeded. Try again in \(Int(retry)) seconds."
            }
            return "Rate limit exceeded. Please try again later."
        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .notConfigured:
            return "Configure the email service with valid credentials."
        case .notAuthenticated:
            return "Sign in with your email account."
        case .authenticationFailed:
            return "Check your credentials and try again."
        case .tokenRefreshFailed:
            return "Sign out and sign in again."
        case .networkError:
            return "Check your internet connection and try again."
        case .rateLimitExceeded:
            return "Wait a few moments before making another request."
        default:
            return "Please try again or contact support if the problem persists."
        }
    }
}

// MARK: - Email Processing Protocol

/// Protocol for processing and transforming email data
protocol EmailProcessingProtocol {
    /// Converts a raw Gmail message to a processed email
    ///
    /// - Parameter gmailMessage: The raw Gmail message
    /// - Returns: A processed email ready for display
    /// - Throws: ``EmailServiceError`` if processing fails
    func processEmail(_ gmailMessage: GmailMessage) throws -> ProcessedEmail
    
    /// Extracts task information from an email
    ///
    /// - Parameter email: The processed email
    /// - Returns: Suggested task properties
    func extractTaskInfo(from email: ProcessedEmail) -> TaskSuggestion
    
    /// Parses email headers to extract metadata
    ///
    /// - Parameter headers: Array of Gmail headers
    /// - Returns: Parsed email metadata
    func parseHeaders(_ headers: [GmailHeader]) -> EmailMetadata
}

// MARK: - Supporting Types

/// Task suggestion extracted from email
struct TaskSuggestion {
    /// Suggested task title
    let title: String
    
    /// Suggested task description
    let description: String
    
    /// Suggested due date (if any)
    let suggestedDueDate: Date?
    
    /// Detected priority level
    let priority: TaskPriority
    
    /// Source email ID
    let sourceEmailId: String
}

/// Email metadata parsed from headers
struct EmailMetadata {
    /// From address
    let from: String
    
    /// To addresses
    let to: [String]
    
    /// CC addresses
    let cc: [String]?
    
    /// Subject
    let subject: String
    
    /// Date
    let date: Date
    
    /// Message ID
    let messageId: String?
    
    /// In-Reply-To header
    let inReplyTo: String?
    
    /// References header
    let references: [String]?
}
