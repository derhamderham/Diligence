//
//  AppError.swift
//  Diligence
//
//  Unified error type for the entire application
//

import Foundation

/// Unified error type for the Diligence application
///
/// `AppError` provides a centralized, type-safe way to handle all errors
/// throughout the app. It includes user-friendly messages, recovery suggestions,
/// and categorization for proper handling and analytics.
///
/// ## Topics
///
/// ### Error Categories
/// - ``network(_:)``
/// - ``authentication(_:)``
/// - ``database(_:)``
/// - ``service(_:)``
/// - ``validation(_:)``
/// - ``system(_:)``
///
/// ### Error Properties
/// - ``errorDescription``
/// - ``recoverySuggestion``
/// - ``failureReason``
/// - ``helpAnchor``
enum AppError: LocalizedError, Equatable {
    
    // MARK: - Network Errors
    
    case network(NetworkError)
    
    enum NetworkError: Equatable {
        case noConnection
        case timeout
        case serverError(statusCode: Int)
        case invalidResponse
        case rateLimitExceeded(retryAfter: TimeInterval?)
        case unknownNetworkError
    }
    
    // MARK: - Authentication Errors
    
    case authentication(AuthenticationError)
    
    enum AuthenticationError: Equatable {
        case notAuthenticated
        case invalidCredentials
        case tokenExpired
        case tokenRefreshFailed
        case authorizationDenied
        case oauthFlowFailed(reason: String)
        case missingClientConfiguration
    }
    
    // MARK: - Database Errors
    
    case database(DatabaseError)
    
    enum DatabaseError: Equatable {
        case migrationFailed
        case corruptedDatabase
        case diskFull
        case accessDenied
        case queryFailed
        case saveFailure
        case deleteFailure
        case contextCreationFailed
        case sqliteError(code: Int)
    }
    
    // MARK: - Service Errors
    
    case service(ServiceError)
    
    enum ServiceError: Equatable {
        // Email service errors
        case emailServiceNotConfigured
        case emailFetchFailed
        case emailMessageNotFound(id: String)
        case attachmentDownloadFailed
        
        // LLM service errors
        case llmNotAvailable
        case llmQueryFailed
        case llmModelNotFound(model: String)
        case llmContextWindowExceeded
        case llmConnectionFailed
        
        // Apple Intelligence errors
        case appleIntelligenceUnavailable(reason: String)
        case aiGenerationFailed
        case aiContextTooLarge
        
        // Reminders service errors
        case remindersNotAuthorized
        case remindersSyncFailed
        case remindersListNotFound
        case remindersXPCConnectionFailed
        
        // Recurring task errors
        case recurringTaskGenerationFailed
        case invalidRecurrencePattern
        
        // Generic service errors
        case serviceUnavailable(name: String)
        case serviceTimeout(name: String)
    }
    
    // MARK: - Validation Errors
    
    case validation(ValidationError)
    
    enum ValidationError: Equatable {
        case emptyField(fieldName: String)
        case invalidFormat(fieldName: String, expectedFormat: String)
        case valueTooLong(fieldName: String, maxLength: Int)
        case valueTooShort(fieldName: String, minLength: Int)
        case invalidEmail
        case invalidURL
        case invalidDate
        case outOfRange(fieldName: String, min: Double, max: Double)
    }
    
    // MARK: - System Errors
    
    case system(SystemError)
    
    enum SystemError: Equatable {
        case permissionDenied(permission: String)
        case resourceNotFound(resource: String)
        case operationCancelled
        case backgroundTaskExpired
        case memoryWarning
        case diskSpaceWarning
        case unknownError
    }
    
    // MARK: - User-Facing Errors
    
    case userFacing(UserFacingError)
    
    enum UserFacingError: Equatable {
        case featureNotAvailable(feature: String)
        case actionNotAllowed(reason: String)
        case quotaExceeded(quotaType: String)
        case upgradRequired(feature: String)
    }
    
    // MARK: - LocalizedError Conformance
    
