//
//  PrimaryButton.swift
//  Diligence
//
//  Primary button component with consistent styling
//

import SwiftUI

// MARK: - Primary Button

/// A primary action button with consistent styling across the app
///
/// Primary buttons are used for the main action in a view or dialog.
/// They feature a filled background with the accent color and are
/// prominently displayed.
///
/// ## Example
/// ```swift
/// PrimaryButton("Save Changes") {
///     saveData()
/// }
/// .disabled(hasErrors)
/// ```
///
/// ## Accessibility
/// - Automatically includes accessibility labels
/// - Supports dynamic type scaling
/// - Works with VoiceOver
/// - Keyboard navigable
///
/// ## Styling
/// - Uses app accent color
/// - Rounded corners (8pt)
/// - Padding (12pt horizontal, 8pt vertical)
/// - Hover effects on macOS
/// - Disabled state styling
struct PrimaryButton: View {
    
    // MARK: - Properties
    
    /// The button label
    private let title: String
    
    /// Optional SF Symbol icon name
    private let iconName: String?
    
    /// The action to perform when tapped
    private let action: () -> Void
    
    /// Whether the button is loading
    @Binding private var isLoading: Bool
    
    /// Whether the button is disabled
    private let isDisabled: Bool
    
    /// Button size variant
    private let size: ButtonSize
    
    // MARK: - State
    
    @State private var isHovered: Bool = false
    
    // MARK: - Initialization
    
    /// Creates a primary button with a title
    ///
    /// - Parameters:
    ///   - title: The button label text
    ///   - icon: Optional SF Symbol name to show before text
    ///   - isLoading: Binding to loading state (shows spinner)
    ///   - isDisabled: Whether the button is disabled
    ///   - size: Button size variant
    ///   - action: The action to perform when tapped
    init(
        _ title: String,
        icon: String? = nil,
        isLoading: Binding<Bool> = .constant(false),
        isDisabled: Bool = false,
        size: ButtonSize = .regular,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.iconName = icon
        self._isLoading = isLoading
        self.isDisabled = isDisabled
        self.size = size
        self.action = action
    }
    
    // MARK: - Body
    
    var body: some View {
        Button(action: handleTap) {
            HStack(spacing: size.iconSpacing) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(size.progressScale)
                        .frame(width: size.iconSize, height: size.iconSize)
                } else if let iconName = iconName {
                    Image(systemName: iconName)
                        .font(.system(size: size.iconSize))
                }
                
                Text(title)
                    .font(size.font)
                    .fontWeight(.medium)
            }
            .foregroundColor(.white)
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .frame(minWidth: size.minWidth)
            .background(backgroundColor)
            .cornerRadius(size.cornerRadius)
            .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowY)
        }
        .buttonStyle(PlainButtonStyle()) // Remove default button styling
        .disabled(isDisabled || isLoading)
        .onHover({ hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        })
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(.isButton)
        .help(title) // Tooltip on hover (macOS)
    }
    
    // MARK: - Computed Properties
    
    /// Background color based on state
    private var backgroundColor: Color {
        if isDisabled {
            return Color.gray.opacity(0.3)
        } else if isHovered {
            return Color.accentColor.opacity(0.85)
        } else {
            return Color.accentColor
        }
    }
    
    /// Shadow color based on state
    private var shadowColor: Color {
        if isDisabled || isLoading {
            return Color.clear
        } else if isHovered {
            return Color.accentColor.opacity(0.4)
        } else {
            return Color.accentColor.opacity(0.2)
        }
    }
    
    /// Shadow radius based on state
    private var shadowRadius: CGFloat {
        isHovered ? 8 : 4
    }
    
    /// Shadow Y offset
    private var shadowY: CGFloat {
        isHovered ? 4 : 2
    }
    
    /// Accessibility label
    private var accessibilityLabel: String {
        if isLoading {
            return "\(title), loading"
        } else {
            return title
        }
    }
    
    /// Accessibility hint
    private var accessibilityHint: String {
        if isDisabled {
            return "Button is disabled"
        } else if isLoading {
            return "Please wait"
        } else {
            return "Double tap to activate"
        }
    }
    
    // MARK: - Actions
    
    /// Handles button tap with haptic feedback
    private func handleTap() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        #endif
        
        action()
    }
}

// MARK: - Button Size

/// Button size variants
enum ButtonSize {
    case small
    case regular
    case large
    
    var font: Font {
        switch self {
        case .small: return .system(size: 12)
        case .regular: return .system(size: 14)
        case .large: return .system(size: 16)
        }
    }
    
    var horizontalPadding: CGFloat {
        switch self {
        case .small: return 12
        case .regular: return 16
        case .large: return 20
        }
    }
    
    var verticalPadding: CGFloat {
        switch self {
        case .small: return 6
        case .regular: return 8
        case .large: return 10
        }
    }
    
    var iconSize: CGFloat {
        switch self {
        case .small: return 12
        case .regular: return 14
        case .large: return 16
        }
    }
    
    var iconSpacing: CGFloat {
        switch self {
        case .small: return 4
        case .regular: return 6
        case .large: return 8
        }
    }
    
    var progressScale: CGFloat {
        switch self {
        case .small: return 0.7
        case .regular: return 0.8
        case .large: return 1.0
        }
    }
    
    var minWidth: CGFloat {
        switch self {
        case .small: return 60
        case .regular: return 80
        case .large: return 100
        }
    }
    
    var cornerRadius: CGFloat {
        switch self {
        case .small: return 6
        case .regular: return 8
        case .large: return 10
        }
    }
}

// MARK: - Preview

#Preview("Primary Button States") {
    VStack(spacing: 20) {
        // Regular state
        PrimaryButton("Save Changes", icon: "checkmark") {
            print("Save tapped")
        }
        
        // Loading state
        PrimaryButton("Processing", isLoading: .constant(true)) {
            print("Processing")
        }
        
        // Disabled state
        PrimaryButton("Submit", isDisabled: true) {
            print("Submit")
        }
        
        // Different sizes
        HStack(spacing: 12) {
            PrimaryButton("Small", size: .small) {
                print("Small")
            }
            
            PrimaryButton("Regular", size: .regular) {
                print("Regular")
            }
            
            PrimaryButton("Large", size: .large) {
                print("Large")
            }
        }
        
        // With icons
        VStack(spacing: 12) {
            PrimaryButton("Add Task", icon: "plus") {
                print("Add task")
            }
            
            PrimaryButton("Delete", icon: "trash") {
                print("Delete")
            }
            
            PrimaryButton("Refresh", icon: "arrow.clockwise") {
                print("Refresh")
            }
        }
    }
    .padding()
    .frame(width: 400)
}

#Preview("Dark Mode") {
    VStack(spacing: 20) {
        PrimaryButton("Save Changes", icon: "checkmark") {
            print("Save")
        }
        
        PrimaryButton("Delete", icon: "trash") {
            print("Delete")
        }
    }
    .padding()
    .preferredColorScheme(.dark)
}
