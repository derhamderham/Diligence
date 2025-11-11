//
//  LogDestination.swift
//  Diligence
//
//  Log destination implementations
//

import Foundation
import os

// MARK: - Analytics Types

/// Protocol for reporting analytics events
protocol AnalyticsReporter: Sendable {
    func report(_ event: AnalyticsEvent)
}

/// Represents an analytics event
struct AnalyticsEvent: Sendable {
    let name: String
    let parameters: [String: Any]
    let timestamp: Date
    
    init(name: String, parameters: [String: Any], timestamp: Date = Date()) {
        self.name = name
        self.parameters = parameters
        self.timestamp = timestamp
    }
}

// MARK: - Log Destinations

/// Protocol for log destinations
protocol LogDestination: Sendable {
    /// Write a log entry
    func write(_ entry: LogEntry)
    
    /// Minimum log level for this destination
    var minimumLevel: LogLevel { get set }
    
    /// Enabled state
    var isEnabled: Bool { get set }
}

// MARK: - Console Destination

/// Logs to console using OSLog
final class ConsoleLogDestination: LogDestination, @unchecked Sendable {
    var minimumLevel: LogLevel
    var isEnabled: Bool
    
    private let subsystem: String
    private let formatter: LogFormatter
    private var loggers: [String: os.Logger] = [:]
    
    init(
        subsystem: String = Bundle.main.bundleIdentifier ?? "com.diligence",
        minimumLevel: LogLevel = .debug,
        formatter: LogFormatter = CompactLogFormatter()
    ) {
        self.subsystem = subsystem
        self.minimumLevel = minimumLevel
        self.isEnabled = true
        self.formatter = formatter
    }
    
    func write(_ entry: LogEntry) {
        guard isEnabled, entry.level >= minimumLevel else { return }
        
        let logger = getLogger(for: entry.category)
        let message = formatter.format(entry)
        
        // Use the appropriate OSLog method based on log level
        switch entry.level {
        case .debug:
            logger.debug("\(message)")
        case .info:
            logger.info("\(message)")
        case .warning:
            logger.warning("\(message)")
        case .error:
            logger.error("\(message)")
        case .critical:
            logger.critical("\(message)")
        }
    }
    
    private func getLogger(for category: LogCategory) -> os.Logger {
        if let logger = loggers[category.rawValue] {
            return logger
        }
        
        let logger = os.Logger(subsystem: subsystem, category: category.rawValue)
        loggers[category.rawValue] = logger
        return logger
    }
}

// MARK: - File Destination

/// Logs to a file
final class FileLogDestination: LogDestination, @unchecked Sendable {
    var minimumLevel: LogLevel
    var isEnabled: Bool
    
    private let fileURL: URL
    private let formatter: LogFormatter
    private let fileHandle: FileHandle?
    private let maxFileSize: Int
    private let maxFiles: Int
    private let queue = DispatchQueue(label: "com.diligence.logger.file", qos: .utility)
    
    init(
        fileURL: URL? = nil,
        minimumLevel: LogLevel = .info,
        formatter: LogFormatter = StandardLogFormatter(),
        maxFileSize: Int = 10 * 1024 * 1024, // 10MB
        maxFiles: Int = 5
    ) {
        self.minimumLevel = minimumLevel
        self.isEnabled = true
        self.formatter = formatter
        self.maxFileSize = maxFileSize
        self.maxFiles = maxFiles
        
        // Default to app support directory
        if let fileURL = fileURL {
            self.fileURL = fileURL
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let logsDir = appSupport.appendingPathComponent("Logs", isDirectory: true)
            try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
            self.fileURL = logsDir.appendingPathComponent("diligence.log")
        }
        
        // Create file if needed
        if !FileManager.default.fileExists(atPath: self.fileURL.path) {
            FileManager.default.createFile(atPath: self.fileURL.path, contents: nil)
        }
        
        // Open file handle
        self.fileHandle = try? FileHandle(forWritingTo: self.fileURL)
        fileHandle?.seekToEndOfFile()
    }
    
    deinit {
        try? fileHandle?.close()
    }
    
