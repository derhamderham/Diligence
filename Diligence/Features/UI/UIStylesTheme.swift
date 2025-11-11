//
//  Theme.swift
//  Diligence
//
//  Comprehensive design system with all design tokens
//

import SwiftUI

// MARK: - Theme

/// The main theme struct containing all design tokens for the app
///
/// Theme provides centralized access to:
/// - Colors (semantic and raw)
/// - Typography (text styles)
/// - Spacing (layout constants)
/// - Corner radius values
/// - Shadow styles
/// - Animation timings
///
/// ## Usage
/// ```swift
/// Text("Hello")
///     .foregroundColor(Theme.colors.text.primary)
///     .font(Theme.typography.body.font)
///     .padding(Theme.spacing.md)
/// ```
///
/// ## Customization
/// The theme automatically adapts to:
/// - Light/Dark mode
/// - User preferences (accent color, font size)
/// - Platform (iOS/macOS)
enum Theme {
    /// Color palette
    static let colors = Colors()
    
    /// Typography styles
    static let typography = Typography()
    
    /// Spacing values
    static let spacing = Spacing()
    
    /// Corner radius values
    static let cornerRadius = CornerRadius()
    
    /// Shadow styles
    static let shadows = Shadows()
    
    /// Animation timings
    static let animations = Animations()
    
    /// Icon sizes
    static let icons = Icons()
}

// MARK: - Colors

/// Complete color palette with semantic naming
struct Colors {
    
    // MARK: - Text Colors
    
    struct TextColors {
        let primary = Color.primary
        let secondary = Color.secondary
        let tertiary = Color.gray
        let inverse = Color.white
        let disabled = Color.gray.opacity(0.4)
        let link = Color.blue
        let error = Color.red
        let success = Color.green
        let warning = Color.orange
    }
    
    let text = TextColors()
    
    // MARK: - Background Colors
    
    struct BackgroundColors {
        #if os(macOS)
        let primary = Color(NSColor.windowBackgroundColor)
        let secondary = Color(NSColor.controlBackgroundColor)
        let tertiary = Color(NSColor.quaternaryLabelColor)
        #else
        let primary = Color(UIColor.systemBackground)
        let secondary = Color(UIColor.secondarySystemBackground)
        let tertiary = Color(UIColor.tertiarySystemBackground)
        #endif
        let elevated = Color(white: 1.0).opacity(0.1)
        let overlay = Color.black.opacity(0.3)
        let overlayLight = Color.black.opacity(0.1)
        let overlayHeavy = Color.black.opacity(0.6)
    }
    
    let background = BackgroundColors()
    
    // MARK: - Brand Colors
    
    struct BrandColors {
        let primary = Color.accentColor
        let primaryHover = Color.accentColor.opacity(0.85)
        let primaryPressed = Color.accentColor.opacity(0.7)
        let primaryDisabled = Color.accentColor.opacity(0.3)
    }
    
    let brand = BrandColors()
    
    // MARK: - Status Colors
    
    struct StatusColors {
        let success = Color.green
        let successLight = Color.green.opacity(0.1)
        let error = Color.red
        let errorLight = Color.red.opacity(0.1)
        let warning = Color.orange
        let warningLight = Color.orange.opacity(0.1)
        let info = Color.blue
        let infoLight = Color.blue.opacity(0.1)
    }
    
    let status = StatusColors()
    
    // MARK: - Border Colors
    
    struct BorderColors {
        let `default` = Color.gray.opacity(0.3)
        let focused = Color.accentColor
        let error = Color.red
        let disabled = Color.gray.opacity(0.15)
    }
    
    let border = BorderColors()
    
    // MARK: - Priority Colors (for tasks)
    
    struct PriorityColors {
        let low = Color.gray
        let normal = Color.blue
        let high = Color.orange
        let urgent = Color.red
        
        func color(for priority: String) -> Color {
            switch priority.lowercased() {
            case "low": return low
            case "normal": return normal
            case "high": return high
            case "urgent": return urgent
            default: return normal
            }
        }
    }
    
