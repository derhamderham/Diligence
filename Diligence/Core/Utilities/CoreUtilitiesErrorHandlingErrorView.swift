//
//  ErrorView.swift
//  Diligence
//
//  UI components for displaying errors
//

import SwiftUI

// MARK: - Error Alert View

/// Alert view for displaying errors
///
/// Use this with ErrorHandler to show error alerts:
///
/// ```swift
/// .alert(isPresented: $errorHandler.showingErrorAlert) {
///     makeErrorAlert(
///         error: errorHandler.currentError,
///         onDismiss: { errorHandler.dismissAlert() }
///     )
/// }
/// ```
func makeErrorAlert(
    error: AppError?,
    onDismiss: (() -> Void)? = nil,
    onRetry: (() async -> Void)? = nil
) -> Alert {
    guard let error = error else {
        return Alert(title: Text("Error"))
    }
    
    var messageParts: [String] = []
    
    if let failureReason = error.failureReason {
        messageParts.append(failureReason)
    }
    
    if let recoverySuggestion = error.recoverySuggestion {
        messageParts.append(recoverySuggestion)
    }
    
    let message: Text? = messageParts.isEmpty ? nil : Text(messageParts.joined(separator: "\n\n"))
    
    let primaryButton: Alert.Button
    if error.isRetryable, let onRetry = onRetry {
        primaryButton = .default(Text("Retry")) {
            _Concurrency.Task {
                await onRetry()
            }
        }
    } else if let helpAnchor = error.helpAnchor {
        primaryButton = .default(Text("Help")) {
            if let url = URL(string: "diligence://help/\(helpAnchor)") {
                NSWorkspace.shared.open(url)
            }
        }
    } else {
        primaryButton = .default(Text("OK"), action: onDismiss)
    }
    
    return Alert(
        title: Text(error.errorDescription ?? "Error"),
        message: message,
        primaryButton: primaryButton,
        secondaryButton: .cancel(Text("Dismiss"), action: onDismiss)
    )
}

// MARK: - Error Banner View

/// Banner view for non-blocking error display
struct ErrorBannerView: View {
    let error: AppError
    let onDismiss: () -> Void
    
    @State private var isVisible = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: iconName(for: error.severity))
                .font(.title2)
                .foregroundColor(iconColor(for: error.severity))
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(error.errorDescription ?? "Error")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if let recoverySuggestion = error.recoverySuggestion {
                    Text(recoverySuggestion)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // Dismiss button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(backgroundColor(for: error.severity))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal)
        .offset(y: isVisible ? 0 : -100)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isVisible = true
            }
        }
    }
    
    private func iconName(for severity: ErrorSeverity) -> String {
        switch severity {
        case .info:
            return "info.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.circle.fill"
        case .critical:
            return "exclamationmark.octagon.fill"
        }
    }
    
    private func iconColor(for severity: ErrorSeverity) -> Color {
        switch severity {
        case .info:
            return .blue
        case .warning:
            return .orange
        case .error:
            return .red
        case .critical:
            return .purple
        }
    }
    
    private func backgroundColor(for severity: ErrorSeverity) -> Color {
        switch severity {
        case .info:
            return Color.blue.opacity(0.1)
        case .warning:
            return Color.orange.opacity(0.1)
        case .error:
            return Color.red.opacity(0.1)
        case .critical:
            return Color.purple.opacity(0.1)
        }
    }
}

// MARK: - Error Detail View

/// Detailed error view for debugging
struct ErrorDetailView: View {
    let error: AppError
    let errorRecord: ErrorRecord?
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Error Information") {
                    LabeledContent("Type", value: error.errorDescription ?? "Unknown")
                    LabeledContent("Category", value: error.category.rawValue.capitalized)
                    LabeledContent("Severity", value: error.severity.rawValue.capitalized)
                }
                
                if let failureReason = error.failureReason {
                    Section("Failure Reason") {
                        Text(failureReason)
                            .font(.body)
                    }
                }
                
                if let recoverySuggestion = error.recoverySuggestion {
                    Section("Recovery Suggestion") {
                        Text(recoverySuggestion)
                            .font(.body)
                    }
                }
                
                Section("Error Properties") {
                    LabeledContent("Retryable", value: error.isRetryable ? "Yes" : "No")
                    LabeledContent("Should Report", value: error.shouldReport ? "Yes" : "No")
                }
                
                if let record = errorRecord {
                    Section("Debug Information") {
                        LabeledContent("Timestamp", value: record.timestamp.formatted())
                        LabeledContent("File", value: record.file)
                        LabeledContent("Function", value: record.function)
                        LabeledContent("Line", value: String(record.line))
                        
                        if let context = record.context {
                            LabeledContent("Context", value: context)
                        }
                    }
                }
            }
            .navigationTitle("Error Details")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Error List View

/// View displaying error history
struct ErrorHistoryView: View {
    @StateObject private var errorHandler = ErrorHandler.shared
    @State private var selectedError: (AppError, ErrorRecord)?
    @State private var showingExport = false
    @State private var exportedText = ""
    
