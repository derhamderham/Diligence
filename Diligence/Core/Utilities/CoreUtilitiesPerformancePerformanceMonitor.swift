//
//  PerformanceMonitor.swift
//  Diligence
//
//  Performance monitoring and optimization utilities
//

import Foundation
import SwiftUI
import os.log
import Combine

// MARK: - Performance Monitor

/// Monitors app performance, tracks metrics, and provides optimization insights
@MainActor
final class PerformanceMonitor: ObservableObject {
    // MARK: - Singleton
    
    static let shared = PerformanceMonitor()
    
    // MARK: - Published Properties
    
    @Published private(set) var metrics: [String: PerformanceMetric] = [:]
    @Published private(set) var isMonitoring = false
    
    // MARK: - Private Properties
    
    private let logger = os.Logger(subsystem: "com.diligence", category: "PerformanceMonitor")
    private var operations: [String: OperationTimer] = [:]
    private var memoryWarningObserver: NSObjectProtocol?
    
    // MARK: - Configuration
    
    var enableLogging = true
    var enableDetailedMetrics = false
    
    // MARK: - Initialization
    
    private init() {
        setupMemoryWarningObserver()
    }
    
    deinit {
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - Memory Monitoring
    
    private func setupMemoryWarningObserver() {
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NSApplicationDidReceiveMemoryWarning"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }
    
    private func handleMemoryWarning() {
        logger.warning("⚠️ Memory warning received")
        recordEvent("memory_warning")
        
        // Notify caches to purge
        NotificationCenter.default.post(name: .performancePurgeCache, object: nil)
    }
    
    // MARK: - Operation Timing
    
    /// Start timing an operation
    /// - Parameters:
    ///   - operation: Unique identifier for the operation
    ///   - metadata: Optional metadata about the operation
    func startOperation(_ operation: String, metadata: [String: Any]? = nil) {
        guard isMonitoring else { return }
        
        let timer = OperationTimer(
            operation: operation,
            startTime: Date(),
            metadata: metadata
        )
        operations[operation] = timer
        
        if enableLogging {
            logger.debug("▶️ Started: \(operation)")
        }
    }
    
    /// End timing an operation and record metrics
    /// - Parameters:
    ///   - operation: Unique identifier for the operation
    ///   - metadata: Optional additional metadata
    func endOperation(_ operation: String, metadata: [String: Any]? = nil) {
        guard isMonitoring else { return }
        guard let timer = operations.removeValue(forKey: operation) else {
            logger.warning("⚠️ No timer found for operation: \(operation)")
            return
        }
        
        let duration = Date().timeIntervalSince(timer.startTime)
        
        // Update or create metric
        if var metric = metrics[operation] {
            metric.recordDuration(duration)
            metrics[operation] = metric
        } else {
            var metric = PerformanceMetric(operation: operation)
            metric.recordDuration(duration)
            metrics[operation] = metric
        }
        
        if enableLogging {
            logger.info("⏱ Completed: \(operation) in \(String(format: "%.3f", duration))s")
        }
        
        // Log slow operations
        if duration > 1.0 {
            logger.warning("🐌 Slow operation detected: \(operation) took \(String(format: "%.3f", duration))s")
        }
    }
    
    /// Measure an async operation
    /// - Parameters:
    ///   - operation: Unique identifier for the operation
    ///   - metadata: Optional metadata
    ///   - work: The async work to measure
    /// - Returns: Result of the work
    func measure<T>(
        _ operation: String,
        metadata: [String: Any]? = nil,
        work: () async throws -> T
    ) async rethrows -> T {
        startOperation(operation, metadata: metadata)
        defer { endOperation(operation) }
        return try await work()
    }
    
    /// Measure a synchronous operation
    /// - Parameters:
    ///   - operation: Unique identifier for the operation
    ///   - metadata: Optional metadata
    ///   - work: The work to measure
    /// - Returns: Result of the work
    func measureSync<T>(
        _ operation: String,
        metadata: [String: Any]? = nil,
        work: () throws -> T
    ) rethrows -> T {
        startOperation(operation, metadata: metadata)
        defer { endOperation(operation) }
        return try work()
    }
    
    // MARK: - Event Recording
    
    /// Record a discrete performance event
    /// - Parameters:
    ///   - event: Event name
    ///   - metadata: Optional metadata
    func recordEvent(_ event: String, metadata: [String: Any]? = nil) {
        guard isMonitoring else { return }
        
        if var metric = metrics[event] {
            metric.incrementCount()
            metrics[event] = metric
        } else {
            var metric = PerformanceMetric(operation: event)
            metric.incrementCount()
            metrics[event] = metric
        }
        
        if enableLogging && enableDetailedMetrics {
            logger.debug("📊 Event: \(event)")
        }
    }
    
    // MARK: - Memory Metrics
    
    /// Get current memory usage in bytes
    var currentMemoryUsage: UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return result == KERN_SUCCESS ? info.resident_size : 0
    }
    
    /// Get current memory usage in megabytes
    var currentMemoryUsageMB: Double {
        Double(currentMemoryUsage) / 1024.0 / 1024.0
    }
    
    // MARK: - Monitoring Control
    
    func startMonitoring() {
        isMonitoring = true
        logger.info("📊 Performance monitoring started")
    }
    
    func stopMonitoring() {
        isMonitoring = false
        logger.info("📊 Performance monitoring stopped")
    }
    
    func reset() {
        metrics.removeAll()
        operations.removeAll()
        logger.info("📊 Performance metrics reset")
    }
    
    // MARK: - Reporting
    
    /// Generate a performance report
    func generateReport() -> PerformanceReport {
        let sortedMetrics = metrics.values.sorted { $0.totalDuration > $1.totalDuration }
        
        return PerformanceReport(
            timestamp: Date(),
            metrics: sortedMetrics,
            memoryUsageMB: currentMemoryUsageMB
        )
    }
    
    /// Print performance report to console
    func printReport() {
        let report = generateReport()
        
        print("\n" + String(repeating: "=", count: 60))
        print("PERFORMANCE REPORT")
        print(String(repeating: "=", count: 60))
        print("Generated: \(report.timestamp)")
        print("Memory Usage: \(String(format: "%.2f MB", report.memoryUsageMB))")
        print(String(repeating: "-", count: 60))
        
        if report.metrics.isEmpty {
            print("No metrics recorded")
        } else {
            print("\nTop Operations by Total Duration:")
            print(String(repeating: "-", count: 60))
            print(String(format: "%-30s %8s %8s %10s", "Operation", "Count", "Avg", "Total"))
            print(String(repeating: "-", count: 60))
            
            for metric in report.metrics.prefix(15) {
                print(String(
                    format: "%-30s %8d %8.3fs %9.3fs",
                    String(metric.operation.prefix(30)),
                    metric.count,
                    metric.averageDuration,
                    metric.totalDuration
                ))
            }
        }
        
        print(String(repeating: "=", count: 60) + "\n")
    }
}

// MARK: - Performance Metric

struct PerformanceMetric: Identifiable {
    let id = UUID()
    let operation: String
    private(set) var count: Int = 0
    private(set) var totalDuration: TimeInterval = 0
    private(set) var minDuration: TimeInterval = .infinity
    private(set) var maxDuration: TimeInterval = 0
    private(set) var lastRecorded: Date?
    
