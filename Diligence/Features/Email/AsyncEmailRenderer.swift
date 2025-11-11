import SwiftUI
import SwiftUI
import WebKit
import Foundation
import OSLog
import Combine

// MARK: - Email Model
struct Email {
    let id: String
    let subject: String
    let sender: String
    let date: Date
    let htmlBody: String?
    let textBody: String
}

// MARK: - Email Rendering State
enum EmailRenderingState {
    case loading
    case htmlReady(String)
    case plainTextFallback(String)
    case error(String)
}

// MARK: - HTML Sanitization and Processing
class HTMLProcessor {
    // Using standard OSLog Logger
    private let logger = Logger(subsystem: "com.diligence.app", category: "HTMLProcessor")
    
    // HTML size limits and complexity thresholds
    let maxHTMLSize = 500_000 // 500KB
    let maxNestingDepth = 20
    let renderingTimeout: TimeInterval = 5.0
    
    func processHTML(_ html: String) async -> String {
        // Check HTML size first
        if html.count > maxHTMLSize {
            logger.warning("HTML too large: \(html.count) characters, exceeding limit of \(self.maxHTMLSize)")
            return html.prefix(maxHTMLSize) + "\n<!-- Content truncated due to size -->"
        }
        
        // Apply timeout directly to the sanitization task
        return await withTimeout(seconds: renderingTimeout) {
            await self.sanitizeHTML(html)
        } ?? html
    }
    
    private func sanitizeHTML(_ html: String) async -> String {
        var sanitized = html
        
        // Remove MSO conditional comments
        sanitized = sanitized.replacingOccurrences(
            of: #"<!--$$if[^$$]*\]>.*?<!$$endif$$-->"#,
            with: "",
            options: .regularExpression
        )
        
        // Remove tracking pixels (1x1 images)
        sanitized = sanitized.replacingOccurrences(
            of: #"<img[^>]*width\s*=\s*["\']?1["\']?[^>]*height\s*=\s*["\']?1["\']?[^>]*/?>"#,
            with: "",
            options: .regularExpression
        )
        
        // Remove external script tags for security
        sanitized = sanitized.replacingOccurrences(
            of: #"<script[^>]*>.*?</script>"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        
        // Simplify excessive inline styles (keep only basic formatting)
        sanitized = simplifyInlineStyles(sanitized)
        
        // Remove empty tags
        sanitized = sanitized.replacingOccurrences(
            of: #"<(\w+)[^>]*>\s*</\1>"#,
            with: "",
            options: .regularExpression
        )
        
        return sanitized
    }
    
    private func simplifyInlineStyles(_ html: String) -> String {
        // Keep only essential style properties
        let allowedStyles = [
            "color", "background-color", "font-size", "font-weight",
            "text-align", "margin", "padding", "border", "width", "height"
        ]
        
        // Use NSRegularExpression for complex replacement
        let pattern = #"style\s*=\s*["\']([^"\']*)["\']"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return html
        }
        
        let nsString = html as NSString
        let range = NSRange(location: 0, length: nsString.length)
        var result = html
        
        // Process matches in reverse order to maintain string indices
        let matches = regex.matches(in: html, options: [], range: range).reversed()
        
        for match in matches {
            guard match.numberOfRanges > 1 else { continue }
            
            let fullMatchRange = match.range(at: 0)
            let styleContentRange = match.range(at: 1)
            
            guard let styleRange = Range(styleContentRange, in: html) else { continue }
            
            let styleContent = String(html[styleRange])
            let filteredStyles = styleContent
                .components(separatedBy: ";")
                .filter { style in
                    let property = style.trimmingCharacters(in: .whitespaces)
                        .components(separatedBy: ":").first?.trimmingCharacters(in: .whitespaces) ?? ""
                    return allowedStyles.contains(property)
                }
                .joined(separator: ";")
            
            let replacement = filteredStyles.isEmpty ? "" : "style=\"\(filteredStyles)\""
            
            if let fullRange = Range(fullMatchRange, in: result) {
                result.replaceSubrange(fullRange, with: replacement)
            }
        }
        
        return result
    }
    
