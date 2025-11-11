//
//  Colors.swift
//  Diligence
//
//  Complete color palette with semantic naming
//

import SwiftUI

// MARK: - Theme Colors

/// Complete color palette with semantic naming
///
/// Colors provides a centralized color system with:
/// - Platform-adaptive colors (light/dark mode)
/// - Semantic naming for intent-based usage
/// - Status colors for feedback
/// - Domain-specific colors (priorities, categories)
///
/// ## Usage
/// ```swift
/// Text("Hello")
///     .foregroundColor(ThemeColors.text.primary)
///     .background(ThemeColors.background.secondary)
/// ```
struct ThemeColors {
    
    // MARK: - Text Colors
    
    /// Text colors for different emphasis levels
    struct TextColors {
        /// Primary text color for main content
        let primary = Color.primary
        
        /// Secondary text color for supporting content
        let secondary = Color.secondary
        
        /// Tertiary text color for de-emphasized content
        let tertiary = Color.gray
        
        /// Inverse text color (typically white on dark backgrounds)
        let inverse = Color.white
        
        /// Disabled text color
        let disabled = Color.gray.opacity(0.4)
        
        /// Link text color
        let link = Color.blue
        
        /// Error text color
        let error = Color.red
        
        /// Success text color
        let success = Color.green
        
        /// Warning text color
        let warning = Color.orange
    }
    
    static let text = TextColors()
    
    // MARK: - Background Colors
    
    /// Background colors for different layers and contexts
    struct BackgroundColors {
        #if os(macOS)
        /// Primary background (window background)
        let primary = Color(NSColor.windowBackgroundColor)
        
        /// Secondary background (content area)
        let secondary = Color(NSColor.controlBackgroundColor)
        
        /// Tertiary background (grouped content)
        let tertiary = Color(NSColor.quaternaryLabelColor)
        
        /// Under page background
        let underPage = Color(NSColor.underPageBackgroundColor)
        #else
        /// Primary background (window background)
        let primary = Color(UIColor.systemBackground)
        
        /// Secondary background (content area)
        let secondary = Color(UIColor.secondarySystemBackground)
        
        /// Tertiary background (grouped content)
        let tertiary = Color(UIColor.tertiarySystemBackground)
        
        /// Under page background
        let underPage = Color(UIColor.systemGroupedBackground)
        #endif
        
        /// Elevated background (cards, modals)
        let elevated = Color.white.opacity(0.05)
        
        /// Overlay backgrounds
        let overlay = Color.black.opacity(0.3)
        let overlayLight = Color.black.opacity(0.1)
        let overlayMedium = Color.black.opacity(0.5)
        let overlayHeavy = Color.black.opacity(0.7)
        
        /// Hover background for interactive elements
        let hover = Color.primary.opacity(0.05)
        
        /// Selected background
        let selected = Color.accentColor.opacity(0.15)
    }
    
    static let background = BackgroundColors()
    
    // MARK: - Brand Colors
    
    /// Brand colors for primary actions and identity
    struct BrandColors {
        /// Primary brand color
        let primary = Color.accentColor
        
        /// Primary hover state
        let primaryHover = Color.accentColor.opacity(0.85)
        
        /// Primary pressed state
        let primaryPressed = Color.accentColor.opacity(0.7)
        
        /// Primary disabled state
        let primaryDisabled = Color.accentColor.opacity(0.3)
        
        /// Primary subtle background
        let primarySubtle = Color.accentColor.opacity(0.1)
        
        /// Secondary brand color
        let secondary = Color.purple
        let secondaryHover = Color.purple.opacity(0.85)
        let secondaryPressed = Color.purple.opacity(0.7)
    }
    
    static let brand = BrandColors()
    
    // MARK: - Status Colors
    
    /// Status colors for user feedback
    struct StatusColors {
        // Success
        let success = Color.green
        let successLight = Color.green.opacity(0.1)
        let successMedium = Color.green.opacity(0.3)
        let successDark = Color.green.opacity(0.8)
        
        // Error
        let error = Color.red
        let errorLight = Color.red.opacity(0.1)
        let errorMedium = Color.red.opacity(0.3)
        let errorDark = Color.red.opacity(0.8)
        
