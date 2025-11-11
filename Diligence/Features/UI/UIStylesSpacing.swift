//
//  Spacing.swift
//  Diligence
//
//  Spacing scale for consistent layouts
//

import SwiftUI

// MARK: - Theme Spacing

/// Spacing scale for consistent layouts
///
/// Spacing provides a comprehensive spacing system with:
/// - Base spacing scale (2-64pt)
/// - Semantic spacing for UI elements
/// - Layout dimensions for structural elements
/// - Insets for common padding patterns
///
/// ## Usage
/// ```swift
/// VStack(spacing: ThemeSpacing.md) {
///     // content
/// }
/// .padding(ThemeSpacing.screenPadding)
/// ```
struct ThemeSpacing {
    
    // MARK: - Base Spacing Scale
    
    /// 2pt - Minimal spacing
    static let xxxs: CGFloat = 2
    
    /// 4pt - Extra extra small spacing
    static let xxs: CGFloat = 4
    
    /// 6pt - Extra small spacing
    static let xs: CGFloat = 6
    
    /// 8pt - Small spacing
    static let sm: CGFloat = 8
    
    /// 12pt - Medium spacing (most common)
    static let md: CGFloat = 12
    
    /// 16pt - Large spacing
    static let lg: CGFloat = 16
    
    /// 20pt - Extra large spacing
    static let xl: CGFloat = 20
    
    /// 24pt - Extra extra large spacing
    static let xxl: CGFloat = 24
    
    /// 32pt - Huge spacing
    static let xxxl: CGFloat = 32
    
    /// 40pt - Extra huge spacing
    static let xxxxl: CGFloat = 40
    
    /// 48pt - Massive spacing
    static let xxxxxl: CGFloat = 48
    
    /// 64pt - Extra massive spacing
    static let xxxxxxl: CGFloat = 64
    
    // MARK: - Semantic Spacing
    
    /// Spacing between related elements in a group
    static let elementSpacing: CGFloat = 8
    
    /// Spacing between sections
    static let sectionSpacing: CGFloat = 16
    
    /// Spacing between major sections
    static let majorSectionSpacing: CGFloat = 24
    
    /// Screen edge padding
    static let screenPadding: CGFloat = 20
    
    /// Screen edge padding (small screens)
    static let screenPaddingSmall: CGFloat = 16
    
    /// Screen edge padding (large screens)
    static let screenPaddingLarge: CGFloat = 24
    
    /// Inside card padding
    static let cardPadding: CGFloat = 16
    
    /// Inside card padding (small)
    static let cardPaddingSmall: CGFloat = 12
    
    /// Inside card padding (large)
    static let cardPaddingLarge: CGFloat = 20
    
    /// Inside button padding (horizontal)
    static let buttonPaddingHorizontal: CGFloat = 16
    
    /// Inside button padding (vertical)
    static let buttonPaddingVertical: CGFloat = 8
    
    /// Inside small button padding (horizontal)
    static let buttonPaddingHorizontalSmall: CGFloat = 12
    
    /// Inside small button padding (vertical)
    static let buttonPaddingVerticalSmall: CGFloat = 6
    
    /// Inside large button padding (horizontal)
    static let buttonPaddingHorizontalLarge: CGFloat = 20
    
    /// Inside large button padding (vertical)
    static let buttonPaddingVerticalLarge: CGFloat = 10
    
    /// Text field padding (horizontal)
    static let fieldPaddingHorizontal: CGFloat = 12
    
    /// Text field padding (vertical)
    static let fieldPaddingVertical: CGFloat = 8
    
    /// List item padding (horizontal)
    static let listItemPaddingHorizontal: CGFloat = 16
    
    /// List item padding (vertical)
    static let listItemPaddingVertical: CGFloat = 8
    
    /// Modal/Sheet padding
    static let modalPadding: CGFloat = 24
    
    /// Toolbar padding
    static let toolbarPadding: CGFloat = 12
    
    /// Tab bar padding
    static let tabBarPadding: CGFloat = 8
    
    // MARK: - Layout Dimensions
    
    /// Sidebar width (default)
    static let sidebarWidth: CGFloat = 250
    
    /// Sidebar minimum width
    static let sidebarMinWidth: CGFloat = 200
    