    func analyzeComplexity(_ html: String) -> (size: Int, nestingDepth: Int, isComplex: Bool) {
        let size = html.count
        let nestingDepth = calculateNestingDepth(html)
        let isComplex = size > maxHTMLSize/2 || nestingDepth > maxNestingDepth/2
        
        logger.info("HTML analysis - Size: \(size), Nesting: \(nestingDepth), Complex: \(isComplex)")
        
        return (size, nestingDepth, isComplex)
    }
    
    private func calculateNestingDepth(_ html: String) -> Int {
        var maxDepth = 0
        var currentDepth = 0
        
        let pattern = #"</?(\w+)[^>]*>"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        
        regex?.enumerateMatches(in: html, range: range) { match, _, _ in
            guard let match = match,
                  let tagRange = Range(match.range, in: html) else { return }
            
            let tag = String(html[tagRange])
            if tag.hasPrefix("</") {
                currentDepth = max(0, currentDepth - 1)
            } else if !tag.hasSuffix("/>") {
                currentDepth += 1
                maxDepth = max(maxDepth, currentDepth)
            }
        }
        
        return maxDepth
    }
}

// MARK: - Async Email Renderer for EnhancedEmailContentView
@MainActor
class AsyncEmailRenderer: ObservableObject {
    // FIX: Explicitly use Logger to avoid name collision
    private let logger = Logger(subsystem: "com.diligence.app", category: "AsyncEmailRenderer")
    private let htmlProcessor = HTMLProcessor()
    
    @Published var isLoading = false
    @Published var error: EmailRenderError?
    @Published var shouldShowPlainText = false
    @Published var renderedContent: AttributedString?
    
    private var currentRenderingTask: _Concurrency.Task<Void, Never>?
    
    init() {
        // Explicit initializer to ensure proper ObservableObject setup
    }
    
    func renderEmail(content: String, timeoutSeconds: TimeInterval = 5.0) {
        // Cancel any existing rendering task
        cancel()
        
        isLoading = true
        error = nil
        renderedContent = nil
        shouldShowPlainText = false
        
        currentRenderingTask = _Concurrency.Task {
            await performEmailRendering(content: content, timeout: timeoutSeconds)
        }
    }
    
    func cancel() {
        currentRenderingTask?.cancel()
        currentRenderingTask = nil
        isLoading = false
    }
    
    private func performEmailRendering(content: String, timeout: TimeInterval) async {
        logger.info("Starting email content rendering")
        
        do {
            // Check if content looks like HTML
            if !content.contains("<") || !content.contains(">") {
                // Plain text content
                await MainActor.run {
                    self.renderedContent = AttributedString(content.formatPlainText())
                    self.isLoading = false
                }
                return
            }
            
            // Analyze complexity
            let complexity = htmlProcessor.analyzeComplexity(content)
            
            // If extremely complex, recommend plain text
            if complexity.size > htmlProcessor.maxHTMLSize || complexity.nestingDepth > htmlProcessor.maxNestingDepth {
                await MainActor.run {
                    self.error = .htmlTooComplex
                    self.shouldShowPlainText = true
                    self.isLoading = false
                }
                return
            }
            
            // Process HTML with timeout
            let processedHTML = await withTimeout(seconds: timeout) {
                await self.htmlProcessor.processHTML(content)
            }
            
            guard let processedHTML = processedHTML else {
                await MainActor.run {
                    self.error = .processingTimeout
                    self.isLoading = false
                }
                return
            }
            
            // Convert HTML to AttributedString
            let attributedString = try await convertHTMLToAttributedString(processedHTML)
            
            await MainActor.run {
                self.renderedContent = attributedString
                self.isLoading = false
                
                // Show plain text option for complex emails
                if complexity.isComplex {
                    self.shouldShowPlainText = true
                }
            }
            
            logger.info("Email rendering completed successfully")
            
        } catch {
            logger.error("Email rendering failed: \(error)")
            await MainActor.run {
                self.error = .renderingFailed
                self.isLoading = false
            }
        }
    }
    
