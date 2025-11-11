//
//  Typography.swift
//  Diligence
//
//  Typography scale with semantic text styles
//

import SwiftUI

// MARK: - Theme Typography

/// Typography scale with semantic text styles
///
/// Typography provides a comprehensive type system with:
/// - Consistent font sizing and weights
/// - Line height and letter spacing
/// - Platform-adaptive fonts
/// - Semantic naming for different contexts
///
/// ## Usage
/// ```swift
/// Text("Hello World")
///     .font(ThemeTypography.headline.font)
///
/// Text("Body text")
///     .textStyle(ThemeTypography.body)
/// ```
struct ThemeTypography {
    
    // MARK: - Text Style
    
    /// A complete text style with font, line height, and letter spacing
    struct TextStyle {
        /// The font to use
        let font: Font
        
        /// Line height (leading)
        let lineHeight: CGFloat
        
        /// Letter spacing (tracking)
        let letterSpacing: CGFloat
        
        /// Font size for calculations
        let size: CGFloat
        
        /// Font weight for calculations
        let weight: Font.Weight
        
        init(
            size: CGFloat,
            weight: Font.Weight = .regular,
            lineHeight: CGFloat? = nil,
            letterSpacing: CGFloat = 0
        ) {
            self.size = size
            self.weight = weight
            self.font = .system(size: size, weight: weight)
            self.lineHeight = lineHeight ?? size * 1.4
            self.letterSpacing = letterSpacing
        }
        
        /// Creates a custom font with different size
        func withSize(_ newSize: CGFloat) -> TextStyle {
            return TextStyle(
                size: newSize,
                weight: weight,
                lineHeight: newSize * (lineHeight / size),
                letterSpacing: letterSpacing
            )
        }
        
        /// Creates a custom font with different weight
        func withWeight(_ newWeight: Font.Weight) -> TextStyle {
            return TextStyle(
                size: size,
                weight: newWeight,
                lineHeight: lineHeight,
                letterSpacing: letterSpacing
            )
        }
    }
    
    // MARK: - Display Styles (Large Headings)
    
    /// Extra large display text (48pt)
    static let displayLarge = TextStyle(
        size: 48,
        weight: .bold,
        lineHeight: 56,
        letterSpacing: -0.5
    )
    
    /// Medium display text (40pt)
    static let displayMedium = TextStyle(
        size: 40,
        weight: .bold,
        lineHeight: 48,
        letterSpacing: -0.5
    )
    
    /// Small display text (36pt)
    static let displaySmall = TextStyle(
        size: 36,
        weight: .bold,
        lineHeight: 44,
        letterSpacing: -0.5
    )
    
    // MARK: - Heading Styles
    
    /// Large title (34pt) - Main screen titles
    static let largeTitle = TextStyle(
        size: 34,
        weight: .bold,
        lineHeight: 41
    )
    
    /// Title 1 (28pt) - Section headers
    static let title1 = TextStyle(
        size: 28,
        weight: .bold,
        lineHeight: 34
    )
    
    /// Title 2 (22pt) - Sub-section headers
    static let title2 = TextStyle(
        size: 22,
        weight: .bold,
        lineHeight: 28
    )
    
    /// Title 3 (20pt) - Card titles
    static let title3 = TextStyle(
        size: 20,
        weight: .semibold,
        lineHeight: 25
    )
    
    /// Headline (17pt) - List item titles
    static let headline = TextStyle(
        size: 17,
        weight: .semibold,
        lineHeight: 22
    )
    
    /// Subheadline (15pt) - Secondary titles
    static let subheadline = TextStyle(
        size: 15,
        weight: .medium,
        lineHeight: 20
    )
    
    // MARK: - Body Text
    
    /// Large body text (16pt)
    static let bodyLarge = TextStyle(
        size: 16,
        weight: .regular,
        lineHeight: 24
    )
    
    /// Regular body text (14pt)
    static let body = TextStyle(
        size: 14,
        weight: .regular,
        lineHeight: 20
    )
    
    /// Small body text (13pt)
    static let bodySmall = TextStyle(
        size: 13,
        weight: .regular,
        lineHeight: 18
    )
    
