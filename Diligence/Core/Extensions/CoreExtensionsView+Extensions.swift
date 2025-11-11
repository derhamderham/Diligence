//
//  View+Extensions.swift
//  Diligence
//
//  SwiftUI View modifiers and utilities
//

import SwiftUI

// MARK: - Conditional Modifiers

extension View {
    /// Applies a modifier conditionally
    ///
    /// - Parameters:
    ///   - condition: Whether to apply the modifier
    ///   - modifier: The modifier to apply
    /// - Returns: Modified view
    ///
    /// Example:
    /// ```swift
    /// Text("Hello")
    ///     .if(isError) { view in
    ///         view.foregroundColor(.red)
    ///     }
    /// ```
    @ViewBuilder
    func `if`<Transform: View>(
        _ condition: Bool,
        transform: (Self) -> Transform
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    /// Applies one of two modifiers based on a condition
    ///
    /// - Parameters:
    ///   - condition: The condition to check
    ///   - trueTransform: Modifier to apply if true
    ///   - falseTransform: Modifier to apply if false
    /// - Returns: Modified view
    ///
    /// Example:
    /// ```swift
    /// Text("Hello")
    ///     .if(isDark,
    ///         then: { $0.foregroundColor(.white) },
    ///         else: { $0.foregroundColor(.black) })
    /// ```
    @ViewBuilder
    func `if`<TrueContent: View, FalseContent: View>(
        _ condition: Bool,
        then trueTransform: (Self) -> TrueContent,
        else falseTransform: (Self) -> FalseContent
    ) -> some View {
        if condition {
            trueTransform(self)
        } else {
            falseTransform(self)
        }
    }
}

// MARK: - Loading Overlay

extension View {
    /// Adds a loading overlay to the view
    ///
    /// - Parameters:
    ///   - isLoading: Whether to show the loading indicator
    ///   - text: Optional text to display below the spinner
    /// - Returns: View with loading overlay
    ///
    /// Example:
    /// ```swift
    /// ContentView()
    ///     .loading(isLoading: viewModel.isLoading)
    /// ```
    func loading(isLoading: Bool, text: String? = nil) -> some View {
        overlay {
            if isLoading {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(1.5)
                        
                        if let text = text {
                            Text(text)
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.all, 24)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(NSColor.windowBackgroundColor))
                            .shadow(radius: 10)
                    )
                }
            }
        }
    }
}

// MARK: - Error Overlay

extension View {
    /// Displays an error message overlay
    ///
    /// - Parameters:
    ///   - error: Optional error to display
    ///   - onDismiss: Closure called when error is dismissed
    /// - Returns: View with error overlay
    func errorOverlay(
        error: Error?,
        onDismiss: @escaping () -> Void
    ) -> some View {
        let hasError = error != nil
        
        return overlay {
            if let error = error {
                VStack {
                    Spacer()
                    
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        
                        Text(error.localizedDescription)
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Button(action: onDismiss) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(NSColor.windowBackgroundColor))
                            .shadow(radius: 5)
                    )
                    .padding()
                }
                .transition(.move(edge: .bottom))
                .animation(.spring(), value: hasError)
            }
        }
    }
}

// MARK: - Card Style

extension View {
    /// Applies a card-style appearance
    ///
    /// - Parameters:
    ///   - insets: Inner padding (default: 16)
    ///   - cornerRadius: Corner radius (default: 12)
    ///   - shadowRadius: Shadow radius (default: 2)
    /// - Returns: View with card styling
    ///
    /// Example:
    /// ```swift
    /// VStack {
    ///     Text("Card Content")
    /// }
    /// .cardStyle()
    /// ```
    func cardStyle(
        insets: CGFloat = 16,
        cornerRadius: CGFloat = 12,
        shadowRadius: CGFloat = 2
    ) -> some View {
        self
            .padding(.all, insets)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .shadow(radius: shadowRadius)
            )
    }
}