    func extractPlainTextFromHTML(_ html: String) -> String {
        // Simple HTML to plain text conversion
        var plainText = html
        
        // Replace line breaks
        plainText = plainText.replacingOccurrences(of: "<br[^>]*>", with: "\n", options: [.regularExpression, .caseInsensitive])
        plainText = plainText.replacingOccurrences(of: "</p>", with: "\n\n", options: [.regularExpression, .caseInsensitive])
        plainText = plainText.replacingOccurrences(of: "</div>", with: "\n", options: [.regularExpression, .caseInsensitive])
        
        // Remove all HTML tags
        plainText = plainText.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        
        // Decode HTML entities
        plainText = plainText.replacingOccurrences(of: "&nbsp;", with: " ")
        plainText = plainText.replacingOccurrences(of: "&amp;", with: "&")
        plainText = plainText.replacingOccurrences(of: "&lt;", with: "<")
        plainText = plainText.replacingOccurrences(of: "&gt;", with: ">")
        plainText = plainText.replacingOccurrences(of: "&quot;", with: "\"")
        
        // Clean up whitespace
        plainText = plainText.replacingOccurrences(of: "\n\n\n+", with: "\n\n", options: .regularExpression)
        plainText = plainText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return plainText
    }
    
    private func convertHTMLToAttributedString(_ html: String) async throws -> AttributedString {
        // Create a simplified HTML document
        let document = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    line-height: 1.4;
                    margin: 0;
                    padding: 0;
                    max-width: 100%;
                    overflow-wrap: break-word;
                }
                img { max-width: 100%; height: auto; }
                table { max-width: 100%; }
            </style>
        </head>
        <body>
            \(html)
        </body>
        </html>
        """
        
        // Try to convert HTML to AttributedString
        if let data = document.data(using: .utf8) {
            do {
                let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ]
                
                let nsAttributedString = try NSAttributedString(data: data, options: options, documentAttributes: nil)
                return AttributedString(nsAttributedString)
            } catch {
                // Fallback to plain text if HTML conversion fails
                let plainText = extractPlainTextFromHTML(html)
                return AttributedString(plainText.formatPlainText())
            }
        } else {
            // Fallback to plain text
            let plainText = extractPlainTextFromHTML(html)
            return AttributedString(plainText.formatPlainText())
        }
    }
}

// MARK: - Legacy Email Renderer (for other parts of the app)
@MainActor
@Observable
class LegacyAsyncEmailRenderer {
    // FIX: Explicitly use Logger to avoid name collision
    private let logger = Logger(subsystem: "com.diligence.app", category: "EmailRenderer")
    private let htmlProcessor = HTMLProcessor()
    
    var state: EmailRenderingState = .loading
    var showPlainTextOption = false
    var renderingProgress: Double = 0.0
    
    private var currentRenderingTask: _Concurrency.Task<Void, Never>?
    
    // CORRECTED: Typo `forceePlainText` fixed to `forcePlainText`
    func renderEmail(_ email: Email, forcePlainText: Bool = false) {
        // Cancel any existing rendering task
        currentRenderingTask?.cancel()
        
        state = .loading
        renderingProgress = 0.0
        showPlainTextOption = false
        
        currentRenderingTask = _Concurrency.Task {
            await performEmailRendering(email, forcePlainText: forcePlainText)
        }
    }
    
    private func performEmailRendering(_ email: Email, forcePlainText: Bool) async {
        logger.info("Starting email rendering for: \(email.id)")
        
        // If forced to plain text or no HTML available
        guard !forcePlainText, let htmlBody = email.htmlBody, !htmlBody.isEmpty else {
            await updateState(.plainTextFallback(email.textBody))
            return
        }
        
        do {
            // Step 1: Analyze complexity (10%)
            await updateProgress(0.1)
            let complexity = htmlProcessor.analyzeComplexity(htmlBody)
            
            // If extremely complex, offer plain text immediately
            if complexity.size > htmlProcessor.maxHTMLSize || complexity.nestingDepth > htmlProcessor.maxNestingDepth {
                logger.warning("Email too complex - Size: \(complexity.size), Nesting: \(complexity.nestingDepth)")
                await updateState(.plainTextFallback(email.textBody))
                await updateShowPlainTextOption(true)
                return
            }
            
            // Step 2: Process HTML (50%)
            await updateProgress(0.5)
            let processedHTML = await withTimeout(seconds: 5.0) {
                await self.htmlProcessor.processHTML(htmlBody)
            }
            
            guard let processedHTML = processedHTML else {
                throw EmailRenderError.processingTimeout
            }
            
            // Step 3: Prepare for WebView (80%)
            await updateProgress(0.8)
            let safeHTML = await prepareHTMLForWebView(processedHTML, email: email)
            
            // Step 4: Complete (100%)
            await updateProgress(1.0)
            await updateState(.htmlReady(safeHTML))
            
            // Show plain text option for complex emails
            if complexity.isComplex {
                await updateShowPlainTextOption(true)
            }
            
            logger.info("Email rendering completed successfully")
            
        } catch {
            logger.error("Email rendering failed: \(error)")
            await handleRenderingError(error, fallbackText: email.textBody)
        }
    }
    
    private func prepareHTMLForWebView(_ html: String, email: Email) async -> String {
        let baseHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    line-height: 1.4;
                    margin: 0;
                    padding: 16px;
                    max-width: 100%;
                    overflow-wrap: break-word;
                }
                img { max-width: 100%; height: auto; }
                table { max-width: 100%; }
                .email-header {
                    border-bottom: 1px solid #e5e5e5;
                    margin-bottom: 16px;
                    padding-bottom: 12px;
                }
                .email-meta {
                    font-size: 14px;
                    color: #666;
                    margin-bottom: 8px;
                }
            </style>
        </head>
        <body>
            <div class="email-header">
                <div class="email-meta">From: \(email.sender)</div>
                <div class="email-meta">Date: \(DateFormatter.emailDisplay.string(from: email.date))</div>
                <h2>\(email.subject)</h2>
            </div>
            <div class="email-content">
                \(html)
            </div>
        </body>
        </html>
        """
        