    /// Emphasized body text (14pt, medium weight)
    static let bodyEmphasized = TextStyle(
        size: 14,
        weight: .medium,
        lineHeight: 20
    )
    
    // MARK: - Supporting Text
    
    /// Callout text (13pt)
    static let callout = TextStyle(
        size: 13,
        weight: .regular,
        lineHeight: 18
    )
    
    /// Footnote text (11pt)
    static let footnote = TextStyle(
        size: 11,
        weight: .regular,
        lineHeight: 15
    )
    
    /// Caption 1 (10pt)
    static let caption1 = TextStyle(
        size: 10,
        weight: .regular,
        lineHeight: 13
    )
    
    /// Caption 2 (9pt)
    static let caption2 = TextStyle(
        size: 9,
        weight: .regular,
        lineHeight: 12
    )
    
    // MARK: - Monospace / Code
    
    /// Code text (13pt, monospaced)
    static let code = TextStyle(
        size: 13,
        weight: .regular,
        lineHeight: 18
    )
    
    /// Small code text (11pt, monospaced)
    static let codeSmall = TextStyle(
        size: 11,
        weight: .regular,
        lineHeight: 15
    )
    
    // MARK: - Button Text
    
    /// Large button text (16pt)
    static let buttonLarge = TextStyle(
        size: 16,
        weight: .medium,
        lineHeight: 20
    )
    
    /// Regular button text (14pt)
    static let button = TextStyle(
        size: 14,
        weight: .medium,
        lineHeight: 18
    )
    
    /// Small button text (12pt)
    static let buttonSmall = TextStyle(
        size: 12,
        weight: .medium,
        lineHeight: 16
    )
    
    // MARK: - Label Text
    
    /// Regular label (13pt)
    static let label = TextStyle(
        size: 13,
        weight: .medium,
        lineHeight: 17
    )
    
    /// Small label (11pt)
    static let labelSmall = TextStyle(
        size: 11,
        weight: .medium,
        lineHeight: 15
    )
    
    /// Uppercase label (11pt, uppercase)
    static let labelUppercase = TextStyle(
        size: 11,
        weight: .semibold,
        lineHeight: 15,
        letterSpacing: 0.5
    )
    
    // MARK: - Input Text
    
    /// Text field input (14pt)
    static let input = TextStyle(
        size: 14,
        weight: .regular,
        lineHeight: 20
    )
    
    /// Small text field input (13pt)
    static let inputSmall = TextStyle(
        size: 13,
        weight: .regular,
        lineHeight: 18
    )
    
    /// Large text field input (16pt)
    static let inputLarge = TextStyle(
        size: 16,
        weight: .regular,
        lineHeight: 24
    )
    
    // MARK: - Helper Functions
    
    /// Returns a monospaced font of the given size
    static func monospaced(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return .system(size: size, weight: weight, design: .monospaced)
    }
    
    /// Returns a rounded font of the given size
    static func rounded(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return .system(size: size, weight: weight, design: .rounded)
    }
    
    /// Returns a serif font of the given size
    static func serif(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return .system(size: size, weight: weight, design: .serif)
    }
    
    /// Returns a custom font with specific size and weight
    static func custom(size: CGFloat, weight: Font.Weight = .regular) -> TextStyle {
        return TextStyle(size: size, weight: weight)
    }
}

// MARK: - View Extensions

extension View {
    /// Applies a complete text style including font, line spacing, and tracking
    func textStyle(_ style: ThemeTypography.TextStyle) -> some View {
        self
            .font(style.font)
            .lineSpacing(style.lineHeight - style.size)
            .tracking(style.letterSpacing)
    }
    
    /// Applies a monospaced font
    func monospacedFont(size: CGFloat, weight: Font.Weight = .regular) -> some View {
        self.font(ThemeTypography.monospaced(size: size, weight: weight))
    }
}

// MARK: - Text Extensions

extension Text {
    /// Creates text with a specific style
    func style(_ style: ThemeTypography.TextStyle) -> Text {
        self
            .font(style.font)
            .tracking(style.letterSpacing)
    }
}

