//
//  LoadingOverlay.swift
//  Diligence
//
//  Loading overlay component with customizable appearance
//

import SwiftUI

// MARK: - Loading Overlay

/// A customizable loading overlay that can be applied to any view
///
/// LoadingOverlay displays a semi-transparent overlay with a progress indicator
/// and optional message. It blocks user interaction while visible.
///
/// ## Example
/// ```swift
/// ContentView()
///     .loadingOverlay(
///         isShowing: viewModel.isLoading,
///         message: "Loading emails..."
///     )
/// ```
///
/// ## Accessibility
/// - Announces loading state to VoiceOver
/// - Message is read aloud
/// - Automatically blocks interaction
/// - Progress indicator has label
struct LoadingOverlay: View {
    
    // MARK: - Properties
    
    /// Whether the overlay is showing
    let isShowing: Bool
    
    /// Optional message to display
    let message: String?
    
    /// Progress value (0.0 to 1.0, nil for indeterminate)
    let progress: Double?
    
    /// Overlay style
    let style: LoadingStyle
    
    /// Whether to allow dismissal
    let isDismissible: Bool
    
    /// Dismiss action
    let onDismiss: (() -> Void)?
    
    // MARK: - State
    
    @State private var rotationAngle: Double = 0
    @State private var scale: CGFloat = 1.0
    
    // MARK: - Initialization
    
    /// Creates a loading overlay
    ///
    /// - Parameters:
    ///   - isShowing: Whether to show the overlay
    ///   - message: Optional loading message
    ///   - progress: Optional progress value (0.0-1.0)
    ///   - style: Visual style of the overlay
    ///   - isDismissible: Whether user can dismiss
    ///   - onDismiss: Action when dismissed
    init(
        isShowing: Bool,
        message: String? = nil,
        progress: Double? = nil,
        style: LoadingStyle = .standard,
        isDismissible: Bool = false,
        onDismiss: (() -> Void)? = nil
    ) {
        self.isShowing = isShowing
        self.message = message
        self.progress = progress
        self.style = style
        self.isDismissible = isDismissible
        self.onDismiss = onDismiss
    }
    
    // MARK: - Body
    
    var body: some View {
        if isShowing {
            ZStack {
                // Backdrop
                Color.black
                    .opacity(style.backdropOpacity)
                    .ignoresSafeArea()
                    .onTapGesture {
                        if isDismissible {
                            onDismiss?()
                        }
                    }
                
                // Loading container
                VStack(spacing: style.spacing) {
                    // Progress indicator
                    if let progress = progress {
                        // Determinate progress
                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                                .frame(width: style.indicatorSize, height: style.indicatorSize)
                            
                            Circle()
                                .trim(from: 0, to: CGFloat(progress))
                                .stroke(
                                    Color.accentColor,
                                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                                )
                                .frame(width: style.indicatorSize, height: style.indicatorSize)
                                .rotationEffect(.degrees(-90))
                            
                            Text("\(Int(progress * 100))%")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                        }
                    } else {
                        // Indeterminate progress
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(style.progressScale)
                            .frame(width: style.indicatorSize, height: style.indicatorSize)
                    }
                    
                    // Message
                    if let message = message {
                        Text(message)
                            .font(style.messageFont)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    // Cancel button (if dismissible)
                    if isDismissible {
                        Button("Cancel") {
                            onDismiss?()
                        }
                        .font(.system(size: 13))
                        .padding(.top, 8)
                    }
                }
                .padding(style.containerPadding)
                .background(containerBackground)
                .cornerRadius(style.cornerRadius)
                .shadow(radius: style.shadowRadius)
                .scaleEffect(scale)
                .onAppear {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        scale = 1.0
                    }
                }
            }
            .transition(.opacity)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Loading")
            .accessibilityValue(accessibilityValue)
            .accessibilityAddTraits(.updatesFrequently)
        }
    }
    
    // MARK: - Computed Properties
    
    /// Container background with blur effect
    private var containerBackground: some View {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
            .opacity(0.95)
        #else
        return Color(UIColor.systemBackground)
            .opacity(0.95)
        #endif
    }
    
    /// Accessibility value
    private var accessibilityValue: String {
        if let progress = progress {
            return "\(Int(progress * 100)) percent complete"
        } else if let message = message {
            return message
        } else {
            return "Loading"
        }
    }
}

