//  EmailPerformanceMonitor.swift
//  Diligence
//
//  Performance monitoring and diagnostics for email rendering
//

import Foundation
import SwiftUI
import Combine

// MARK: - Supporting Types

struct ContentComplexity {
    let size: Int
    let nestingDepth: Int
    let tableCount: Int
    let styleCount: Int
    let imageCount: Int
    
    var score: Int {
        // Calculate complexity score based on various factors
        let sizeScore = min(size / 1000, 50) // Up to 50 points for size
        let nestingScore = min(nestingDepth * 2, 20) // Up to 20 points for nesting
        let tableScore = min(tableCount * 5, 15) // Up to 15 points for tables
        let styleScore = min(styleCount / 10, 10) // Up to 10 points for styles
        let imageScore = min(imageCount, 5) // Up to 5 points for images
        
        return sizeScore + nestingScore + tableScore + styleScore + imageScore
    }
    
    init(size: Int, nestingDepth: Int, tableCount: Int = 0, styleCount: Int = 0, imageCount: Int = 0) {
        self.size = size
        self.nestingDepth = nestingDepth
        self.tableCount = tableCount
        self.styleCount = styleCount
        self.imageCount = imageCount
    }
    
    // Convenience initializer for basic complexity analysis
    init(from analysisResult: (size: Int, nestingDepth: Int, isComplex: Bool)) {
        self.size = analysisResult.size
        self.nestingDepth = analysisResult.nestingDepth
        self.tableCount = 0 // Could be enhanced to analyze HTML content
        self.styleCount = 0 // Could be enhanced to count style attributes
        self.imageCount = 0 // Could be enhanced to count images
    }
}

// MARK: - Email Performance Monitor

class EmailPerformanceMonitor: ObservableObject {
    static let shared = EmailPerformanceMonitor()
    
    @Published var renderingStats: [EmailRenderingStat] = []
    
    private let maxStats = 50 // Keep last 50 rendering operations
    private let performanceQueue = DispatchQueue(label: "email.performance", qos: .utility)
    
    private init() {}
    
    func recordRendering(
        emailId: String,
        contentSize: Int,
        complexity: ContentComplexity,
        renderTime: TimeInterval,
        success: Bool,
        error: EmailRenderError? = nil
    ) {
        let stat = EmailRenderingStat(
            emailId: emailId,
            timestamp: Date(),
            contentSize: contentSize,
            complexity: complexity,
            renderTime: renderTime,
            success: success,
            error: error
        )
        
        performanceQueue.async {
            DispatchQueue.main.async {
                self.renderingStats.insert(stat, at: 0)
                if self.renderingStats.count > self.maxStats {
                    self.renderingStats.removeLast()
                }
                
                self.logPerformanceIfNeeded(stat)
            }
        }
    }
    
    private func logPerformanceIfNeeded(_ stat: EmailRenderingStat) {
        // Log slow renders
        if stat.renderTime > 2.0 {
            print("🐌 Slow email render: \(stat.renderTime)s for \(stat.contentSize) bytes (complexity: \(stat.complexity.score))")
        }
        
        // Log failed renders
        if !stat.success {
            print("❌ Failed email render: \(stat.error?.errorDescription ?? "Unknown") - Size: \(stat.contentSize), Complexity: \(stat.complexity.score)")
        }
        
        // Log high complexity emails
        if stat.complexity.score > 80 {
            print("🔥 High complexity email: Score \(stat.complexity.score) - Tables: \(stat.complexity.tableCount), Styles: \(stat.complexity.styleCount)")
        }
    }
    
    var averageRenderTime: TimeInterval {
        guard !renderingStats.isEmpty else { return 0 }
        return renderingStats.map { $0.renderTime }.reduce(0, +) / Double(renderingStats.count)
    }
    
    var successRate: Double {
        guard !renderingStats.isEmpty else { return 0 }
        let successCount = renderingStats.filter { $0.success }.count
        return Double(successCount) / Double(renderingStats.count)
    }
    
    var slowRenderCount: Int {
        return renderingStats.filter { $0.renderTime > 1.0 }.count
    }
}

// MARK: - Email Rendering Statistics

struct EmailRenderingStat: Identifiable {
    let id = UUID()
    let emailId: String
    let timestamp: Date
    let contentSize: Int
    let complexity: ContentComplexity
    let renderTime: TimeInterval
    let success: Bool
    let error: EmailRenderError?
    
    var statusDescription: String {
        if success {
            if renderTime > 2.0 {
                return "Slow"
            } else if complexity.score > 80 {
                return "Complex"
            } else {
                return "Success"
            }
        } else {
            return error?.errorDescription ?? "Failed"
        }
    }
    
    var statusColor: Color {
        if success {
            if renderTime > 2.0 || complexity.score > 80 {
                return .orange
            } else {
                return .green
            }
        } else {
            return .red
        }
    }
}

// MARK: - Performance Debug View

struct EmailPerformanceDebugView: View {
    @StateObject private var monitor = EmailPerformanceMonitor.shared
    @State private var showingStats = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Performance Summary
            performanceSummary
            
            if showingStats {
                // Detailed statistics
                detailedStats
            }
            
            // Toggle button
            Button(showingStats ? "Hide Details" : "Show Details") {
                withAnimation {
                    showingStats.toggle()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }
    
    @ViewBuilder
    private var performanceSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.blue)
                
                Text("Email Rendering Performance")
                    .font(.headline)
            }
            
            HStack(spacing: 16) {
                performanceMetric("Avg Time", String(format: "%.2fs", monitor.averageRenderTime), .blue)
                performanceMetric("Success Rate", String(format: "%.1f%%", monitor.successRate * 100), .green)
                performanceMetric("Slow Renders", "\(monitor.slowRenderCount)", .orange)
            }
        }
    }
    
    @ViewBuilder
    private func performanceMetric(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
        .frame(minWidth: 60)
    }
    
    @ViewBuilder
    private var detailedStats: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Renders (\(monitor.renderingStats.count))")
                .font(.subheadline)
                .fontWeight(.medium)
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(monitor.renderingStats.prefix(20)) { stat in
                        renderingStatRow(stat)
                    }
                }
            }
            .frame(maxHeight: 200)
        }
    }
    
    @ViewBuilder
    private func renderingStatRow(_ stat: EmailRenderingStat) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(stat.statusColor)
                .frame(width: 6, height: 6)
            
            VStack(alignment: .leading, spacing: 1) {
                HStack {
                    Text("\(String(format: "%.2fs", stat.renderTime))")
                        .font(.caption2)
                        .fontWeight(.medium)
                    
                    Text("• \(stat.contentSize) bytes")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("• Score: \(stat.complexity.score)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(stat.statusDescription)
                        .font(.caption2)
                        .foregroundColor(stat.statusColor)
                }
                
                Text(formatTimestamp(stat.timestamp))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 1)
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}
