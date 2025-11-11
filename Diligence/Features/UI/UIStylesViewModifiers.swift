//
//  ViewModifiers.swift
//  Diligence
//
//  Custom view modifiers for common styling patterns
//

import SwiftUI

// MARK: - Card Style

/// Applies card styling with shadow and background
extension View {
    func paddingEdges(_ insets: EdgeInsets) -> some View {
        self.padding(.top, insets.top)
            .padding(.leading, insets.leading)
            .padding(.bottom, insets.bottom)
            .padding(.trailing, insets.trailing)
    }
}

struct CardModifier: ViewModifier {
    let cardPadding: CGFloat
    let cornerRadius: CGFloat
    let shadow: Shadows.ShadowStyle
    
    func body(content: Content) -> some View {
        content
            .padding(.all, cardPadding)
            .background(Theme.colors.background.secondary)
            .cornerRadius(cornerRadius)
            .themeShadow(shadow)
    }
}

extension View {
    /// Applies card styling
    func cardStyle(
        padding: CGFloat = Theme.spacing.md,
        cornerRadius: CGFloat = Theme.cornerRadius.card,
        shadow: Shadows.ShadowStyle = Theme.shadows.card
    ) -> some View {
        modifier(CardModifier(cardPadding: padding, cornerRadius: cornerRadius, shadow: shadow))
    }
}

// MARK: - Section Header Style

/// Applies section header styling
struct SectionHeaderModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .textStyle(Theme.typography.subheadline)
            .foregroundColor(Theme.colors.text.secondary)
            .textCase(.uppercase)
            .tracking(0.5)
    }
}

extension View {
    /// Applies section header styling
    func sectionHeaderStyle() -> some View {
        modifier(SectionHeaderModifier())
    }
}

// MARK: - Primary Button Style

/// Custom button style for primary actions
struct ThemePrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.typography.button.font)
            .foregroundColor(Theme.colors.text.inverse)
            .padding(.horizontal, Theme.spacing.md as CGFloat)
            .padding(.vertical, Theme.spacing.sm as CGFloat)
            .background(backgroundColor(isPressed: configuration.isPressed))
            .cornerRadius(Theme.cornerRadius.button)
            .themeShadow(isEnabled ? Theme.shadows.button : Theme.shadows.none)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(Theme.animations.buttonTap, value: configuration.isPressed)
            .onHover({ (hovering: Bool) in
                isHovered = hovering
            })
    }
    
    private func backgroundColor(isPressed: Bool) -> Color {
        if !isEnabled {
            return Theme.colors.brand.primaryDisabled
        } else if isPressed {
            return Theme.colors.brand.primaryPressed
        } else if isHovered {
            return Theme.colors.brand.primaryHover
        } else {
            return Theme.colors.brand.primary
        }
    }
}

extension ButtonStyle where Self == ThemePrimaryButtonStyle {
    static var themePrimary: ThemePrimaryButtonStyle {
        ThemePrimaryButtonStyle()
    }
}

// MARK: - Status Badge

/// Applies status badge styling
struct StatusBadgeModifier: ViewModifier {
    let status: StatusType
    
    enum StatusType {
        case success, error, warning, info
        
        var color: Color {
            switch self {
            case .success: return Theme.colors.status.success
            case .error: return Theme.colors.status.error
            case .warning: return Theme.colors.status.warning
            case .info: return Theme.colors.status.info
            }
        }
        
        var backgroundColor: Color {
            switch self {
            case .success: return Theme.colors.status.successLight
            case .error: return Theme.colors.status.errorLight
            case .warning: return Theme.colors.status.warningLight
            case .info: return Theme.colors.status.infoLight
            }
        }
    }
    
    func body(content: Content) -> some View {
        content
            .font(Theme.typography.caption1.font)
            .foregroundColor(status.color)
            .padding(.horizontal, Theme.spacing.xs)
            .padding(.vertical, Theme.spacing.xxs)
            .background(status.backgroundColor)
            .cornerRadius(Theme.cornerRadius.tag)
    }
}

extension View {
    /// Applies status badge styling
    func statusBadge(_ status: StatusBadgeModifier.StatusType) -> some View {
        modifier(StatusBadgeModifier(status: status))
    }
}

// MARK: - Loading State

/// Shows loading overlay with optional message
struct LoadingModifier: ViewModifier {
    let isLoading: Bool
    let message: String?
    
    func body(content: Content) -> some View {
        content
            .overlay {
                if isLoading {
                    ZStack {
                        Theme.colors.background.overlay
                            .ignoresSafeArea()
                        
                        VStack(spacing: Theme.spacing.md) {
                            ProgressView()
                                .scaleEffect(1.5)
                            
                            if let message = message {
                                Text(message)
                                    .textStyle(Theme.typography.body)
                                    .foregroundColor(Theme.colors.text.inverse)
                            }
                        }
                        .padding(.all, Theme.spacing.xl)
                        .background(Theme.colors.background.secondary)
                        .cornerRadius(Theme.cornerRadius.md)
                        .themeShadow(Theme.shadows.overlay)
                    }
                }
            }
    }
}

extension View {
    /// Applies loading overlay
    func loading(_ isLoading: Bool, message: String? = nil) -> some View {
        modifier(LoadingModifier(isLoading: isLoading, message: message))
    }
}

// MARK: - Preview

#Preview("Card Style") {
    VStack {
        Text("Card Content")
            .cardStyle(padding: Theme.spacing.md)
    }
    .padding()
}

#Preview("Status Badges") {
    HStack(spacing: 12) {
        Text("Success").statusBadge(.success)
        Text("Error").statusBadge(.error)
        Text("Warning").statusBadge(.warning)
        Text("Info").statusBadge(.info)
    }
    .padding()
}

#Preview("Primary Button") {
    VStack(spacing: 12) {
        Button("Save Changes") { }
            .buttonStyle(.themePrimary)
        
        Button("Disabled") { }
            .buttonStyle(.themePrimary)
            .disabled(true)
    }
    .padding()
}
