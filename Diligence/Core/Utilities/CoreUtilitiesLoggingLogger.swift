//
//  Logger.swift
//  Diligence
//
//  Main logging system
//

import Foundation
import Combine

/// Main logger class
///
/// Provides a centralized logging system with multiple destinations,
/// categories, privacy-aware redaction, and performance monitoring.
///
/// ## Usage
///
/// ```swift
/// // Simple logging
/// AppLogger.shared.info("App started", category: .app)
///
/// // With metadata
/// AppLogger.shared.error("Failed to fetch", category: .network, metadata: ["url": url])
///
/// // Privacy-aware
/// AppLogger.shared.debug("User email: \(email.redacted())", category: .auth)
///
/// // Performance measurement
/// let measurement = AppLogger.shared.measurePerformance("database_query")
/// // ... do work ...
/// measurement.end()
/// ```
@MainActor
final class AppLogger {
    
    // MARK: - Singleton
    
    static let shared = AppLogger()
    
    // MARK: - Properties
    
    /// Thread-safe storage for destinations
    private let destinationsLock = NSLock()
    private nonisolated(unsafe) var _destinations: [any LogDestination] = []
    
    /// Global minimum log level
    nonisolated(unsafe) var minimumLevel: LogLevel = .debug
    
    /// Whether logging is enabled globally
    nonisolated(unsafe) var isEnabled = true
    
    // MARK: - Initialization
    
    private init() {
        setupDefaultDestinations()
        print("📋 AppLogger: Initialized")
    }
    
    private func setupDefaultDestinations() {
        #if DEBUG
        // Debug: Console + Memory
        addDestination(ConsoleLogDestination(minimumLevel: .debug))
        addDestination(MemoryLogDestination(maxEntries: 500))
        #else
        // Production: Console (info+) + File (warning+)
        addDestination(ConsoleLogDestination(minimumLevel: .info, formatter: ProductionLogFormatter()))
        addDestination(FileLogDestination(minimumLevel: .warning, formatter: ProductionLogFormatter()))
        #endif
    }
    
    // MARK: - Destination Management
    
    /// Add a log destination
    nonisolated func addDestination(_ destination: any LogDestination) {
        destinationsLock.lock()
        defer { destinationsLock.unlock() }
        _destinations.append(destination)
    }
    
    /// Remove all destinations
    nonisolated func clearDestinations() {
        destinationsLock.lock()
        defer { destinationsLock.unlock() }
        _destinations.removeAll()
    }
    
    /// Get all destinations
    nonisolated func getDestinations() -> [any LogDestination] {
        destinationsLock.lock()
        defer { destinationsLock.unlock() }
        return _destinations
    }
    
    /// Thread-safe access to destinations for writing
    private nonisolated func withDestinations<T>(_ work: ([any LogDestination]) -> T) -> T {
        destinationsLock.lock()
        defer { destinationsLock.unlock() }
        return work(_destinations)
    }
    
    // MARK: - Logging Methods
    