    var averageDuration: TimeInterval {
        count > 0 ? totalDuration / Double(count) : 0
    }
    
    mutating func recordDuration(_ duration: TimeInterval) {
        count += 1
        totalDuration += duration
        minDuration = min(minDuration, duration)
        maxDuration = max(maxDuration, duration)
        lastRecorded = Date()
    }
    
    mutating func incrementCount() {
        count += 1
        lastRecorded = Date()
    }
}

// MARK: - Operation Timer

private struct OperationTimer {
    let operation: String
    let startTime: Date
    let metadata: [String: Any]?
}

// MARK: - Performance Report

struct PerformanceReport {
    let timestamp: Date
    let metrics: [PerformanceMetric]
    let memoryUsageMB: Double
    
    var topOperations: [PerformanceMetric] {
        Array(metrics.prefix(10))
    }
    
    var slowOperations: [PerformanceMetric] {
        metrics.filter { $0.averageDuration > 0.5 }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let performancePurgeCache = Notification.Name("com.diligence.performance.purgeCache")
}

// MARK: - View Extension for Performance Tracking

extension View {
    /// Track view appearance performance
    func trackPerformance(_ operationName: String) -> some View {
        self.modifier(PerformanceTrackingModifier(operationName: operationName))
    }
}

private struct PerformanceTrackingModifier: ViewModifier {
    let operationName: String
    @State private var appearTime: Date?
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                appearTime = Date()
                PerformanceMonitor.shared.startOperation("\(operationName).appear")
            }
            .onDisappear {
                if let start = appearTime {
                    let duration = Date().timeIntervalSince(start)
                    PerformanceMonitor.shared.recordEvent(
                        "\(operationName).visible_time",
                        metadata: ["duration": duration]
                    )
                }
                PerformanceMonitor.shared.endOperation("\(operationName).appear")
            }
    }
}

// MARK: - Task Cancellation Helper

/// Helper for managing task cancellation in async operations
@MainActor
final class CancellableTaskManager {
    private var tasks: [String: _Concurrency.Task<Void, Never>] = [:]
    
    /// Store a cancellable task
    func store(_ key: String, task: _Concurrency.Task<Void, Never>) {
        // Cancel existing task with same key
        cancel(key)
        tasks[key] = task
    }
    
    /// Cancel a specific task
    func cancel(_ key: String) {
        tasks[key]?.cancel()
        tasks.removeValue(forKey: key)
    }
    
    /// Cancel all tasks
    func cancelAll() {
        tasks.values.forEach { $0.cancel() }
        tasks.removeAll()
    }
    
    /// Check if a task is cancelled
    func isCancelled(_ key: String) -> Bool {
        tasks[key]?.isCancelled ?? true
    }
}

// MARK: - Performance Optimization Utilities

enum PerformanceUtils {
    
    /// Debounce async operations
    @MainActor
    static func debounce(
        delay: Duration,
        operation: @escaping () async -> Void
    ) -> () async -> Void {
        var task: _Concurrency.Task<Void, Never>?
        
        return {
            task?.cancel()
            task = _Concurrency.Task {
                try? await _Concurrency.Task.sleep(for: delay)
                guard !_Concurrency.Task.isCancelled else { return }
                await operation()
            }
        }
    }
    
    /// Throttle async operations
    @MainActor
    static func throttle(
        interval: Duration,
        operation: @escaping () async -> Void
    ) -> () async -> Void {
        var lastExecutionTime: ContinuousClock.Instant?
        var task: _Concurrency.Task<Void, Never>?
        
        return {
            let now = ContinuousClock.now
            
            if let lastTime = lastExecutionTime {
                let elapsed = now - lastTime
                if elapsed < interval {
                    return
                }
            }
            
            lastExecutionTime = now
            task?.cancel()
            task = _Concurrency.Task {
                await operation()
            }
        }
    }
}