    var errorDescription: String? {
        switch self {
        // Network errors
        case .network(.noConnection):
            return "No Internet Connection"
        case .network(.timeout):
            return "Request Timed Out"
        case .network(.serverError(let statusCode)):
            return "Server Error (\(statusCode))"
        case .network(.invalidResponse):
            return "Invalid Response from Server"
        case .network(.rateLimitExceeded):
            return "Rate Limit Exceeded"
        case .network(.unknownNetworkError):
            return "Network Error"
            
        // Authentication errors
        case .authentication(.notAuthenticated):
            return "Not Signed In"
        case .authentication(.invalidCredentials):
            return "Invalid Credentials"
        case .authentication(.tokenExpired):
            return "Session Expired"
        case .authentication(.tokenRefreshFailed):
            return "Failed to Refresh Session"
        case .authentication(.authorizationDenied):
            return "Authorization Denied"
        case .authentication(.oauthFlowFailed):
            return "Sign In Failed"
        case .authentication(.missingClientConfiguration):
            return "App Not Configured"
            
        // Database errors
        case .database(.migrationFailed):
            return "Database Migration Failed"
        case .database(.corruptedDatabase):
            return "Database Corrupted"
        case .database(.diskFull):
            return "Storage Full"
        case .database(.accessDenied):
            return "Database Access Denied"
        case .database(.queryFailed):
            return "Database Query Failed"
        case .database(.saveFailure):
            return "Failed to Save Data"
        case .database(.deleteFailure):
            return "Failed to Delete Data"
        case .database(.contextCreationFailed):
            return "Database Initialization Failed"
        case .database(.sqliteError(let code)):
            return "Database Error (\(code))"
            
        // Service errors
        case .service(.emailServiceNotConfigured):
            return "Email Service Not Configured"
        case .service(.emailFetchFailed):
            return "Failed to Fetch Emails"
        case .service(.emailMessageNotFound):
            return "Email Not Found"
        case .service(.attachmentDownloadFailed):
            return "Failed to Download Attachment"
        case .service(.llmNotAvailable):
            return "AI Service Unavailable"
        case .service(.llmQueryFailed):
            return "AI Query Failed"
        case .service(.llmModelNotFound(let model)):
            return "AI Model '\(model)' Not Found"
        case .service(.llmContextWindowExceeded):
            return "Content Too Large for AI"
        case .service(.llmConnectionFailed):
            return "Cannot Connect to AI Service"
        case .service(.appleIntelligenceUnavailable):
            return "Apple Intelligence Unavailable"
        case .service(.aiGenerationFailed):
            return "AI Generation Failed"
        case .service(.aiContextTooLarge):
            return "Content Too Large for AI"
        case .service(.remindersNotAuthorized):
            return "Reminders Access Denied"
        case .service(.remindersSyncFailed):
            return "Reminders Sync Failed"
        case .service(.remindersListNotFound):
            return "Reminders List Not Found"
        case .service(.remindersXPCConnectionFailed):
            return "Reminders Connection Failed"
        case .service(.recurringTaskGenerationFailed):
            return "Failed to Generate Recurring Tasks"
        case .service(.invalidRecurrencePattern):
            return "Invalid Recurrence Pattern"
        case .service(.serviceUnavailable(let name)):
            return "\(name) Service Unavailable"
        case .service(.serviceTimeout(let name)):
            return "\(name) Service Timed Out"
            
        // Validation errors
        case .validation(.emptyField(let fieldName)):
            return "\(fieldName) Cannot Be Empty"
        case .validation(.invalidFormat(let fieldName, _)):
            return "Invalid \(fieldName) Format"
        case .validation(.valueTooLong(let fieldName, let maxLength)):
            return "\(fieldName) Too Long (max \(maxLength) characters)"
        case .validation(.valueTooShort(let fieldName, let minLength)):
            return "\(fieldName) Too Short (min \(minLength) characters)"
        case .validation(.invalidEmail):
            return "Invalid Email Address"
        case .validation(.invalidURL):
            return "Invalid URL"
        case .validation(.invalidDate):
            return "Invalid Date"
        case .validation(.outOfRange(let fieldName, let min, let max)):
            return "\(fieldName) Must Be Between \(min) and \(max)"
            
        // System errors
        case .system(.permissionDenied(let permission)):
            return "\(permission) Permission Denied"
        case .system(.resourceNotFound(let resource)):
            return "\(resource) Not Found"
        case .system(.operationCancelled):
            return "Operation Cancelled"
        case .system(.backgroundTaskExpired):
            return "Background Task Expired"
        case .system(.memoryWarning):
            return "Low Memory Warning"
        case .system(.diskSpaceWarning):
            return "Low Disk Space"
        case .system(.unknownError):
            return "Unknown Error Occurred"
            
        // User-facing errors
        case .userFacing(.featureNotAvailable(let feature)):
            return "\(feature) Not Available"
        case .userFacing(.actionNotAllowed(let reason)):
            return "Action Not Allowed: \(reason)"
        case .userFacing(.quotaExceeded(let quotaType)):
            return "\(quotaType) Quota Exceeded"
        case .userFacing(.upgradRequired(let feature)):
            return "Upgrade Required for \(feature)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        // Network errors
        case .network(.noConnection):
            return "Check your internet connection and try again."
        case .network(.timeout):
            return "The server is taking too long to respond. Try again in a moment."
        case .network(.serverError):
            return "The server encountered an error. Please try again later."
        case .network(.invalidResponse):
            return "The server returned invalid data. Please try again."
        case .network(.rateLimitExceeded(let retryAfter)):
            if let retry = retryAfter {
                let minutes = Int(retry / 60)
                return minutes > 0 ? "Please wait \(minutes) minute(s) before trying again." : "Please wait a moment before trying again."
            }
            return "You've made too many requests. Please wait before trying again."
        case .network(.unknownNetworkError):
            return "Check your connection and try again."
            
        // Authentication errors
        case .authentication(.notAuthenticated):
            return "Please sign in to continue."
        case .authentication(.invalidCredentials):
            return "Check your credentials and try signing in again."
        case .authentication(.tokenExpired):
            return "Your session has expired. Please sign in again."
        case .authentication(.tokenRefreshFailed):
            return "Please sign out and sign in again."
        case .authentication(.authorizationDenied):
            return "Grant the necessary permissions in System Settings."
        case .authentication(.oauthFlowFailed(let reason)):
            return "Sign in failed: \(reason). Please try again."
        case .authentication(.missingClientConfiguration):
            return "The app needs to be configured with proper credentials. Contact support."
            
        // Database errors
        case .database(.migrationFailed):
            return "Database upgrade failed. You may need to restart the app or reset your data."
        case .database(.corruptedDatabase):
            return "Your database is corrupted. Consider backing up data and resetting the database."
        case .database(.diskFull):
            return "Free up disk space on your device to continue."
        case .database(.accessDenied):
            return "Check app permissions in System Settings."
        case .database(.queryFailed):
            return "Failed to retrieve data. Try restarting the app."
        case .database(.saveFailure):
            return "Failed to save your changes. Try again or check available storage."
        case .database(.deleteFailure):
            return "Failed to delete. Try again or restart the app."
        case .database(.contextCreationFailed):
            return "Failed to initialize database. Try restarting the app."
        case .database(.sqliteError):
            return "Database error occurred. Restart the app or reset your data."
            
        // Service errors
        case .service(.emailServiceNotConfigured):
            return "Configure your Gmail credentials in Settings."
        case .service(.emailFetchFailed):
            return "Check your connection and try again. Make sure you're signed in."
        case .service(.emailMessageNotFound):
            return "This email may have been deleted or moved."
        case .service(.attachmentDownloadFailed):
            return "Check your connection and try downloading again."
        case .service(.llmNotAvailable):
            return "Make sure your LLM service (Jan.ai) is running and accessible."
        case .service(.llmQueryFailed):
            return "Check your LLM service connection and try again."
        case .service(.llmModelNotFound(let model)):
            return "Make sure '\(model)' is loaded in your LLM service."
        case .service(.llmContextWindowExceeded):
            return "Try with fewer emails or shorter content."
        case .service(.llmConnectionFailed):
            return "Ensure Jan.ai or your LLM service is running at the configured URL."
        case .service(.appleIntelligenceUnavailable(let reason)):
            return reason.isEmpty ? "Apple Intelligence is not available on this device." : reason
        case .service(.aiGenerationFailed):
            return "AI processing failed. Try again or use a different AI service."
        case .service(.aiContextTooLarge):
            return "Reduce the amount of content and try again."
        case .service(.remindersNotAuthorized):
            return "Grant Reminders access in System Settings > Privacy & Security > Calendars."
        case .service(.remindersSyncFailed):
            return "Check Reminders permissions and try syncing again."
        case .service(.remindersListNotFound):
            return "The Reminders list may have been deleted. Try creating it again."
        case .service(.remindersXPCConnectionFailed):
            return "Restart the app or your Mac. If the problem persists, check system permissions."
        case .service(.recurringTaskGenerationFailed):
            return "Check your recurring task pattern and try again."
        case .service(.invalidRecurrencePattern):
            return "Review your recurrence settings and correct any invalid values."
        case .service(.serviceUnavailable(let name)):
            return "\(name) is currently unavailable. Try again later."
        case .service(.serviceTimeout(let name)):
            return "\(name) took too long to respond. Try again."
            
        // Validation errors
        case .validation(.emptyField):
            return "Please fill in this required field."
        case .validation(.invalidFormat(_, let expectedFormat)):
            return "Expected format: \(expectedFormat)"
        case .validation(.valueTooLong(_, let maxLength)):
            return "Shorten to \(maxLength) characters or less."
        case .validation(.valueTooShort(_, let minLength)):
            return "Enter at least \(minLength) characters."
        case .validation(.invalidEmail):
            return "Enter a valid email address (e.g., user@example.com)."
        case .validation(.invalidURL):
            return "Enter a valid URL (e.g., https://example.com)."
        case .validation(.invalidDate):
            return "Select a valid date."
        case .validation(.outOfRange(_, let min, let max)):
            return "Enter a value between \(min) and \(max)."
            
        // System errors
        case .system(.permissionDenied(let permission)):
            return "Grant \(permission) permission in System Settings."
        case .system(.resourceNotFound):
            return "The requested resource could not be found."
        case .system(.operationCancelled):
            return "You cancelled this operation."
        case .system(.backgroundTaskExpired):
            return "This operation took too long in the background."
        case .system(.memoryWarning):
            return "Close some apps to free up memory."
        case .system(.diskSpaceWarning):
            return "Free up disk space by deleting unnecessary files."
        case .system(.unknownError):
            return "An unexpected error occurred. Try restarting the app."
            
        // User-facing errors
        case .userFacing(.featureNotAvailable):
            return "This feature is not available on your current plan or device."
        case .userFacing(.actionNotAllowed):
            return "You don't have permission to perform this action."
        case .userFacing(.quotaExceeded):
            return "You've reached your quota limit. Upgrade or wait for the next period."
        case .userFacing(.upgradRequired):
            return "Upgrade to a premium plan to access this feature."
        }
    }
    