// MARK: - Placeholder

extension View {
    /// Shows a placeholder when content is empty
    ///
    /// - Parameters:
    ///   - isEmpty: Whether to show placeholder
    ///   - placeholder: The placeholder view
    /// - Returns: Original view or placeholder
    ///
    /// Example:
    /// ```swift
    /// List(items) { item in
    ///     Text(item.name)
    /// }
    /// .placeholder(items.isEmpty) {
    ///     Text("No items")
    /// }
    /// ```
    @ViewBuilder
    func placeholder<PlaceholderView: View>(
        _ isEmpty: Bool,
        @ViewBuilder placeholder: () -> PlaceholderView
    ) -> some View {
        if isEmpty {
            placeholder()
        } else {
            self
        }
    }
}

// MARK: - Debug Border

extension View {
    /// Adds a colored border for debugging layouts
    ///
    /// Only visible in DEBUG builds
    ///
    /// - Parameters:
    ///   - color: Border color (default: red)
    ///   - width: Border width (default: 1)
    /// - Returns: View with debug border
    func debugBorder(_ color: Color = .red, width: CGFloat = 1) -> some View {
        #if DEBUG
        return self.border(color, width: width)
        #else
        return self
        #endif
    }
}

// MARK: - Keyboard Shortcuts

extension View {
    /// Adds a keyboard shortcut with a command modifier
    ///
    /// - Parameters:
    ///   - key: The keyboard key
    ///   - action: Action to perform
    /// - Returns: View with keyboard shortcut
    func commandShortcut(_ key: KeyEquivalent, action: @escaping () -> Void) -> some View {
        self.keyboardShortcut(key, modifiers: .command)
    }
}

// MARK: - Hover Effect

extension View {
    /// Adds a hover effect that changes appearance on mouse over
    ///
    /// - Parameter action: Closure called with hover state
    /// - Returns: View with hover tracking
    ///
    /// Example:
    /// ```swift
    /// Text("Hover me")
    ///     .hoverEffect { isHovered in
    ///         isHovered ? .blue : .primary
    ///     }
    /// ```
    func onHover(_ action: @escaping (Bool) -> Void) -> some View {
        self.onContinuousHover { phase in
            switch phase {
            case .active:
                action(true)
            case .ended:
                action(false)
            }
        }
    }
}

// MARK: - Frame Utilities

extension View {
    /// Sets a square frame
    ///
    /// - Parameter size: The width and height
    /// - Returns: View with square frame
    func frame(size: CGFloat) -> some View {
        frame(width: size, height: size)
    }
    
    /// Sets maximum width and height to infinity
    ///
    /// - Parameter alignment: Alignment (default: center)
    /// - Returns: View filling available space
    func fillMaxSize(alignment: Alignment = .center) -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
    }
    
    /// Sets maximum width to infinity
    ///
    /// - Parameter alignment: Alignment (default: center)
    /// - Returns: View filling available width
    func fillMaxWidth(alignment: Alignment = .center) -> some View {
        frame(maxWidth: .infinity, alignment: alignment)
    }
    
    /// Sets maximum height to infinity
    ///
    /// - Parameter alignment: Alignment (default: center)
    /// - Returns: View filling available height
    func fillMaxHeight(alignment: Alignment = .center) -> some View {
        frame(maxHeight: .infinity, alignment: alignment)
    }
}

// MARK: - Hidden Modifier

extension View {
    /// Hides the view conditionally
    ///
    /// - Parameter hidden: Whether to hide the view
    /// - Returns: View that may be hidden
    @ViewBuilder
    func hidden(_ hidden: Bool) -> some View {
        if hidden {
            self.hidden()
        } else {
            self
        }
    }
}

// MARK: - Corner Radius with Specific Corners