// MARK: - Loading Style

/// Visual styles for loading overlay
enum LoadingStyle {
    case minimal
    case standard
    case detailed
    
    var backdropOpacity: Double {
        switch self {
        case .minimal: return 0.1
        case .standard: return 0.3
        case .detailed: return 0.5
        }
    }
    
    var indicatorSize: CGFloat {
        switch self {
        case .minimal: return 30
        case .standard: return 40
        case .detailed: return 50
        }
    }
    
    var progressScale: CGFloat {
        switch self {
        case .minimal: return 1.0
        case .standard: return 1.5
        case .detailed: return 2.0
        }
    }
    
    var spacing: CGFloat {
        switch self {
        case .minimal: return 8
        case .standard: return 16
        case .detailed: return 20
        }
    }
    
    var containerPadding: CGFloat {
        switch self {
        case .minimal: return 20
        case .standard: return 24
        case .detailed: return 32
        }
    }
    
    var cornerRadius: CGFloat {
        switch self {
        case .minimal: return 8
        case .standard: return 12
        case .detailed: return 16
        }
    }
    
    var shadowRadius: CGFloat {
        switch self {
        case .minimal: return 5
        case .standard: return 10
        case .detailed: return 15
        }
    }
    
    var messageFont: Font {
        switch self {
        case .minimal: return .system(size: 12)
        case .standard: return .system(size: 14)
        case .detailed: return .system(size: 16, weight: .medium)
        }
    }
}

// MARK: - View Extension

extension View {
    /// Applies a loading overlay to the view
    ///
    /// - Parameters:
    ///   - isShowing: Whether to show the overlay
    ///   - message: Optional loading message
    ///   - progress: Optional progress value (0.0-1.0)
    ///   - style: Visual style
    ///   - isDismissible: Whether user can dismiss
    ///   - onDismiss: Dismiss action
    /// - Returns: View with loading overlay
    func loadingOverlay(
        isShowing: Bool,
        message: String? = nil,
        progress: Double? = nil,
        style: LoadingStyle = .standard,
        isDismissible: Bool = false,
        onDismiss: (() -> Void)? = nil
    ) -> some View {
        overlay {
            LoadingOverlay(
                isShowing: isShowing,
                message: message,
                progress: progress,
                style: style,
                isDismissible: isDismissible,
                onDismiss: onDismiss
            )
        }
    }
}

// MARK: - Preview

#Preview("Loading Overlay Styles") {
    VStack(spacing: 20) {
        Text("Content Behind Overlay")
            .font(.title)
        
        Rectangle()
            .fill(Color.blue.opacity(0.2))
            .frame(height: 200)
    }
    .padding()
    .loadingOverlay(
        isShowing: true,
        message: "Loading data...",
        style: .standard
    )
}

#Preview("With Progress") {
    VStack {
        Text("Downloading...")
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .loadingOverlay(
        isShowing: true,
        message: "Downloading files...",
        progress: 0.65,
        style: .detailed
    )
}

#Preview("Dismissible") {
    VStack {
        Text("Content")
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .loadingOverlay(
        isShowing: true,
        message: "Processing...\nThis may take a while",
        style: .standard,
        isDismissible: true,
        onDismiss: {
            print("Dismissed")
        }
    )
}

#Preview("Minimal Style") {
    VStack {
        Text("Content")
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .loadingOverlay(
        isShowing: true,
        message: "Loading...",
        style: .minimal
    )
}

#Preview("Dark Mode") {
    VStack {
        Text("Content")
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .loadingOverlay(
        isShowing: true,
        message: "Syncing with server...",
        style: .standard
    )
    .preferredColorScheme(.dark)
}