    var failureReason: String? {
        switch self {
        case .network(.noConnection):
            return "No active internet connection detected."
        case .network(.timeout):
            return "The request exceeded the timeout limit."
        case .network(.serverError(let statusCode)):
            return "Server returned status code \(statusCode)."
        case .network(.invalidResponse):
            return "The server response could not be parsed."
        case .authentication(.tokenExpired):
            return "Your authentication token has expired."
        case .database(.corruptedDatabase):
            return "The database file is corrupted or invalid."
        case .database(.diskFull):
            return "Insufficient disk space available."
        case .service(.llmNotAvailable):
            return "The LLM service could not be reached."
        case .service(.remindersNotAuthorized):
            return "The app doesn't have permission to access Reminders."
        default:
            return nil
        }
    }
    
    var helpAnchor: String? {
        switch self {
        case .authentication:
            return "authentication-help"
        case .service(.emailServiceNotConfigured),
             .service(.emailFetchFailed):
            return "gmail-setup-guide"
        case .service(.llmNotAvailable),
             .service(.llmConnectionFailed):
            return "llm-setup-guide"
        case .service(.remindersNotAuthorized),
             .service(.remindersSyncFailed):
            return "reminders-permissions"
        case .database:
            return "database-troubleshooting"
        default:
            return nil
        }
    }
    