    let priority = PriorityColors()
    
    // MARK: - AI Provider Colors
    
    struct AIProviderColors {
        let appleIntelligence = Color.blue
        let janAI = Color.purple
        let custom = Color.gray
    }
    
    let aiProvider = AIProviderColors()
    
    // MARK: - Email Category Colors
    
    struct EmailCategoryColors {
        let task = Color.orange
        let financial = Color.green
        let newsletter = Color.blue
        let personal = Color.purple
        let work = Color.blue
        let travel = Color.cyan
        let shopping = Color.pink
        let social = Color.indigo
        let spam = Color.red
        let other = Color.gray
    }
    
    let emailCategory = EmailCategoryColors()
    
    // MARK: - Chart Colors
    
    struct ChartColors {
        let primary = Color.blue
        let secondary = Color.purple
        let tertiary = Color.green
        let quaternary = Color.orange
        
        let gradient = [Color.blue, Color.purple]
        
        func color(at index: Int) -> Color {
            let colors = [primary, secondary, tertiary, quaternary]
            return colors[index % colors.count]
        }
    }
    
    let chart = ChartColors()
    
    // MARK: - Helper Functions
    
    /// Returns a color with adjusted opacity
    func withOpacity(_ opacity: Double, color: Color) -> Color {
        return color.opacity(opacity)
    }
    
    /// Returns a hover color (slightly transparent)
    func hover(_ color: Color) -> Color {
        return color.opacity(0.85)
    }
    
    /// Returns a pressed color (more transparent)
    func pressed(_ color: Color) -> Color {
        return color.opacity(0.7)
    }
    
    /// Returns a disabled color (very transparent)
    func disabled(_ color: Color) -> Color {
        return color.opacity(0.3)
    }
}

// MARK: - Typography

/// Typography scale with semantic text styles
struct Typography {
    
    // MARK: - Text Style
    
    struct TextStyle {
        let font: Font
        let lineHeight: CGFloat
        let letterSpacing: CGFloat
        
        init(size: CGFloat, weight: Font.Weight = .regular, lineHeight: CGFloat? = nil, letterSpacing: CGFloat = 0) {
            self.font = .system(size: size, weight: weight)
            self.lineHeight = lineHeight ?? size * 1.4
            self.letterSpacing = letterSpacing
        }
    }
    
    // MARK: - Headings
    
    let largeTitle = TextStyle(size: 34, weight: .bold, lineHeight: 41)
    let title1 = TextStyle(size: 28, weight: .bold, lineHeight: 34)
    let title2 = TextStyle(size: 22, weight: .bold, lineHeight: 28)
    let title3 = TextStyle(size: 20, weight: .semibold, lineHeight: 25)
    let headline = TextStyle(size: 17, weight: .semibold, lineHeight: 22)
    
    // MARK: - Body Text
    
    let body = TextStyle(size: 14, weight: .regular, lineHeight: 20)
    let bodyEmphasized = TextStyle(size: 14, weight: .medium, lineHeight: 20)
    let callout = TextStyle(size: 13, weight: .regular, lineHeight: 18)
    let subheadline = TextStyle(size: 12, weight: .medium, lineHeight: 16)
    
    // MARK: - Small Text
    
    let footnote = TextStyle(size: 11, weight: .regular, lineHeight: 15)
    let caption1 = TextStyle(size: 10, weight: .regular, lineHeight: 13)
    let caption2 = TextStyle(size: 9, weight: .regular, lineHeight: 12)
    
    // MARK: - Monospace
    
    let code = TextStyle(size: 12, weight: .regular, lineHeight: 16)
    let codeSmall = TextStyle(size: 10, weight: .regular, lineHeight: 14)
    
    // MARK: - Special
    
    let button = TextStyle(size: 14, weight: .medium, lineHeight: 18)
    let buttonSmall = TextStyle(size: 12, weight: .medium, lineHeight: 16)
    let buttonLarge = TextStyle(size: 16, weight: .medium, lineHeight: 20)
    
