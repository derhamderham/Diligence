//
//  LogFormatter.swift
//  Diligence
//
//  Log message formatting
//

import Foundation
import Combine

/// Protocol for formatting log messages
protocol LogFormatter {
    /// Format a log entry
    func format(_ entry: LogEntry) -> String
}

/// Log entry containing all information about a log message
struct LogEntry: Codable {
    /// Timestamp of the log
    let timestamp: Date
    
    /// Log level
    let level: LogLevel
    
    /// Log category
    let category: LogCategory
    
    /// The log message
    let message: String
    
    /// Additional metadata
    let metadata: [String: String]?
    
    /// Source file name
    let file: String
    
    /// Function name
    let function: String
    
    /// Line number
    let line: Int
    
    /// Thread name/ID
    let thread: String
    
    /// App version
    let appVersion: String
    
    /// Build number
    let buildNumber: String
    
    init(
        timestamp: Date = Date(),
        level: LogLevel,
        category: LogCategory,
        message: String,
        metadata: [String: String]? = nil,
        file: String,
        function: String,
        line: Int
    ) {
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.message = message
        self.metadata = metadata
        self.file = (file as NSString).lastPathComponent
        self.function = function
        self.line = line
        
        // Capture thread information
        if Thread.isMainThread {
            self.thread = "main"
        } else {
            self.thread = Thread.current.name ?? "unknown"
        }
        
        // Capture app version
        let info = Bundle.main.infoDictionary
        self.appVersion = info?["CFBundleShortVersionString"] as? String ?? "unknown"
        self.buildNumber = info?["CFBundleVersion"] as? String ?? "unknown"
    }
}

// MARK: - Standard Formatter

/// Standard log formatter with all details
class StandardLogFormatter: LogFormatter {
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
    
    func format(_ entry: LogEntry) -> String {
        let timestamp = dateFormatter.string(from: entry.timestamp)
        let level = entry.level.shortName
        let category = entry.category.rawValue
        let location = "\(entry.file):\(entry.line)"
        
        var components = [
            "[\(timestamp)]",
            "[\(level)]",
            "[\(category)]",
            "[\(entry.thread)]",
            entry.message,
            "(\(location))"
        ]
        
        // Add metadata if present
        if let metadata = entry.metadata, !metadata.isEmpty {
            let metadataString = metadata.map { "\($0)=\($1)" }.joined(separator: ", ")
            components.insert("{\(metadataString)}", at: components.count - 1)
        }
        
        return components.joined(separator: " ")
    }
}

// MARK: - Compact Formatter

/// Compact formatter for console output
class CompactLogFormatter: LogFormatter {
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
    
    func format(_ entry: LogEntry) -> String {
        let timestamp = dateFormatter.string(from: entry.timestamp)
        let emoji = entry.level.emoji
        let categoryIcon = entry.category.icon
        
        return "\(emoji) [\(timestamp)] \(categoryIcon) \(entry.message)"
    }
}

// MARK: - JSON Formatter

/// JSON formatter for structured logging
class JSONLogFormatter: LogFormatter {
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()
    
    func format(_ entry: LogEntry) -> String {
        guard let data = try? encoder.encode(entry),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }
}

// MARK: - Production Formatter

/// Production formatter (minimal, no file/line info)
class ProductionLogFormatter: LogFormatter {
    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    func format(_ entry: LogEntry) -> String {
        let timestamp = dateFormatter.string(from: entry.timestamp)
        let level = entry.level.name
        let category = entry.category.rawValue
        
        var components = [
            timestamp,
            level,
            category,
            entry.message
        ]
        
        // Add metadata in production
        if let metadata = entry.metadata, !metadata.isEmpty {
            let metadataString = metadata.map { "\($0)=\($1)" }.joined(separator: " ")
            components.append(metadataString)
        }
        
        return components.joined(separator: " | ")
    }
}

// MARK: - Privacy Utilities

/// Utilities for handling sensitive data in logs
enum LogPrivacyUtilities {
    
    /// Redact sensitive information
    static func redact(_ value: String, privacy: LogPrivacy) -> String {
        switch privacy {
        case .public:
            return value
        case .private:
            return hash(value)
        case .sensitive:
            return "<redacted>"
        case .auto:
            return autoRedact(value)
        }
    }
    
    /// Hash a value for privacy
    private static func hash(_ value: String) -> String {
        let hash = value.hashValue
        return "<hash:\(abs(hash))>"
    }
    
    /// Auto-detect and redact sensitive patterns
    private static func autoRedact(_ value: String) -> String {
        var redacted = value
        
        // Email addresses
        if value.contains("@") && value.contains(".") {
            redacted = redactEmail(value)
        }
        
        // API keys/tokens (common patterns)
        if value.count > 20 && (value.contains("key") || value.contains("token") || value.contains("secret")) {
            return "<redacted-credential>"
        }
        
        // Credit card numbers
        redacted = redactCreditCard(redacted)
        
        // Phone numbers
        redacted = redactPhoneNumber(redacted)
        
        return redacted
    }
    
    private static func redactEmail(_ email: String) -> String {
        let components = email.split(separator: "@")
        guard components.count == 2 else { return "<email>" }
        let username = components[0]
        let domain = components[1]
        
        // Show first and last character of username
        if username.count > 2 {
            return "\(username.first!)***\(username.last!)@\(domain)"
        }
        return "***@\(domain)"
    }
    
    private static func redactCreditCard(_ text: String) -> String {
        // Match common credit card patterns
        let pattern = #"\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b"#
        return text.replacingOccurrences(
            of: pattern,
            with: "****-****-****-****",
            options: .regularExpression
        )
    }
    
    private static func redactPhoneNumber(_ text: String) -> String {
        // Match common phone patterns
        let pattern = #"\b\d{3}[-.\s]?\d{3}[-.\s]?\d{4}\b"#
        return text.replacingOccurrences(
            of: pattern,
            with: "***-***-****",
            options: .regularExpression
        )
    }
}

// MARK: - Helper Extensions

extension String {
    /// Apply privacy redaction to string
    func redacted(privacy: LogPrivacy = .auto) -> String {
        LogPrivacyUtilities.redact(self, privacy: privacy)
    }
}