        // Warning
        let warning = Color.orange
        let warningLight = Color.orange.opacity(0.1)
        let warningMedium = Color.orange.opacity(0.3)
        let warningDark = Color.orange.opacity(0.8)
        
        // Info
        let info = Color.blue
        let infoLight = Color.blue.opacity(0.1)
        let infoMedium = Color.blue.opacity(0.3)
        let infoDark = Color.blue.opacity(0.8)
        
        // Neutral
        let neutral = Color.gray
        let neutralLight = Color.gray.opacity(0.1)
        let neutralMedium = Color.gray.opacity(0.3)
        let neutralDark = Color.gray.opacity(0.8)
    }
    
    static let status = StatusColors()
    
    // MARK: - Border Colors
    
    /// Border colors for different states
    struct BorderColors {
        /// Default border color
        let `default` = Color.gray.opacity(0.3)
        
        /// Focused border color
        let focused = Color.accentColor
        
        /// Error border color
        let error = Color.red
        
        /// Success border color
        let success = Color.green
        
        /// Disabled border color
        let disabled = Color.gray.opacity(0.15)
        
        /// Hover border color
        let hover = Color.gray.opacity(0.5)
        
        /// Subtle border for minimal separation
        let subtle = Color.gray.opacity(0.1)
    }
    
    static let border = BorderColors()
    
    // MARK: - Priority Colors (for tasks)
    
    /// Priority colors for task management
    struct PriorityColors {
        let low = Color.gray
        let normal = Color.blue
        let high = Color.orange
        let urgent = Color.red
        let critical = Color.red
        
        /// Returns color for a priority string
        func color(for priority: String) -> Color {
            switch priority.lowercased() {
            case "low": return low
            case "normal", "medium": return normal
            case "high": return high
            case "urgent": return urgent
            case "critical": return critical
            default: return normal
            }
        }
        
        /// Returns background color for a priority
        func background(for priority: String) -> Color {
            color(for: priority).opacity(0.1)
        }
    }
    
    static let priority = PriorityColors()
    
    // MARK: - AI Provider Colors
    
    /// Colors for different AI providers
    struct AIProviderColors {
        let appleIntelligence = Color.blue
        let janAI = Color.purple
        let openAI = Color.green
        let anthropic = Color.orange
        let custom = Color.gray
        
        /// Returns color for a provider string
        func color(for provider: String) -> Color {
            switch provider.lowercased() {
            case "apple", "apple intelligence": return appleIntelligence
            case "jan", "jan ai", "janai": return janAI
            case "openai", "chatgpt": return openAI
            case "anthropic", "claude": return anthropic
            default: return custom
            }
        }
    }
    
    static let aiProvider = AIProviderColors()
    
    // MARK: - Email Category Colors
    
    /// Colors for email categories
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
        let promotion = Color.yellow
        let updates = Color.teal
        let other = Color.gray
        
        /// Returns color for a category string
        func color(for category: String) -> Color {
            switch category.lowercased() {
            case "task", "tasks": return task
            case "financial", "finance": return financial
            case "newsletter", "newsletters": return newsletter
            case "personal": return personal
            case "work": return work
            case "travel": return travel
            case "shopping": return shopping
            case "social": return social
            case "spam": return spam
            case "promotion", "promotions": return promotion
            case "updates": return updates
            default: return other
            }
        }
        
