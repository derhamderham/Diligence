//
//  ErrorHandler.swift
//  Diligence
//
//  Created by derham on 11/10/25.
//

import SwiftUI
import Combine

@MainActor
class ErrorHandler: ObservableObject {
    static let shared = ErrorHandler()
    
    @Published var currentError: AppError?
    @Published var showBanner = false
    @Published var showingBanner = false
    @Published var showingErrorAlert = false
    @Published var bannerError: AppError?
    
    private var errorHistory: [ErrorRecord] = []
    private let maxHistorySize = 100
    
    private init() {}
    
    func handle(
        _ error: AppError,
        context: ErrorContext,
        shouldPresent: Bool = true,
        presentationStyle: PresentationStyle = .alert,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        currentError = error
        
        // Record the error
        let record = ErrorRecord(
            error: error,
            context: context,
            timestamp: Date(),
            file: file,
            function: function,
            line: line
        )
        addToHistory(record)
        
        if shouldPresent {
            switch presentationStyle {
            case .banner:
                bannerError = error
                showingBanner = true
                showBanner = true
            case .alert:
                showingErrorAlert = true
            }
            print("⚠️ Error: \(error) - \(context.operation)")
        }
    }
    
    func handleSilently(
        _ error: AppError,
        context: ErrorContext,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        // Record the error
        let record = ErrorRecord(
            error: error,
            context: context,
            timestamp: Date(),
            file: file,
            function: function,
            line: line
        )
        addToHistory(record)
        
        print("⚠️ Silent error: \(error) - \(context.operation)")
        if !context.additionalInfo.isEmpty {
            print("   Additional info: \(context.additionalInfo)")
        }
    }
    
    func dismissAlert() {
        showingErrorAlert = false
        currentError = nil
    }
    
    func dismissBanner() {
        showingBanner = false
        showBanner = false
        bannerError = nil
    }
    
    // MARK: - Error History
    
    private func addToHistory(_ record: ErrorRecord) {
        errorHistory.append(record)
        
        // Keep history size manageable
        if errorHistory.count > maxHistorySize {
            errorHistory.removeFirst(errorHistory.count - maxHistorySize)
        }
    }
    
    func getRecentErrors(limit: Int = 50) -> [ErrorRecord] {
        Array(errorHistory.suffix(limit))
    }
    
    func clearHistory() {
        errorHistory.removeAll()
    }
    
    func exportHistory() -> String? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        guard let data = try? encoder.encode(errorHistory),
              let json = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return json
    }
    
    enum PresentationStyle {
        case alert
        case banner
    }
}

// MARK: - Error Context
// Note: AppError is defined in CoreUtilitiesErrorHandlingAppError.swift

struct ErrorContext {
    let operation: String
    var additionalInfo: [String: String] = [:]
}

// MARK: - Error Record

struct ErrorRecord: Identifiable, Codable {
    let id: UUID
    let error: String
    let category: String
    let severity: String
    let context: String?
    let timestamp: Date
    let file: String
    let function: String
    let line: Int
    
    init(
        id: UUID = UUID(),
        error: AppError,
        context: ErrorContext,
        timestamp: Date = Date(),
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        self.id = id
        self.error = error.errorDescription ?? "Unknown error"
        self.category = error.category.rawValue
        self.severity = error.severity.rawValue
        self.context = context.operation
        self.timestamp = timestamp
        self.file = (file as NSString).lastPathComponent
        self.function = function
        self.line = line
    }
}

// MARK: - View Modifiers
// Note: withErrorHandling(), withErrorBanner(), and ErrorBannerModifier 
// are defined in CoreUtilitiesErrorHandlingErrorView.swift
