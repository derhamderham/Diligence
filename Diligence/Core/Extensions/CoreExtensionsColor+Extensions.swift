//
//  Color+Extensions.swift
//  Diligence
//
//  Color initialization and manipulation utilities
//

import AppKit
import SwiftUI
import Combine

// MARK: - NSColor Hex Initialization

extension NSColor {
    /// Creates an NSColor from a hex string
    ///
    /// Supports the following formats:
    /// - RGB (12-bit): "RGB" (e.g., "F0A")
    /// - RGB (24-bit): "RRGGBB" (e.g., "FF00AA")
    /// - ARGB (32-bit): "AARRGGBB" (e.g., "80FF00AA")
    ///
    /// The hex string can optionally include a "#" prefix.
    ///
    /// - Parameter hex: Hex color string
    /// - Returns: NSColor, or nil if the hex string is invalid
    ///
    /// Example:
    /// ```swift
    /// let red = NSColor(hex: "#FF0000")
    /// let green = NSColor(hex: "00FF00")
    /// let semiTransparentBlue = NSColor(hex: "800000FF")
    /// ```
    
    
    /// Converts the color to a hex string
    ///
    /// - Parameter includeAlpha: Whether to include alpha in the hex string
    /// - Returns: Hex string (e.g., "#FF0000" or "#80FF0000")
    func toHexString(includeAlpha: Bool = false) -> String {
        guard let rgbColor = usingColorSpace(.deviceRGB) else {
            return "#000000"
        }
        
        let red = Int(round(rgbColor.redComponent * 255))
        let green = Int(round(rgbColor.greenComponent * 255))
        let blue = Int(round(rgbColor.blueComponent * 255))
        
        if includeAlpha {
            let alpha = Int(round(rgbColor.alphaComponent * 255))
            return String(format: "#%02X%02X%02X%02X", alpha, red, green, blue)
        } else {
            return String(format: "#%02X%02X%02X", red, green, blue)
        }
    }
}

// MARK: - SwiftUI Color Hex Initialization

extension Color {
    /// Creates a Color from a hex string
    ///
    /// - Parameter hex: Hex color string
    /// - Returns: Color, or nil if the hex string is invalid
    ///
    /// Example:
    /// ```swift
    /// let red = Color(hex: "#FF0000")
    /// ```
    init?(hex: String) {
        guard let nsColor = NSColor(hex: hex) else {
            return nil
        }
        self.init(nsColor: nsColor)
    }
    
    /// Converts the color to a hex string
    ///
    /// - Parameter includeAlpha: Whether to include alpha in the hex string
    /// - Returns: Hex string
    func toHexString(includeAlpha: Bool = false) -> String {
        let nsColor = NSColor(self)
        return nsColor.toHexString(includeAlpha: includeAlpha)
    }
}

// MARK: - Color Manipulation

extension NSColor {
    /// Returns a lighter version of the color
    ///
    /// - Parameter percentage: Amount to lighten (0.0 to 1.0)
    /// - Returns: Lightened color
    func lighter(by percentage: CGFloat = 0.3) -> NSColor {
        return adjustBrightness(by: abs(percentage))
    }
    
    /// Returns a darker version of the color
    ///
    /// - Parameter percentage: Amount to darken (0.0 to 1.0)
    /// - Returns: Darkened color
    func darker(by percentage: CGFloat = 0.3) -> NSColor {
        return adjustBrightness(by: -abs(percentage))
    }
    
    /// Adjusts the brightness of the color
    ///
    /// - Parameter percentage: Percentage to adjust (-1.0 to 1.0)
    /// - Returns: Adjusted color
    private func adjustBrightness(by percentage: CGFloat) -> NSColor {
        guard let rgbColor = usingColorSpace(.deviceRGB) else {
            return self
        }
        
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        rgbColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        brightness = max(0, min(1, brightness + percentage))
        
        return NSColor(
            hue: hue,
            saturation: saturation,
            brightness: brightness,
            alpha: alpha
        )
    }
    
    /// Returns the color with adjusted alpha
    ///
    /// - Parameter alpha: New alpha value (0.0 to 1.0)
    /// - Returns: Color with new alpha
    func withAlpha(_ alpha: CGFloat) -> NSColor {
        return withAlphaComponent(alpha)
    }
}

extension Color {
    /// Returns a lighter version of the color
    ///
    /// - Parameter percentage: Amount to lighten (0.0 to 1.0)
    /// - Returns: Lightened color
    func lighter(by percentage: CGFloat = 0.3) -> Color {
        let nsColor = NSColor(self)
        return Color(nsColor: nsColor.lighter(by: percentage))
    }
    
    /// Returns a darker version of the color
    ///
    /// - Parameter percentage: Amount to darken (0.0 to 1.0)
    /// - Returns: Darkened color
    func darker(by percentage: CGFloat = 0.3) -> Color {
        let nsColor = NSColor(self)
        return Color(nsColor: nsColor.darker(by: percentage))
    }
    
    /// Returns the color with adjusted opacity
    ///
    /// - Parameter opacity: New opacity value (0.0 to 1.0)
    /// - Returns: Color with new opacity
    func withOpacity(_ opacity: Double) -> Color {
        return self.opacity(opacity)
    }
}

// MARK: - Predefined Colors

extension Color {
    /// Task priority colors
    struct Priority {
        static let low = Color.gray
        static let normal = Color.blue
        static let high = Color.orange
        static let urgent = Color.red
    }
    
    /// Status indicator colors
    struct Status {
        static let success = Color.green
        static let warning = Color.orange
        static let error = Color.red
        static let info = Color.blue
        static let inactive = Color.gray
    }
    
    /// AI provider colors
    struct AIProvider {
        static let appleIntelligence = Color.blue
        static let janAI = Color.purple
    }
}

extension NSColor {
    /// Task priority colors
    struct Priority {
        static let low = NSColor.gray
        static let normal = NSColor.systemBlue
        static let high = NSColor.systemOrange
        static let urgent = NSColor.systemRed
    }
    
    /// Status indicator colors
    struct Status {
        static let success = NSColor.systemGreen
        static let warning = NSColor.systemOrange
        static let error = NSColor.systemRed
        static let info = NSColor.systemBlue
        static let inactive = NSColor.systemGray
    }
}

// MARK: - Color Contrast

extension NSColor {
    /// Determines if this color is considered "dark"
    ///
    /// - Returns: `true` if the color is dark
    var isDark: Bool {
        guard let rgbColor = usingColorSpace(.deviceRGB) else {
            return false
        }
        
        // Calculate relative luminance
        let red = rgbColor.redComponent
        let green = rgbColor.greenComponent
        let blue = rgbColor.blueComponent
        
        let luminance = 0.299 * red + 0.587 * green + 0.114 * blue
        
        return luminance < 0.5
    }
    
    /// Returns a contrasting color (black or white) for text on this background
    ///
    /// - Returns: Black or white color for maximum contrast
    var contrastingTextColor: NSColor {
        return isDark ? .white : .black
    }
}

extension Color {
    /// Determines if this color is considered "dark"
    var isDark: Bool {
        return NSColor(self).isDark
    }
    
    /// Returns a contrasting color (black or white) for text on this background
    var contrastingTextColor: Color {
        let nsColor = NSColor(self)
        return Color(nsColor: nsColor.contrastingTextColor)
    }
}