    let label = TextStyle(size: 13, weight: .medium, lineHeight: 17)
    let labelSmall = TextStyle(size: 11, weight: .medium, lineHeight: 15)
    
    // MARK: - Helper Functions
    
    /// Returns a monospaced font of the given size
    func monospaced(size: CGFloat) -> Font {
        return .system(size: size, design: .monospaced)
    }
    
    /// Returns a rounded font of the given size
    func rounded(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return .system(size: size, weight: weight, design: .rounded)
    }
}

// MARK: - Spacing

/// Spacing scale for consistent layouts
struct Spacing {
    // Basic spacing scale
    let xxxs: CGFloat = 2
    let xxs: CGFloat = 4
    let xs: CGFloat = 6
    let sm: CGFloat = 8
    let md: CGFloat = 12
    let lg: CGFloat = 16
    let xl: CGFloat = 20
    let xxl: CGFloat = 24
    let xxxl: CGFloat = 32
    let xxxxl: CGFloat = 40
    
    // Semantic spacing
    struct Semantic {
        let elementSpacing: CGFloat = 8      // Between elements in a group
        let sectionSpacing: CGFloat = 16     // Between sections
        let screenPadding: CGFloat = 20      // Screen edge padding
        let cardPadding: CGFloat = 16        // Inside cards
        let buttonPadding: CGFloat = 12      // Inside buttons
    }
    
    let semantic = Semantic()
    
    // Layout spacing
    struct Layout {
        let sidebarWidth: CGFloat = 250
        let sidebarMinWidth: CGFloat = 200
        let sidebarMaxWidth: CGFloat = 350
        let detailMinWidth: CGFloat = 400
        let toolbarHeight: CGFloat = 44
    }
    
    let layout = Layout()
}

// MARK: - Corner Radius

/// Corner radius values for consistent UI elements
struct CornerRadius {
    let none: CGFloat = 0
    let xs: CGFloat = 4
    let sm: CGFloat = 6
    let md: CGFloat = 8
    let lg: CGFloat = 12
    let xl: CGFloat = 16
    let xxl: CGFloat = 20
    let full: CGFloat = 9999
    
    // Semantic radius
    let button: CGFloat = 8
    let field: CGFloat = 6
    let card: CGFloat = 12
    let modal: CGFloat = 16
    let tag: CGFloat = 4
}

// MARK: - Shadows

/// Shadow styles for elevation
struct Shadows {
    struct ShadowStyle {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
    
    // Shadow levels
    let none = ShadowStyle(color: .clear, radius: 0, x: 0, y: 0)
    
    let sm = ShadowStyle(
        color: Color.black.opacity(0.1),
        radius: 2,
        x: 0,
        y: 1
    )
    
    let md = ShadowStyle(
        color: Color.black.opacity(0.15),
        radius: 4,
        x: 0,
        y: 2
    )
    
    let lg = ShadowStyle(
        color: Color.black.opacity(0.2),
        radius: 8,
        x: 0,
        y: 4
    )
    
    let xl = ShadowStyle(
        color: Color.black.opacity(0.25),
        radius: 16,
        x: 0,
        y: 8
    )
    
    // Semantic shadows
    let button = ShadowStyle(
        color: Color.accentColor.opacity(0.2),
        radius: 4,
        x: 0,
        y: 2
    )
    
    let card = ShadowStyle(
        color: Color.black.opacity(0.1),
        radius: 8,
        x: 0,
        y: 2
    )
    
    let overlay = ShadowStyle(
        color: Color.black.opacity(0.3),
        radius: 20,
        x: 0,
        y: 10
    )
}

// MARK: - Animations

/// Animation timing and curves
struct Animations {
    // Duration
    let instant: Double = 0.1
    let fast: Double = 0.15
    let normal: Double = 0.25
    let slow: Double = 0.35
    let slower: Double = 0.5
    
    // Spring animations
    let spring = Animation.spring(response: 0.3, dampingFraction: 0.7)
    let springBouncy = Animation.spring(response: 0.4, dampingFraction: 0.6)
    let springSmooth = Animation.spring(response: 0.5, dampingFraction: 0.8)
    