        /// Returns background color for a category
        func background(for category: String) -> Color {
            color(for: category).opacity(0.1)
        }
    }
    
    static let emailCategory = EmailCategoryColors()
    
    // MARK: - Chart Colors
    
    /// Colors for data visualizations
    struct ChartColors {
        let primary = Color.blue
        let secondary = Color.purple
        let tertiary = Color.green
        let quaternary = Color.orange
        let quinary = Color.pink
        let senary = Color.cyan
        
        /// Color palette for multiple series
        let palette = [
            Color.blue,
            Color.purple,
            Color.green,
            Color.orange,
            Color.pink,
            Color.cyan,
            Color.indigo,
            Color.teal
        ]
        
        /// Gradient colors
        let gradientPrimary = [Color.blue, Color.purple]
        let gradientSecondary = [Color.green, Color.cyan]
        let gradientTertiary = [Color.orange, Color.pink]
        
        /// Returns color at index (cycles through palette)
        func color(at index: Int) -> Color {
            palette[index % palette.count]
        }
    }
    
    static let chart = ChartColors()
    
    // MARK: - Semantic Colors
    
    /// Semantic colors for specific UI elements
    struct SemanticColors {
        // Interactive elements
        let interactive = Color.blue
        let interactiveHover = Color.blue.opacity(0.85)
        let interactivePressed = Color.blue.opacity(0.7)
        let interactiveDisabled = Color.gray.opacity(0.3)
        
        // Destructive actions
        let destructive = Color.red
        let destructiveHover = Color.red.opacity(0.85)
        let destructivePressed = Color.red.opacity(0.7)
        
        // Dividers and separators
        let divider = Color.gray.opacity(0.2)
        let separator = Color.gray.opacity(0.15)
        
        // Focus indicators
        let focus = Color.accentColor
        let focusRing = Color.accentColor.opacity(0.3)
    }
    
    static let semantic = SemanticColors()
    
    // MARK: - Helper Functions
    
    /// Returns a color with adjusted opacity
    static func withOpacity(_ opacity: Double, color: Color) -> Color {
        return color.opacity(opacity)
    }
    
    /// Returns a hover color (slightly transparent)
    static func hover(_ color: Color) -> Color {
        return color.opacity(0.85)
    }
    
    /// Returns a pressed color (more transparent)
    static func pressed(_ color: Color) -> Color {
        return color.opacity(0.7)
    }
    
    /// Returns a disabled color (very transparent)
    static func disabled(_ color: Color) -> Color {
        return color.opacity(0.3)
    }
    
    /// Returns a subtle background color
    static func subtle(_ color: Color) -> Color {
        return color.opacity(0.1)
    }
}

// MARK: - Preview

#Preview("Color Palette") {
    ColorPalettePreview()
}

private struct ColorPalettePreview: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Text colors
                ColorSection(title: "Text Colors") {
                    HStack(spacing: 12) {
                        ColorSwatch(color: ThemeColors.text.primary, name: "Primary")
                        ColorSwatch(color: ThemeColors.text.secondary, name: "Secondary")
                        ColorSwatch(color: ThemeColors.text.tertiary, name: "Tertiary")
                        ColorSwatch(color: ThemeColors.text.link, name: "Link")
                    }
                }
                
                // Status colors
                ColorSection(title: "Status Colors") {
                    VStack(spacing: 8) {
                        HStack(spacing: 12) {
                            ColorSwatch(color: ThemeColors.status.success, name: "Success")
                            ColorSwatch(color: ThemeColors.status.successLight, name: "Success Light")
                        }
                        HStack(spacing: 12) {
                            ColorSwatch(color: ThemeColors.status.error, name: "Error")
                            ColorSwatch(color: ThemeColors.status.errorLight, name: "Error Light")
                        }
                        HStack(spacing: 12) {
                            ColorSwatch(color: ThemeColors.status.warning, name: "Warning")
                            ColorSwatch(color: ThemeColors.status.warningLight, name: "Warning Light")
                        }
                        HStack(spacing: 12) {
                            ColorSwatch(color: ThemeColors.status.info, name: "Info")
                            ColorSwatch(color: ThemeColors.status.infoLight, name: "Info Light")
                        }
                    }
                }
                
                // Priority colors
                ColorSection(title: "Priority Colors") {
                    HStack(spacing: 12) {
                        ColorSwatch(color: ThemeColors.priority.low, name: "Low")
                        ColorSwatch(color: ThemeColors.priority.normal, name: "Normal")
                        ColorSwatch(color: ThemeColors.priority.high, name: "High")
                        ColorSwatch(color: ThemeColors.priority.urgent, name: "Urgent")
                    }
                }
                
                // Chart colors
                ColorSection(title: "Chart Colors") {
                    HStack(spacing: 12) {
                        ForEach(0..<6) { index in
                            ColorSwatch(
                                color: ThemeColors.chart.color(at: index),
                                name: "Color \(index + 1)"
                            )
                        }
                    }
                }
            }
            .padding()
        }
        .frame(width: 700)
    }
}

// Helper views
private struct ColorSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content
        }
    }
}