    /// Sidebar maximum width
    static let sidebarMaxWidth: CGFloat = 350
    
    /// Detail pane minimum width
    static let detailMinWidth: CGFloat = 400
    
    /// Detail pane preferred width
    static let detailPreferredWidth: CGFloat = 600
    
    /// Toolbar height
    static let toolbarHeight: CGFloat = 44
    
    /// Tab bar height
    static let tabBarHeight: CGFloat = 48
    
    /// Navigation bar height
    static let navigationBarHeight: CGFloat = 44
    
    /// Status bar height
    static let statusBarHeight: CGFloat = 22
    
    /// Bottom safe area height (approx for iPhone)
    static let bottomSafeArea: CGFloat = 34
    
    /// Form width (max for readability)
    static let formMaxWidth: CGFloat = 600
    
    /// Content max width (for text readability)
    static let contentMaxWidth: CGFloat = 800
    
    /// Card max width
    static let cardMaxWidth: CGFloat = 400
    
    // MARK: - Icon Spacing
    
    /// Spacing between icon and text (small)
    static let iconTextSpacingSmall: CGFloat = 4
    
    /// Spacing between icon and text (regular)
    static let iconTextSpacing: CGFloat = 6
    
    /// Spacing between icon and text (large)
    static let iconTextSpacingLarge: CGFloat = 8
    
    // MARK: - List Spacing
    
    /// Spacing between list items
    static let listItemSpacing: CGFloat = 2
    
    /// Spacing between list sections
    static let listSectionSpacing: CGFloat = 16
    
    /// List section header spacing (top)
    static let listSectionHeaderSpacingTop: CGFloat = 16
    
    /// List section header spacing (bottom)
    static let listSectionHeaderSpacingBottom: CGFloat = 8
    
    // MARK: - Grid Spacing
    
    /// Grid column spacing (small)
    static let gridColumnSpacingSmall: CGFloat = 8
    
    /// Grid column spacing (regular)
    static let gridColumnSpacing: CGFloat = 12
    
    /// Grid column spacing (large)
    static let gridColumnSpacingLarge: CGFloat = 16
    
    /// Grid row spacing (small)
    static let gridRowSpacingSmall: CGFloat = 8
    
    /// Grid row spacing (regular)
    static let gridRowSpacing: CGFloat = 12
    
    /// Grid row spacing (large)
    static let gridRowSpacingLarge: CGFloat = 16
    
    // MARK: - Edge Insets
    
    /// Standard edge insets for content
    static let contentInsets = EdgeInsets(
        top: screenPadding,
        leading: screenPadding,
        bottom: screenPadding,
        trailing: screenPadding
    )
    
    /// Edge insets for cards
    static let cardInsets = EdgeInsets(
        top: cardPadding,
        leading: cardPadding,
        bottom: cardPadding,
        trailing: cardPadding
    )
    
    /// Edge insets for list items
    static let listItemInsets = EdgeInsets(
        top: listItemPaddingVertical,
        leading: listItemPaddingHorizontal,
        bottom: listItemPaddingVertical,
        trailing: listItemPaddingHorizontal
    )
    
    /// Edge insets for buttons
    static let buttonInsets = EdgeInsets(
        top: buttonPaddingVertical,
        leading: buttonPaddingHorizontal,
        bottom: buttonPaddingVertical,
        trailing: buttonPaddingHorizontal
    )
    
    // MARK: - Helper Functions
    
    /// Returns spacing for a specific multiplier
    static func spacing(_ multiplier: CGFloat) -> CGFloat {
        return sm * multiplier // Based on 8pt grid
    }
    
    /// Returns horizontal edge padding
    static func horizontal(_ value: CGFloat) -> EdgeInsets {
        return EdgeInsets(top: 0, leading: value, bottom: 0, trailing: value)
    }
    
    /// Returns vertical edge padding
    static func vertical(_ value: CGFloat) -> EdgeInsets {
        return EdgeInsets(top: value, leading: 0, bottom: value, trailing: 0)
    }
    
    /// Returns symmetric edge padding
    static func symmetric(horizontal: CGFloat = 0, vertical: CGFloat = 0) -> EdgeInsets {
        return EdgeInsets(top: vertical, leading: horizontal, bottom: vertical, trailing: horizontal)
    }
    