    var body: some View {
        NavigationView {
            List {
                if errorHandler.getRecentErrors().isEmpty {
                    ContentUnavailableView(
                        "No Errors",
                        systemImage: "checkmark.circle",
                        description: Text("No errors have been recorded yet.")
                    )
                } else {
                    ForEach(errorHandler.getRecentErrors().reversed()) { record in
                        ErrorHistoryRow(record: record)
                            .onTapGesture {
                                if let error = parseError(from: record) {
                                    selectedError = (error, record)
                                }
                            }
                    }
                }
            }
            .navigationTitle("Error History")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(action: exportHistory) {
                            Label("Export History", systemImage: "square.and.arrow.up")
                        }
                        
                        Button(role: .destructive, action: clearHistory) {
                            Label("Clear History", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(item: Binding(
                get: { selectedError.map { ErrorSheetItem(error: $0.0, record: $0.1) } },
                set: { selectedError = $0.map { ($0.error, $0.record) } }
            )) { item in
                ErrorDetailView(error: item.error, errorRecord: item.record)
            }
            .sheet(isPresented: $showingExport) {
                ExportView(text: exportedText)
            }
        }
    }
    
    private func clearHistory() {
        errorHandler.clearHistory()
    }
    
    private func exportHistory() {
        if let json = errorHandler.exportHistory() {
            exportedText = json
            showingExport = true
        }
    }
    
    private func parseError(from record: ErrorRecord) -> AppError? {
        // This is a simplified parser - in production you'd need more robust parsing
        switch record.category {
        case "network":
            return .network(.unknownNetworkError)
        case "authentication":
            return .authentication(.notAuthenticated)
        case "database":
            return .database(.queryFailed)
        case "service":
            return .service(.serviceUnavailable(name: "Unknown"))
        case "validation":
            return .validation(.emptyField(fieldName: "Unknown"))
        case "system":
            return .system(.unknownError)
        default:
            return nil
        }
    }
}

// MARK: - Supporting Views

struct ErrorHistoryRow: View {
    let record: ErrorRecord
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: iconName(for: record.severity))
                    .foregroundColor(iconColor(for: record.severity))
                
                Text(record.error)
                    .font(.headline)
                
                Spacer()
                
                Text(record.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text("\(record.file):\(record.line) · \(record.function)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if let context = record.context {
                Text(context)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func iconName(for severity: String) -> String {
        switch severity {
        case "info":
            return "info.circle.fill"
        case "warning":
            return "exclamationmark.triangle.fill"
        case "error":
            return "xmark.circle.fill"
        case "critical":
            return "exclamationmark.octagon.fill"
        default:
            return "questionmark.circle"
        }
    }
    
    private func iconColor(for severity: String) -> Color {
        switch severity {
        case "info":
            return .blue
        case "warning":
            return .orange
        case "error":
            return .red
        case "critical":
            return .purple
        default:
            return .gray
        }
    }
}

struct ErrorSheetItem: Identifiable {
    let id = UUID()
    let error: AppError
    let record: ErrorRecord
}

struct ExportView: View {
    let text: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                Text(text)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding()
            }
            .navigationTitle("Export Error History")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button("Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                    }
                }
            }
        }
    }
}

// MARK: - Error View Modifiers

extension View {
    
    /// Add error handling to a view
    ///
    /// Displays errors via alert or banner based on ErrorHandler state.
    ///
    /// ```swift
    /// ContentView()
    ///     .withErrorHandling()
    /// ```
    func withErrorHandling() -> some View {
        modifier(ErrorHandlingModifier())
    }
    
    /// Add error banner to a view
    ///
    /// ```swift
    /// ContentView()
    ///     .withErrorBanner()
    /// ```
    func withErrorBanner() -> some View {
        modifier(ErrorBannerModifier())
    }
}

struct ErrorHandlingModifier: ViewModifier {
    @StateObject private var errorHandler = ErrorHandler.shared
    
    func body(content: Content) -> some View {
        content
            .alert(isPresented: $errorHandler.showingErrorAlert) {
                makeErrorAlert(
                    error: errorHandler.currentError,
                    onDismiss: {
                        errorHandler.dismissAlert()
                    }
                )
            }
    }
}

struct ErrorBannerModifier: ViewModifier {
    @StateObject private var errorHandler = ErrorHandler.shared
    
    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content
            
            if errorHandler.showingBanner, let error = errorHandler.bannerError {
                ErrorBannerView(error: error) {
                    errorHandler.dismissBanner()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(1000)
            }
        }
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension AppError {
    static let previewNetwork = AppError.network(.noConnection)
    static let previewAuth = AppError.authentication(.notAuthenticated)
    static let previewDatabase = AppError.database(.corruptedDatabase)
    static let previewService = AppError.service(.emailFetchFailed)
    static let previewValidation = AppError.validation(.emptyField(fieldName: "Email"))
}

#Preview("Error Alert") {
    Text("Content")
        .alert(isPresented: .constant(true)) {
            makeErrorAlert(error: .previewNetwork)
        }
}

#Preview("Error Banner") {
    VStack {
        ErrorBannerView(error: .previewAuth) {}
            .padding(.top, 50)
        Spacer()
    }
}

#Preview("Error Detail") {
    ErrorDetailView(
        error: .previewDatabase,
        errorRecord: ErrorRecord(
            error: .previewDatabase,
            context: ErrorContext(operation: "Saving task"),
            timestamp: Date(),
            file: "TaskViewModel.swift",
            function: "saveTask()",
            line: 42
        )
    )
}

#Preview("Error History") {
    ErrorHistoryView()
}
#endif
