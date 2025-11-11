//  EnhancedEmailContentView.swift
//  Diligence
//
//  Enhanced email content display with async rendering and fallback support
//

import SwiftUI
import Combine

// MARK: - Email Rendering Preferences
struct EmailRenderingPreferences {
    static var preferPlainText: Bool {
        UserDefaults.standard.bool(forKey: "preferPlainTextEmail")
    }
    
    static var renderTimeout: TimeInterval {
        let timeout = UserDefaults.standard.double(forKey: "emailRenderTimeout")
        return timeout > 0 ? timeout : 5.0 // Default to 5 seconds
    }
    
    static func setPreferPlainText(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: "preferPlainTextEmail")
    }
    
    static func setRenderTimeout(_ value: TimeInterval) {
        UserDefaults.standard.set(value, forKey: "emailRenderTimeout")
    }
}

struct EnhancedEmailContentView: View {
    let content: String
    @StateObject private var renderer = AsyncEmailRenderer()
    @State private var forcePlainText = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Render controls and status
            if renderer.error != nil || renderer.isLoading {
                renderingStatusView
            }
            
            // Main content
            contentView
        }
        .onAppear {
            startRendering()
        }
        .onDisappear {
            renderer.cancel()
        }
        .onChange(of: content) { _, _ in
            startRendering()
        }
    }
    
    @ViewBuilder
    private var renderingStatusView: some View {
        HStack {
            if renderer.isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 14, height: 14)
                    
                    Text("Rendering email content...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if let error = renderer.error {
                errorBannerView(error: error)
            }
            
            Spacer()
            
            // Always show plain text toggle
            plainTextToggle
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(6)
    }
    
    @ViewBuilder
    private func errorBannerView(error: EmailRenderError) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.caption)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Rendering Issue")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.orange)
                
                Text(error.errorDescription ?? "Unknown error")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if error.shouldShowRetry {
                Button("Retry") {
                    startRendering()
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .controlSize(.mini)
            }
        }
    }
    
    @ViewBuilder
    private var plainTextToggle: some View {
        Button(action: { 
            forcePlainText.toggle()
        }) {
            HStack(spacing: 4) {
                Image(systemName: forcePlainText ? "doc.text" : "doc.richtext")
                    .font(.caption)
                
                Text(forcePlainText ? "Rich" : "Plain")
                    .font(.caption2)
            }
        }
        .buttonStyle(.borderless)
        .help(forcePlainText ? "Switch to rich text view" : "Switch to plain text view")
    }
    
    @ViewBuilder
    private var contentView: some View {
        if renderer.isLoading {
            loadingView
        } else if forcePlainText || renderer.shouldShowPlainText {
            plainTextView
        } else if let renderedContent = renderer.renderedContent {
            richTextView(renderedContent)
        } else {
            fallbackView
        }
    }
    
    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(0.8)
            
            Text("Loading email content...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .frame(alignment: .center)
    }
    
    @ViewBuilder
    private var plainTextView: some View {
        ScrollView {
            Text(extractPlainText(from: content))
                .textSelection(.enabled)
                .lineSpacing(4)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
        }
    }
    
    @ViewBuilder
    private func richTextView(_ attributedString: AttributedString) -> some View {
        ScrollView {
            Text(attributedString)
                .textSelection(.enabled)
                .lineSpacing(4)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 8)
        }
    }
    
    @ViewBuilder
    private var fallbackView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.orange)
                .font(.title2)
            
            Text("Unable to display email content")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("The email content could not be rendered. Try switching to plain text view.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("View as Plain Text") {
                forcePlainText = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .padding()
    }
    
    private func startRendering() {
        // Check if user prefers plain text
        if EmailRenderingPreferences.preferPlainText || forcePlainText {
            return // Don't render HTML if forcing plain text
        }
        
        // Check if content looks like HTML
        if content.contains("<") && content.contains(">") {
            renderer.renderEmail(
                content: content, 
                timeoutSeconds: EmailRenderingPreferences.renderTimeout
            )
        } else {
            // Plain text content - no need for async rendering
            renderer.renderedContent = AttributedString(content.formatPlainText())
        }
    }
    
    private func extractPlainText(from html: String) -> String {
        // Use the same plain text extraction as the renderer
        let plainTextRenderer = AsyncEmailRenderer()
        return plainTextRenderer.extractPlainTextFromHTML(html)
    }
}

// MARK: - Extensions

extension EmailRenderError {
    var shouldShowRetry: Bool {
        switch self {
        case .processingTimeout, .renderingFailed, .webViewLoadFailure:
            return true
        case .htmlTooComplex:
            return false
        }
    }
}