    // MARK: - Error Metadata
    
    /// Severity level for error reporting and UI presentation
    var severity: ErrorSeverity {
        switch self {
        case .validation:
            return .warning
        case .network(.noConnection),
             .network(.timeout):
            return .warning
        case .authentication(.notAuthenticated):
            return .info
        case .database(.corruptedDatabase),
             .database(.migrationFailed):
            return .critical
        case .system(.memoryWarning),
             .system(.diskSpaceWarning):
            return .warning
        default:
            return .error
        }
    }
    
    /// Category for analytics and error grouping
    var category: ErrorCategory {
        switch self {
        case .network:
            return .network
        case .authentication:
            return .authentication
        case .database:
            return .database
        case .service:
            return .service
        case .validation:
            return .validation
        case .system:
            return .system
        case .userFacing:
            return .userFacing
        }
    }
    
    /// Whether this error should be reported to analytics
    var shouldReport: Bool {
        switch self {
        case .validation,
             .authentication(.notAuthenticated),
             .system(.operationCancelled):
            return false
        default:
            return true
        }
    }
    
    /// Whether this error can be retried
    var isRetryable: Bool {
        switch self {
        case .network(.noConnection),
             .network(.timeout),
             .network(.serverError),
             .service(.emailFetchFailed),
             .service(.llmQueryFailed),
             .service(.remindersSyncFailed),
             .database(.saveFailure),
             .database(.queryFailed):
            return true
        case .authentication(.tokenExpired),
             .authentication(.tokenRefreshFailed):
            return true
        default:
            return false
        }
    }
}

