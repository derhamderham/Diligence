//
//  LogLevel.swift
//  Diligence
//
//  Log level definitions
//

import Foundation
import OSLog
import Combine

/// Log severity levels
///
/// Defines the severity of log messages, from verbose debug information
/// to critical errors that require immediate attention.
enum LogLevel: Int, Comparable, Codable, CaseIterable {
    /// Verbose debugging information
    /// - Use for detailed technical information during development
    /// - Disabled in production by default
    case debug = 0
    
    /// Informational messages
    /// - Use for general app flow and state changes
    /// - Enabled in production
    case info = 1
    
    /// Warning messages
    /// - Use for unexpected but recoverable situations
    /// - Always enabled
    case warning = 2
    
    /// Error messages
    /// - Use for errors that don't crash the app
    /// - Always enabled
    case error = 3
    
    /// Critical errors
    /// - Use for severe errors that may crash the app
    /// - Always enabled and always reported
    case critical = 4
    
    // MARK: - Display Properties
    
    /// Human-readable name
    var name: String {
        switch self {
        case .debug:
            return "DEBUG"
        case .info:
            return "INFO"
        case .warning:
            return "WARNING"
        case .error:
            return "ERROR"
        case .critical:
            return "CRITICAL"
        }
    }
    
    /// Short display name (for compact logging)
    var shortName: String {
        switch self {
        case .debug:
            return "DBG"
        case .info:
            return "INF"
        case .warning:
            return "WRN"
        case .error:
            return "ERR"
        case .critical:
            return "CRT"
        }
    }
    
    /// Emoji representation
    var emoji: String {
        switch self {
        case .debug:
            return "🔍"
        case .info:
            return "ℹ️"
        case .warning:
            return "⚠️"
        case .error:
            return "❌"
        case .critical:
            return "🚨"
        }
    }
    
    /// OSLog type mapping
    var osLogType: OSLogType {
        switch self {
        case .debug:
            return .debug
        case .info:
            return .info
        case .warning:
            return .default
        case .error:
            return .error
        case .critical:
            return .fault
        }
    }
    
    // MARK: - Comparable
    
    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Log categories for organizing logs
///
/// Categories help filter and search logs by subsystem.
enum LogCategory: String, Codable, CaseIterable {
    /// Network operations (API calls, downloads)
    case network = "network"
    
    /// Database operations (reads, writes, migrations)
    case database = "database"
    
    /// UI events and updates
    case ui = "ui"
    
    /// AI/ML operations (LLM, Apple Intelligence)
    case ai = "ai"
    
    /// Authentication and authorization
    case auth = "auth"
    
    /// Service operations (email, reminders, etc.)
    case service = "service"
    
    /// Application lifecycle
    case app = "app"
    
    /// Performance monitoring
    case performance = "performance"
    
    /// Error tracking
    case error = "error"
    
    /// General/uncategorized
    case general = "general"
    
    /// Human-readable display name
    var displayName: String {
        rawValue.capitalized
    }
    
    /// Icon/emoji for category
    var icon: String {
        switch self {
        case .network:
            return "🌐"
        case .database:
            return "💾"
        case .ui:
            return "🎨"
        case .ai:
            return "🤖"
        case .auth:
            return "🔐"
        case .service:
            return "⚙️"
        case .app:
            return "📱"
        case .performance:
            return "⚡️"
        case .error:
            return "❌"
        case .general:
            return "📋"
        }
    }
}

/// Log privacy level for sensitive data
///
/// Controls how sensitive information is handled in logs.
enum LogPrivacy {
    /// Public data (safe to log as-is)
    case `public`
    
    /// Private data (hash or redact)
    case `private`
    
    /// Sensitive data (always redact)
    case sensitive
    
    /// Auto-detect based on content
    case auto
}