    /// Log a debug message
    func debug(
        _ message: String,
        category: LogCategory = .general,
        metadata: [String: String]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .debug, message: message, category: category, metadata: metadata, file: file, function: function, line: line)
    }
    
    /// Log an info message
    func info(
        _ message: String,
        category: LogCategory = .general,
        metadata: [String: String]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .info, message: message, category: category, metadata: metadata, file: file, function: function, line: line)
    }
    
    /// Log a warning message
    func warning(
        _ message: String,
        category: LogCategory = .general,
        metadata: [String: String]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .warning, message: message, category: category, metadata: metadata, file: file, function: function, line: line)
    }
    
    /// Log an error message
    func error(
        _ message: String,
        category: LogCategory = .general,
        metadata: [String: String]? = nil,
        error: Error? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        var meta = metadata ?? [:]
        if let error = error {
            meta["error"] = error.localizedDescription
        }
        log(level: .error, message: message, category: category, metadata: meta, file: file, function: function, line: line)
    }
    
    /// Log a critical message
    func critical(
        _ message: String,
        category: LogCategory = .general,
        metadata: [String: String]? = nil,
        error: Error? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        var meta = metadata ?? [:]
        if let error = error {
            meta["error"] = error.localizedDescription
        }
        log(level: .critical, message: message, category: category, metadata: meta, file: file, function: function, line: line)
    }
    
    // MARK: - Core Logging
    
    private nonisolated func log(
        level: LogLevel,
        message: String,
        category: LogCategory,
        metadata: [String: String]?,
        file: String,
        function: String,
        line: Int
    ) {
        guard isEnabled, level >= minimumLevel else { return }
        
        let entry = LogEntry(
            level: level,
            category: category,
            message: message,
            metadata: metadata,
            file: file,
            function: function,
            line: line
        )
        
        // Write to all destinations in a thread-safe manner
        withDestinations { destinations in
            for destination in destinations {
                destination.write(entry)
            }
        }
    }
    
    // MARK: - Performance Logging
    
    /// Measure performance of an operation
    func measurePerformance(
        _ operation: String,
        category: LogCategory = .performance,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) -> PerformanceMeasurement {
        PerformanceMeasurement(
            operation: operation,
            category: category,
            logger: self,
            file: file,
            function: function,
            line: line
        )
    }
    
    /// Measure an async operation
    func measure<T>(
        _ operation: String,
        category: LogCategory = .performance,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        work: () async throws -> T
    ) async rethrows -> T {
        let start = Date()
        defer {
            let duration = Date().timeIntervalSince(start)
            info(
                "\(operation) completed in \(String(format: "%.3f", duration))s",
                category: category,
                metadata: ["duration": String(format: "%.3f", duration)],
                file: file,
                function: function,
                line: line
            )
        }
        return try await work()
    }
    
    // MARK: - Convenience Methods
    
    /// Log network request
    func networkRequest(
        method: String,
        url: String,
        statusCode: Int? = nil,
        duration: TimeInterval? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        var metadata: [String: String] = [
            "method": method,
            "url": url.redacted(privacy: .auto)
        ]
        
        if let statusCode = statusCode {
            metadata["status"] = "\(statusCode)"
        }
        
        if let duration = duration {
            metadata["duration"] = String(format: "%.3f", duration)
        }
        
        let level: LogLevel = (statusCode ?? 200) >= 400 ? .error : .info
        log(
            level: level,
            message: "\(method) \(url.redacted())",
            category: .network,
            metadata: metadata,
            file: file,
            function: function,
            line: line
        )
    }
    
    /// Log database operation
    func databaseOperation(
        operation: String,
        table: String? = nil,
        duration: TimeInterval? = nil,
        error: Error? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        var metadata: [String: String] = ["operation": operation]
        
        if let table = table {
            metadata["table"] = table
        }
        
        if let duration = duration {
            metadata["duration"] = String(format: "%.3f", duration)
        }
        
        let level: LogLevel = error != nil ? .error : .debug
        let message = error != nil ? "\(operation) failed" : "\(operation) completed"
        
        log(
            level: level,
            message: message,
            category: .database,
            metadata: metadata,
            file: file,
            function: function,
            line: line
        )
    }
}

// MARK: - Performance Measurement

/// Performance measurement helper
class PerformanceMeasurement {
    private let operation: String
    private let category: LogCategory
    private weak var logger: AppLogger?
    private let startTime: Date
    private let file: String
    private let function: String
    private let line: Int
    
    init(
        operation: String,
        category: LogCategory,
        logger: AppLogger,
        file: String,
        function: String,
        line: Int
    ) {
        self.operation = operation
        self.category = category
        self.logger = logger
        self.startTime = Date()
        self.file = file
        self.function = function
        self.line = line
        
        logger.debug(
            "\(operation) started",
            category: category,
            file: file,
            function: function,
            line: line
        )
    }
    
    /// End measurement and log duration
    func end(additionalInfo: String? = nil) {
        let duration = Date().timeIntervalSince(startTime)
        let durationStr = String(format: "%.3f", duration)
        
        var message = "\(operation) completed in \(durationStr)s"
        if let info = additionalInfo {
            message += " - \(info)"
        }
        
        logger?.info(
            message,
            category: category,
            metadata: [
                "duration": durationStr,
                "operation": operation
            ],
            file: file,
            function: function,
            line: line
        )
    }
    
    deinit {
        // Auto-end if not explicitly ended
        end()
    }
}

// MARK: - Global Convenience Functions

/// Global debug log
func logDebug(
    _ message: String,
    category: LogCategory = .general,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    _Concurrency.Task { @MainActor [message, category, file, function, line] in
        AppLogger.shared.debug(message, category: category, file: file, function: function, line: line)
    }
}

/// Global info log
func logInfo(
    _ message: String,
    category: LogCategory = .general,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    _Concurrency.Task { @MainActor [message, category, file, function, line] in
        AppLogger.shared.info(message, category: category, file: file, function: function, line: line)
    }
}

/// Global warning log
func logWarning(
    _ message: String,
    category: LogCategory = .general,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    _Concurrency.Task { @MainActor [message, category, file, function, line] in
        AppLogger.shared.warning(message, category: category, file: file, function: function, line: line)
    }
}

/// Global error log
func logError(
    _ message: String,
    error: Error? = nil,
    category: LogCategory = .general,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    _Concurrency.Task { @MainActor [message, category, error, file, function, line] in
        AppLogger.shared.error(message, category: category, error: error, file: file, function: function, line: line)
    }
}