// MARK: - Supporting Types

/// Error severity levels
enum ErrorSeverity: String, Codable {
    case info = "info"
    case warning = "warning"
    case error = "error"
    case critical = "critical"
}

/// Error categories for grouping
enum ErrorCategory: String, Codable {
    case network = "network"
    case authentication = "authentication"
    case database = "database"
    case service = "service"
    case validation = "validation"
    case system = "system"
    case userFacing = "user_facing"
}

// MARK: - Error Conversion Extensions

extension AppError {
    
    /// Convert from EmailServiceError
    static func from(_ error: EmailServiceError) -> AppError {
        switch error {
        case .notConfigured:
            return .service(.emailServiceNotConfigured)
        case .notAuthenticated:
            return .authentication(.notAuthenticated)
        case .authenticationFailed(let message):
            return .authentication(.oauthFlowFailed(reason: message))
        case .tokenRefreshFailed:
            return .authentication(.tokenRefreshFailed)
        case .networkError:
            return .network(.unknownNetworkError)
        case .invalidResponse:
            return .network(.invalidResponse)
        case .serverError(let statusCode, _):
            return .network(.serverError(statusCode: statusCode))
        case .messageNotFound(let id):
            return .service(.emailMessageNotFound(id: id))
        case .attachmentNotFound:
            return .service(.attachmentDownloadFailed)
        case .rateLimitExceeded(let retryAfter):
            return .network(.rateLimitExceeded(retryAfter: retryAfter))
        case .invalidConfiguration:
            return .authentication(.missingClientConfiguration)
        case .unknown:
            return .system(.unknownError)
        }
    }
    
    /// Convert from NSError
    static func from(_ error: NSError) -> AppError {
        switch error.domain {
        case NSURLErrorDomain:
            switch error.code {
            case NSURLErrorNotConnectedToInternet,
                 NSURLErrorNetworkConnectionLost:
                return .network(.noConnection)
            case NSURLErrorTimedOut:
                return .network(.timeout)
            default:
                return .network(.unknownNetworkError)
            }
        case NSCocoaErrorDomain:
            // CoreData and SQLite errors typically fall under NSCocoaErrorDomain
            if error.code >= 130000 && error.code < 140000 {
                // CoreData error codes range
                return .database(.sqliteError(code: error.code))
            }
            return .system(.unknownError)
        default:
            // Check for SQLite-specific error domain string
            if error.domain == "com.apple.coredata.sqlite" || error.domain.contains("sqlite") {
                return .database(.sqliteError(code: error.code))
            }
            return .system(.unknownError)
        }
    }
}