        return baseHTML
    }
    
    private func handleRenderingError(_ error: Error, fallbackText: String) async {
        let errorMessage: String
        
        if let renderError = error as? EmailRenderError {
            errorMessage = renderError.errorDescription ?? "An unknown rendering error occurred."
        } else {
            errorMessage = "Unable to display HTML content: \(error.localizedDescription)"
        }
        
        logger.error("Rendering error: \(errorMessage)")
        await updateState(.plainTextFallback(fallbackText))
        await updateShowPlainTextOption(true)
    }
    
    private func updateState(_ newState: EmailRenderingState) async {
        await MainActor.run {
            self.state = newState
        }
    }
    
    private func updateProgress(_ progress: Double) async {
        await MainActor.run {
            self.renderingProgress = progress
        }
    }
    
    private func updateShowPlainTextOption(_ show: Bool) async {
        await MainActor.run {
            self.showPlainTextOption = show
        }
    }
    
    func cancelRendering() {
        currentRenderingTask?.cancel()
        currentRenderingTask = nil
    }
}


// MARK: - Email Rendering Errors
// CORRECT: Merged the two enums into one single, valid definition.
enum EmailRenderError: LocalizedError {
    case processingTimeout
    case renderingFailed
    case htmlTooComplex
    case webViewLoadFailure
    
