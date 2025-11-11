//
//  String+Extensions.swift
//  Diligence
//
//  String manipulation and validation utilities
//

import Foundation

// MARK: - String Validation Extensions

extension String {
    /// Returns true if the string is not empty after trimming whitespace
    var isNotEmpty: Bool {
        return !trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Returns true if the string is empty after trimming whitespace
    var isBlank: Bool {
        return trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Returns the string trimmed of whitespace and newlines
    var trimmed: String {
        return trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Returns true if the string is a valid email address
    var isValidEmail: Bool {
        let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return predicate.evaluate(with: self)
    }
    
    /// Returns true if the string is a valid URL
    var isValidURL: Bool {
        return URL(string: self) != nil
    }
}

// MARK: - String Truncation

extension String {
    /// Truncates the string to a maximum length, adding an ellipsis if needed
    ///
    /// - Parameters:
    ///   - length: Maximum length
    ///   - trailing: The trailing string to add (default: "...")
    /// - Returns: Truncated string
    func truncate(to length: Int, trailing: String = "...") -> String {
        guard count > length else { return self }
        return String(prefix(length)) + trailing
    }
    
    /// Truncates the string to fit within a word boundary
    ///
    /// - Parameters:
    ///   - length: Approximate maximum length
    ///   - trailing: The trailing string to add (default: "...")
    /// - Returns: Truncated string ending at a word boundary
    func truncateAtWordBoundary(to length: Int, trailing: String = "...") -> String {
        guard count > length else { return self }
        
        let truncated = String(prefix(length))
        if let lastSpace = truncated.lastIndex(of: " ") {
            return String(truncated[..<lastSpace]) + trailing
        }
        
        return truncated + trailing
    }
}

// MARK: - HTML/XML Processing

extension String {
    /// Removes HTML tags from the string
    ///
    /// - Returns: String with HTML tags removed
    func removingHTMLTags() -> String {
        return replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression
        )
    }
    
    /// Decodes HTML entities (e.g., &amp; → &)
    ///
    /// - Returns: String with decoded HTML entities
    func decodingHTMLEntities() -> String {
        var result = self
        
        // Common HTML entities
        let entities = [
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&apos;": "'",
            "&nbsp;": " ",
            "&#39;": "'",
            "&#x27;": "'",
            "&mdash;": "—",
            "&ndash;": "–",
            "&hellip;": "…",
            "&copy;": "©",
            "&reg;": "®",
            "&trade;": "™"
        ]
        
        for (entity, replacement) in entities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        
        // Decode numeric entities (e.g., &#65; or &#x41;)
        result = result.replacingNumericHTMLEntities()
        
        return result
    }
    
    /// Helper to decode numeric HTML entities
    private func replacingNumericHTMLEntities() -> String {
        var result = self
        
        // Decode decimal entities (e.g., &#65;)
        let decimalPattern = "&#(\\d+);"
        if let regex = try? NSRegularExpression(pattern: decimalPattern) {
            let nsString = result as NSString
            let matches = regex.matches(in: result, range: NSRange(location: 0, length: nsString.length))
            
            // Process matches in reverse to maintain correct indices
            for match in matches.reversed() {
                if match.numberOfRanges >= 2 {
                    let fullRange = match.range(at: 0)
                    let numberRange = match.range(at: 1)
                    
                    if let numberString = Range(numberRange, in: result),
                       let number = Int(result[numberString]),
                       let scalar = UnicodeScalar(number) {
                        let replacement = String(Character(scalar))
                        if let fullStringRange = Range(fullRange, in: result) {
                            result.replaceSubrange(fullStringRange, with: replacement)
                        }
                    }
                }
            }
        }
        
        // Decode hexadecimal entities (e.g., &#x41;)
        let hexPattern = "&#x([0-9A-Fa-f]+);"
        if let regex = try? NSRegularExpression(pattern: hexPattern) {
            let nsString = result as NSString
            let matches = regex.matches(in: result, range: NSRange(location: 0, length: nsString.length))
            
            // Process matches in reverse to maintain correct indices
            for match in matches.reversed() {
                if match.numberOfRanges >= 2 {
                    let fullRange = match.range(at: 0)
                    let hexRange = match.range(at: 1)
                    
                    if let hexString = Range(hexRange, in: result),
                       let number = Int(result[hexString], radix: 16),
                       let scalar = UnicodeScalar(number) {
                        let replacement = String(Character(scalar))
                        if let fullStringRange = Range(fullRange, in: result) {
                            result.replaceSubrange(fullStringRange, with: replacement)
                        }
                    }
                }
            }
        }
        
        return result
    }
    
    /// Converts HTML to plain text
    ///
    /// - Returns: Plain text version of HTML
    func htmlToPlainText() -> String {
        return decodingHTMLEntities().removingHTMLTags()
    }
}

// MARK: - Base64URL Encoding/Decoding

extension String {
    /// Decodes a Base64URL-encoded string (used by Gmail API)
    ///
    /// Base64URL uses `-` and `_` instead of `+` and `/`
    ///
    /// - Returns: Decoded string, or nil if decoding fails
    func decodingBase64URL() -> String? {
        // Convert Base64URL to standard Base64
        var base64 = self
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        // Add padding if needed
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        
        // Decode
        guard let data = Data(base64Encoded: base64),
              let decoded = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return decoded
    }
    
    /// Encodes a string to Base64URL format
    ///
    /// - Returns: Base64URL-encoded string
    func encodingBase64URL() -> String {
        guard let data = self.data(using: .utf8) else { return "" }
        
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - Email Parsing

extension String {
    /// Parses an email "From" header to extract name and address
    ///
    /// Handles formats like:
    /// - "John Doe <john@example.com>"
    /// - "john@example.com"
    /// - "<john@example.com>"
    ///
    /// - Returns: Tuple of (name, email) where name may equal email if no name is provided
    func parseEmailAddress() -> (name: String, email: String) {
        let pattern = #"^(.*?)\s*<(.+?)>$"#
        
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: self, range: NSRange(self.startIndex..., in: self)) {
            
            if let nameRange = Range(match.range(at: 1), in: self),
               let emailRange = Range(match.range(at: 2), in: self) {
                let name = String(self[nameRange]).trimmed
                let email = String(self[emailRange])
                return (name.isEmpty ? email : name, email)
            }
        }
        
        // No angle brackets, assume the whole string is an email
        let trimmed = self.trimmed
        return (trimmed, trimmed)
    }
}

// MARK: - String Masking

extension String {
    /// Masks part of a string for privacy (e.g., email addresses, API keys)
    ///
    /// Example: "user@example.com" → "u***@example.com"
    ///
    /// - Parameters:
    ///   - style: Masking style (default: middle)
    ///   - visibleCount: Number of characters to keep visible
    ///   - maskCharacter: Character to use for masking
    /// - Returns: Masked string
    func masked(
        style: MaskingStyle = .middle,
        visibleCount: Int = 3,
        maskCharacter: Character = "*"
    ) -> String {
        guard count > visibleCount * 2 else { return self }
        
        switch style {
        case .start:
            let start = String(repeating: maskCharacter, count: count - visibleCount)
            let end = suffix(visibleCount)
            return start + end
            
        case .end:
            let start = prefix(visibleCount)
            let end = String(repeating: maskCharacter, count: count - visibleCount)
            return start + end
            
        case .middle:
            let start = prefix(visibleCount)
            let end = suffix(visibleCount)
            let middleCount = count - (visibleCount * 2)
            let middle = String(repeating: maskCharacter, count: middleCount)
            return start + middle + end
            
        case .email:
            // Special handling for email addresses
            if let atIndex = firstIndex(of: "@") {
                let localPart = String(self[..<atIndex])
                let domainPart = String(self[atIndex...])
                
                let maskedLocal = localPart.masked(style: .middle, visibleCount: 1)
                return maskedLocal + domainPart
            }
            return masked(style: .middle, visibleCount: visibleCount, maskCharacter: maskCharacter)
        }
    }
    
    /// Masking styles
    enum MaskingStyle {
        /// Mask the beginning (e.g., "***example")
        case start
        
        /// Mask the end (e.g., "exam***")
        case end
        
        /// Mask the middle (e.g., "ex***le")
        case middle
        
        /// Mask email addresses intelligently
        case email
    }
}

// MARK: - Plural Helpers

extension String {
    /// Returns the string with an 's' added if count != 1
    ///
    /// - Parameter count: The count to check
    /// - Returns: Pluralized string
    func pluralized(count: Int) -> String {
        return count == 1 ? self : self + "s"
    }
}