// MARK: - Preview

#Preview("Typography Scale") {
    ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            Group {
                Text("Display Styles")
                    .font(.headline)
                    .padding(.top)
                
                Text("Display Large")
                    .textStyle(ThemeTypography.displayLarge)
                
                Text("Display Medium")
                    .textStyle(ThemeTypography.displayMedium)
                
                Text("Display Small")
                    .textStyle(ThemeTypography.displaySmall)
            }
            
            Divider().padding(.vertical)
            
            Group {
                Text("Heading Styles")
                    .font(.headline)
                
                Text("Large Title")
                    .textStyle(ThemeTypography.largeTitle)
                
                Text("Title 1")
                    .textStyle(ThemeTypography.title1)
                
                Text("Title 2")
                    .textStyle(ThemeTypography.title2)
                
                Text("Title 3")
                    .textStyle(ThemeTypography.title3)
                
                Text("Headline")
                    .textStyle(ThemeTypography.headline)
                
                Text("Subheadline")
                    .textStyle(ThemeTypography.subheadline)
            }
            
            Divider().padding(.vertical)
            
            Group {
                Text("Body Styles")
                    .font(.headline)
                
                Text("Body Large - The quick brown fox jumps over the lazy dog")
                    .textStyle(ThemeTypography.bodyLarge)
                
                Text("Body - The quick brown fox jumps over the lazy dog")
                    .textStyle(ThemeTypography.body)
                
                Text("Body Small - The quick brown fox jumps over the lazy dog")
                    .textStyle(ThemeTypography.bodySmall)
                
                Text("Body Emphasized - The quick brown fox jumps over the lazy dog")
                    .textStyle(ThemeTypography.bodyEmphasized)
            }
            
            Divider().padding(.vertical)
            
            Group {
                Text("Supporting Styles")
                    .font(.headline)
                
                Text("Callout")
                    .textStyle(ThemeTypography.callout)
                
                Text("Footnote")
                    .textStyle(ThemeTypography.footnote)
                
                Text("Caption 1")
                    .textStyle(ThemeTypography.caption1)
                
                Text("Caption 2")
                    .textStyle(ThemeTypography.caption2)
            }
            
            Divider().padding(.vertical)
            
            Group {
                Text("Button Styles")
                    .font(.headline)
                
                Text("Button Large")
                    .textStyle(ThemeTypography.buttonLarge)
                
                Text("Button Regular")
                    .textStyle(ThemeTypography.button)
                
                Text("Button Small")
                    .textStyle(ThemeTypography.buttonSmall)
            }
            
            Divider().padding(.vertical)
            
            Group {
                Text("Monospace / Code")
                    .font(.headline)
                
                Text("let code = \"monospaced\"")
                    .font(ThemeTypography.monospaced(size: 13))
                
                Text("func example() { }")
                    .font(ThemeTypography.monospaced(size: 11))
            }
        }
        .padding()
    }
    .frame(width: 600, height: 800)
}

#Preview("Typography in Context") {
    VStack(alignment: .leading, spacing: 20) {
        VStack(alignment: .leading, spacing: 8) {
            Text("Section Title")
                .textStyle(ThemeTypography.title2)
                .foregroundColor(ThemeColors.text.primary)
            
            Text("This is body text that provides context and explanation. It should be easy to read and have appropriate line spacing.")
                .textStyle(ThemeTypography.body)
                .foregroundColor(ThemeColors.text.secondary)
            
            Text("Additional details in footnote text")
                .textStyle(ThemeTypography.footnote)
                .foregroundColor(ThemeColors.text.tertiary)
        }
        
        Divider()
        
        VStack(alignment: .leading, spacing: 4) {
            Text("LABEL")
                .textStyle(ThemeTypography.labelUppercase)
                .foregroundColor(ThemeColors.text.secondary)
            
            Text("Value Text")
                .textStyle(ThemeTypography.bodyEmphasized)
                .foregroundColor(ThemeColors.text.primary)
        }
    }
    .padding()
    .frame(width: 400)
}