    var errorDescription: String? {
        switch self {
        case .processingTimeout:
            return "Email rendering timed out"
        case .renderingFailed:
            return "Failed to render email content"
        case .htmlTooComplex:
            return "Email content is too complex"
        case .webViewLoadFailure:
            return "Failed to load email in web view"
        }
    }
}

// MARK: - Email View SwiftUI Component
struct EmailView: View {
    let email: Email
    @State private var renderer = LegacyAsyncEmailRenderer()
    @State private var showingPlainText = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            if renderer.showPlainTextOption {
                HStack {
                    Spacer()
                    Button(showingPlainText ? "Show HTML" : "Show Plain Text") {
                        if showingPlainText {
                            showingPlainText = false
                            // CORRECTED: Typo `forceePlainText` fixed
                            renderer.renderEmail(email, forcePlainText: false)
                        } else {
                            showingPlainText = true
                            renderer.renderEmail(email, forcePlainText: true)
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))
                Divider()
            }
            
            // Content
            switch renderer.state {
            case .loading:
                loadingView
            case .htmlReady(let html):
                EmailWebView(htmlContent: html)
            case .plainTextFallback(let text):
                plainTextView(text)
            case .error(let message):
                errorView(message)
            }
        }
        .task {
            renderer.renderEmail(email)
        }
        .onDisappear {
            renderer.cancelRendering()
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView(value: renderer.renderingProgress)
                .progressViewStyle(LinearProgressViewStyle())
                .frame(width: 200)
            
            Text("Loading email content...")
                .foregroundColor(.secondary)
            
            Button("Cancel") {
                renderer.cancelRendering()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.textBackgroundColor))
    }
    
    private func plainTextView(_ text: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Email header
                VStack(alignment: .leading, spacing: 4) {
                    Text("From: \(email.sender)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Date: \(DateFormatter.emailDisplay.string(from: email.date))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(email.subject)
                        .font(.headline)
                        .padding(.top, 4)
                }
                .padding(.bottom, 8)
                
                Divider()
                
                // Plain text content
                Text(text)
                    .textSelection(.enabled)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
        }
        .background(Color(NSColor.textBackgroundColor))
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            
            Text("Unable to Display Email")
                .font(.headline)
            
            Text(message)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Show Plain Text Instead") {
                showingPlainText = true
                renderer.renderEmail(email, forcePlainText: true)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.textBackgroundColor))
    }
}

// MARK: - WebView Component
struct EmailWebView: NSViewRepresentable {
    let htmlContent: String
    
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        
        // Disable JavaScript for security
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        
        // Configure for email display
        config.suppressesIncrementalRendering = true
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        
        // Configure appearance
        webView.setValue(false, forKey: "drawsBackground")
        
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(htmlContent, baseURL: nil)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Only allow the initial load, block all other navigation
            if navigationAction.navigationType == .other {
                decisionHandler(.allow)
            } else {
                decisionHandler(.cancel)
            }
        }
    }
}

// MARK: - Utility Extensions
extension DateFormatter {
    static let emailDisplay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

extension String {
    func formatPlainText() -> String {
        // Clean up whitespace and ensure proper line spacing
        var formatted = self
        
        // Normalize line breaks
        formatted = formatted.replacingOccurrences(of: "\r\n", with: "\n")
        formatted = formatted.replacingOccurrences(of: "\r", with: "\n")
        
        // Remove excessive blank lines (more than 2 consecutive)
        formatted = formatted.replacingOccurrences(of: "\n\n\n+", with: "\n\n", options: .regularExpression)
        
        // Trim leading and trailing whitespace
        formatted = formatted.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return formatted
    }
}

// MARK: - Timeout Utility
// CORRECT: Changed the operation to be non-throwing to match its usage.
func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async -> T) async -> T? {
    return await withTaskGroup(of: Optional<T>.self) { group in
        group.addTask {
            return await operation()
        }
        
        group.addTask {
            try? await _Concurrency.Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            return nil
        }
        
        let result = await group.next()
        group.cancelAll()
        return result ?? nil // This will be the result of the first task to finish
    }
}