    // Easing curves
    let easeIn = Animation.easeIn(duration: 0.25)
    let easeOut = Animation.easeOut(duration: 0.25)
    let easeInOut = Animation.easeInOut(duration: 0.25)
    let linear = Animation.linear(duration: 0.25)
    
    // Common animations
    let buttonTap = Animation.easeInOut(duration: 0.15)
    let cardAppear = Animation.spring(response: 0.4, dampingFraction: 0.75)
    let overlayAppear = Animation.easeOut(duration: 0.2)
}

// MARK: - Icons

/// Icon sizing for consistent iconography
struct Icons {
    let xs: CGFloat = 12
    let sm: CGFloat = 14
    let md: CGFloat = 16
    let lg: CGFloat = 20
    let xl: CGFloat = 24
    let xxl: CGFloat = 32
    
    // Semantic sizes
    let button: CGFloat = 14
    let field: CGFloat = 14
    let toolbar: CGFloat = 16
    let navigation: CGFloat = 20
}

// MARK: - View Extensions

extension View {
    /// Applies a theme text style
    func textStyle(_ style: Typography.TextStyle) -> some View {
        self.font(style.font)
    }
    
    /// Applies a theme shadow
    func themeShadow(_ shadow: Shadows.ShadowStyle) -> some View {
        self.shadow(
            color: shadow.color,
            radius: shadow.radius,
            x: shadow.x,
            y: shadow.y
        )
    }
}

// MARK: - Preview

#Preview("Theme Colors") {
    ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            // Text colors
            Group {
                Text("Text Colors").font(.headline)
                HStack(spacing: 8) {
                    ColorSwatch(color: Theme.colors.text.primary, name: "Primary")
                    ColorSwatch(color: Theme.colors.text.secondary, name: "Secondary")
                    ColorSwatch(color: Theme.colors.text.tertiary, name: "Tertiary")
                }
            }
            
            // Status colors
            Group {
                Text("Status Colors").font(.headline)
                HStack(spacing: 8) {
                    ColorSwatch(color: Theme.colors.status.success, name: "Success")
                    ColorSwatch(color: Theme.colors.status.error, name: "Error")
                    ColorSwatch(color: Theme.colors.status.warning, name: "Warning")
                    ColorSwatch(color: Theme.colors.status.info, name: "Info")
                }
            }
            
            // Priority colors
            Group {
                Text("Priority Colors").font(.headline)
                HStack(spacing: 8) {
                    ColorSwatch(color: Theme.colors.priority.low, name: "Low")
                    ColorSwatch(color: Theme.colors.priority.normal, name: "Normal")
                    ColorSwatch(color: Theme.colors.priority.high, name: "High")
                    ColorSwatch(color: Theme.colors.priority.urgent, name: "Urgent")
                }
            }
        }
        .padding()
    }
    .frame(width: 500, height: 400)
}

#Preview("Typography") {
    ScrollView {
        VStack(alignment: .leading, spacing: 12) {
            Text("Large Title").textStyle(Theme.typography.largeTitle)
            Text("Title 1").textStyle(Theme.typography.title1)
            Text("Title 2").textStyle(Theme.typography.title2)
            Text("Title 3").textStyle(Theme.typography.title3)
            Text("Headline").textStyle(Theme.typography.headline)
            Text("Body").textStyle(Theme.typography.body)
            Text("Body Emphasized").textStyle(Theme.typography.bodyEmphasized)
            Text("Callout").textStyle(Theme.typography.callout)
            Text("Subheadline").textStyle(Theme.typography.subheadline)
            Text("Footnote").textStyle(Theme.typography.footnote)
            Text("Caption 1").textStyle(Theme.typography.caption1)
            Text("Caption 2").textStyle(Theme.typography.caption2)
        }
        .padding()
    }
    .frame(width: 400, height: 500)
}

// Helper view for color swatches
struct ColorSwatch: View {
    let color: Color
    let name: String
    
    var body: some View {
        VStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(color)
                .frame(width: 60, height: 60)
            
            Text(name)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }
}