extension View {
    /// Applies corner radius to specific corners
    ///
    /// - Parameters:
    ///   - radius: Corner radius
    ///   - corners: Which corners to round
    /// - Returns: View with rounded corners
    func cornerRadius(_ radius: CGFloat, corners: RectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

/// Helper shape for rounding specific corners
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: RectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let topLeft = rect.origin
        let topRight = CGPoint(x: rect.maxX, y: rect.minY)
        let bottomRight = CGPoint(x: rect.maxX, y: rect.maxY)
        let bottomLeft = CGPoint(x: rect.minX, y: rect.maxY)
        
        // Start from top left (accounting for rounded corner if needed)
        if corners.contains(.topLeft) {
            path.move(to: CGPoint(x: topLeft.x, y: topLeft.y + radius))
            path.addArc(
                center: CGPoint(x: topLeft.x + radius, y: topLeft.y + radius),
                radius: radius,
                startAngle: .degrees(180),
                endAngle: .degrees(270),
                clockwise: false
            )
        } else {
            path.move(to: topLeft)
        }
        
        // Top right corner
        if corners.contains(.topRight) {
            path.addLine(to: CGPoint(x: topRight.x - radius, y: topRight.y))
            path.addArc(
                center: CGPoint(x: topRight.x - radius, y: topRight.y + radius),
                radius: radius,
                startAngle: .degrees(270),
                endAngle: .degrees(0),
                clockwise: false
            )
        } else {
            path.addLine(to: topRight)
        }
        
        // Bottom right corner
        if corners.contains(.bottomRight) {
            path.addLine(to: CGPoint(x: bottomRight.x, y: bottomRight.y - radius))
            path.addArc(
                center: CGPoint(x: bottomRight.x - radius, y: bottomRight.y - radius),
                radius: radius,
                startAngle: .degrees(0),
                endAngle: .degrees(90),
                clockwise: false
            )
        } else {
            path.addLine(to: bottomRight)
        }
        
        // Bottom left corner
        if corners.contains(.bottomLeft) {
            path.addLine(to: CGPoint(x: bottomLeft.x + radius, y: bottomLeft.y))
            path.addArc(
                center: CGPoint(x: bottomLeft.x + radius, y: bottomLeft.y - radius),
                radius: radius,
                startAngle: .degrees(90),
                endAngle: .degrees(180),
                clockwise: false
            )
        } else {
            path.addLine(to: bottomLeft)
        }
        
        path.closeSubpath()
        return path
    }
}

/// Corner specification
nonisolated struct RectCorner: OptionSet, Sendable {
    let rawValue: Int
    
    static let topLeft = RectCorner(rawValue: 1 << 0)
    static let topRight = RectCorner(rawValue: 1 << 1)
    static let bottomLeft = RectCorner(rawValue: 1 << 2)
    static let bottomRight = RectCorner(rawValue: 1 << 3)
    
    static let allCorners: RectCorner = [.topLeft, .topRight, .bottomLeft, .bottomRight]
    static let topCorners: RectCorner = [.topLeft, .topRight]
    static let bottomCorners: RectCorner = [.bottomLeft, .bottomRight]
    static let leftCorners: RectCorner = [.topLeft, .bottomLeft]
    static let rightCorners: RectCorner = [.topRight, .bottomRight]
}

// MARK: - NSBezierPath Extension

extension NSBezierPath {
    /// Converts NSBezierPath to CGPath for use in SwiftUI
    var cgPath: CGPath {
        let path = CGMutablePath()
        var points = [CGPoint](repeating: .zero, count: 3)
        
        for i in 0..<elementCount {
            let type = element(at: i, associatedPoints: &points)
            switch type {
            case .moveTo:
                path.move(to: points[0])
            case .lineTo:
                path.addLine(to: points[0])
            case .curveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .closePath:
                path.closeSubpath()
            case .cubicCurveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .quadraticCurveTo:
                path.addQuadCurve(to: points[1], control: points[0])
            @unknown default:
                break
            }
        }
        
        return path
    }
}