    /// Returns all-sides equal edge padding
    static func all(_ value: CGFloat) -> EdgeInsets {
        return EdgeInsets(top: value, leading: value, bottom: value, trailing: value)
    }
}

// MARK: - View Extensions

extension View {
    /// Applies screen edge padding
    func applyScreenPadding() -> some View {
        self.padding(.all, ThemeSpacing.screenPadding)
    }
    
    /// Applies card padding
    func applyCardPadding() -> some View {
        self.padding(.all, ThemeSpacing.cardPadding)
    }
    
    /// Applies section spacing
    func applySectionSpacing() -> some View {
        self.padding(.vertical, ThemeSpacing.sectionSpacing)
    }
    
    /// Applies custom edge insets
    func applyCustomPadding(_ insets: EdgeInsets) -> some View {
        self.padding(.top, insets.top)
            .padding(.leading, insets.leading)
            .padding(.bottom, insets.bottom)
            .padding(.trailing, insets.trailing)
    }
}

// MARK: - Preview

#Preview("Spacing Scale") {
    ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            Text("Base Spacing Scale")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                SpacingRow(value: ThemeSpacing.xxxs, name: "xxxs (2pt)")
                SpacingRow(value: ThemeSpacing.xxs, name: "xxs (4pt)")
                SpacingRow(value: ThemeSpacing.xs, name: "xs (6pt)")
                SpacingRow(value: ThemeSpacing.sm, name: "sm (8pt)")
                SpacingRow(value: ThemeSpacing.md, name: "md (12pt)")
                SpacingRow(value: ThemeSpacing.lg, name: "lg (16pt)")
                SpacingRow(value: ThemeSpacing.xl, name: "xl (20pt)")
                SpacingRow(value: ThemeSpacing.xxl, name: "xxl (24pt)")
                SpacingRow(value: ThemeSpacing.xxxl, name: "xxxl (32pt)")
                SpacingRow(value: ThemeSpacing.xxxxl, name: "xxxxl (40pt)")
            }
            
            Divider()
                .padding(.vertical)
            
            Text("Semantic Spacing")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                SpacingRow(value: ThemeSpacing.elementSpacing, name: "Element Spacing")
                SpacingRow(value: ThemeSpacing.sectionSpacing, name: "Section Spacing")
                SpacingRow(value: ThemeSpacing.screenPadding, name: "Screen Padding")
                SpacingRow(value: ThemeSpacing.cardPadding, name: "Card Padding")
                SpacingRow(value: ThemeSpacing.buttonPaddingHorizontal, name: "Button Padding (H)")
            }
            
            Divider()
                .padding(.vertical)
            
            Text("Layout Dimensions")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                DimensionRow(value: ThemeSpacing.sidebarWidth, name: "Sidebar Width")
                DimensionRow(value: ThemeSpacing.toolbarHeight, name: "Toolbar Height")
                DimensionRow(value: ThemeSpacing.formMaxWidth, name: "Form Max Width")
                DimensionRow(value: ThemeSpacing.contentMaxWidth, name: "Content Max Width")
            }
        }
        .padding()
    }
    .frame(width: 500, height: 700)
}

// Helper views
struct SpacingRow: View {
    let value: CGFloat
    let name: String
    
    var body: some View {
        HStack {
            Rectangle()
                .fill(Color.blue)
                .frame(width: value, height: 20)
            
            Text(name)
                .font(.system(size: 12))
            
            Spacer()
            
            Text("\(Int(value))pt")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }
}

struct DimensionRow: View {
    let value: CGFloat
    let name: String
    
    var body: some View {
        HStack {
            Text(name)
                .font(.system(size: 12))
            
            Spacer()
            
            Text("\(Int(value))pt")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }
}

#Preview("Spacing in Context") {
    VStack(spacing: ThemeSpacing.sectionSpacing) {
        VStack(alignment: .leading, spacing: ThemeSpacing.elementSpacing) {
            Text("Card Title")
                .font(.headline)
            Text("This card uses semantic spacing values.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.all, ThemeSpacing.screenPadding)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
        
        HStack(spacing: ThemeSpacing.iconTextSpacing) {
            Image(systemName: "star.fill")
            Text("Icon with text spacing")
        }
    }
    .padding(.all, ThemeSpacing.screenPadding)
    .frame(width: 400)
}