    func write(_ entry: LogEntry) {
        guard isEnabled, entry.level >= minimumLevel else { return }
        
        queue.async { [weak self] in
            guard let self = self else { return }
            
            let message = self.formatter.format(entry) + "\n"
            guard let data = message.data(using: .utf8) else { return }
            
            self.fileHandle?.write(data)
            
            // Check file size and rotate if needed
            self.rotateIfNeeded()
        }
    }
    
    private func rotateIfNeeded() {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let fileSize = attributes[.size] as? Int,
              fileSize > maxFileSize else {
            return
        }
        
        // Close current file
        try? fileHandle?.close()
        
        // Rotate files
        for i in stride(from: maxFiles - 1, through: 1, by: -1) {
            let oldURL = fileURL.appendingPathExtension("\(i)")
            let newURL = fileURL.appendingPathExtension("\(i + 1)")
            try? FileManager.default.moveItem(at: oldURL, to: newURL)
        }
        
        // Move current file to .1
        let rotatedURL = fileURL.appendingPathExtension("1")
        try? FileManager.default.moveItem(at: fileURL, to: rotatedURL)
        
        // Create new file
        FileManager.default.createFile(atPath: fileURL.path, contents: nil)
    }
    
    /// Get log file contents
    func getLogContents() -> String? {
        try? String(contentsOf: fileURL, encoding: .utf8)
    }
    
    /// Clear log file
    func clear() {
        queue.async { [weak self] in
            guard let self = self else { return }
            try? self.fileHandle?.truncate(atOffset: 0)
        }
    }
}

// MARK: - Analytics Destination

/// Logs to analytics service
final class AnalyticsLogDestination: LogDestination, @unchecked Sendable {
    var minimumLevel: LogLevel
    var isEnabled: Bool
    
    private let analyticsReporter: AnalyticsReporter?
    
    init(
        analyticsReporter: AnalyticsReporter? = nil,
        minimumLevel: LogLevel = .error
    ) {
        self.analyticsReporter = analyticsReporter
        self.minimumLevel = minimumLevel
        self.isEnabled = true
    }
    
    func write(_ entry: LogEntry) {
        guard isEnabled,
              entry.level >= minimumLevel,
              let reporter = analyticsReporter else {
            return
        }
        
        var parameters: [String: Any] = [
            "level": entry.level.name,
            "category": entry.category.rawValue,
            "message": entry.message,
            "file": entry.file,
            "line": entry.line,
            "thread": entry.thread
        ]
        
        // Add metadata
        if let metadata = entry.metadata {
            for (key, value) in metadata {
                parameters["meta_\(key)"] = value
            }
        }
        
        let event = AnalyticsEvent(
            name: "log_event",
            parameters: parameters,
            timestamp: entry.timestamp
        )
        
        reporter.report(event)
    }
}

// MARK: - Memory Destination

/// Stores logs in memory for debugging
final class MemoryLogDestination: LogDestination, @unchecked Sendable {
    var minimumLevel: LogLevel
    var isEnabled: Bool
    
    private(set) var entries: [LogEntry] = []
    private let maxEntries: Int
    private let queue = DispatchQueue(label: "com.diligence.logger.memory")
    
    init(
        minimumLevel: LogLevel = .debug,
        maxEntries: Int = 1000
    ) {
        self.minimumLevel = minimumLevel
        self.isEnabled = true
        self.maxEntries = maxEntries
    }
    
    func write(_ entry: LogEntry) {
        guard isEnabled, entry.level >= minimumLevel else { return }
        
        queue.async { [weak self] in
            guard let self = self else { return }
            
            self.entries.append(entry)
            
            // Trim if needed
            if self.entries.count > self.maxEntries {
                self.entries.removeFirst(self.entries.count - self.maxEntries)
            }
        }
    }
    
    /// Get entries filtered by level
    func getEntries(level: LogLevel? = nil, category: LogCategory? = nil) -> [LogEntry] {
        queue.sync {
            var filtered = entries
            
            if let level = level {
                filtered = filtered.filter { $0.level >= level }
            }
            
            if let category = category {
                filtered = filtered.filter { $0.category == category }
            }
            
            return filtered
        }
    }
    
    /// Clear all entries
    func clear() {
        queue.async { [weak self] in
            self?.entries.removeAll()
        }
    }
}
