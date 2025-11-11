//
//  ProcessedEmail.swift
//  Diligence
//
//  Simplified email model for UI display and task creation
//

import Foundation

// MARK: - Processed Email Model

/// A simplified, processed representation of an email for UI display
///
/// `ProcessedEmail` is created from raw Gmail API responses and contains
/// only the essential information needed for displaying emails and creating
/// tasks. This model handles all the parsing and extraction of Gmail's
/// complex MIME structure.
///
/// ## Topics
///
/// ### Properties
/// - ``id``
/// - ``threadId``
/// - ``subject``
/// - ``sender``
/// - ``senderEmail``
/// - ``body``
/// - ``snippet``
/// - ``receivedDate``
/// - ``gmailURL``
/// - ``attachments``
///
/// ### Computed Properties
/// - ``hasAttachments``
/// - ``attachmentCount``
struct ProcessedEmail: Identifiable, Equatable, Hashable, Codable {
    /// Unique Gmail message identifier
    let id: String
    
    /// Gmail thread identifier this email belongs to
    let threadId: String
    
    /// Email subject line
    let subject: String
    
    /// Display name of the sender (e.g., "John Doe")
    let sender: String
    
    /// Email address of the sender (e.g., "john@example.com")
    let senderEmail: String
    
    /// Email body content (plain text or HTML converted to plain text)
    let body: String
    
    /// Short preview text from Gmail
    let snippet: String
    
    /// Date the email was received
    let receivedDate: Date
    
    /// Deep link URL to open this email in Gmail web interface
    let gmailURL: URL
    
    /// Array of attachments included in this email
    let attachments: [EmailAttachment]
    
    // MARK: - Computed Properties
    
    /// Returns `true` if the email has attachments
    var hasAttachments: Bool {
        return !attachments.isEmpty
    }
    
    /// Number of attachments in this email
    var attachmentCount: Int {
        return attachments.count
    }
    
    /// Formatted string describing attachments (e.g., "3 attachments")
    var attachmentDescription: String {
        guard hasAttachments else { return "No attachments" }
        return attachmentCount == 1 ? "1 attachment" : "\(attachmentCount) attachments"
    }
    
    // MARK: - Conformance
    
    static func == (lhs: ProcessedEmail, rhs: ProcessedEmail) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Email Processing Helpers

extension ProcessedEmail {
    /// Creates a ProcessedEmail from a GmailMessage
    ///
    /// This initializer handles parsing the Gmail API response and extracting
    /// all relevant information into a simpler format.
    ///
    /// - Parameter gmailMessage: The raw Gmail message from the API
    /// - Returns: A processed email, or `nil` if parsing failed
    static func from(_ gmailMessage: GmailMessage) -> ProcessedEmail? {
        // Extract subject
        let subject = gmailMessage.payload?.headers?.first(where: { $0.name == "Subject" })?.value ?? "(No Subject)"
        
        // Extract sender information
        let fromHeader = gmailMessage.payload?.headers?.first(where: { $0.name == "From" })?.value ?? ""
        let (senderName, senderEmail) = parseSenderInfo(from: fromHeader)
        
        // Extract body
        let body = extractBody(from: gmailMessage.payload) ?? gmailMessage.snippet ?? ""
        
        // Parse received date
        let receivedDate = parseInternalDate(gmailMessage.internalDate) ?? Date()
        
        // Build Gmail URL
        guard let gmailURL = URL(string: "https://mail.google.com/mail/u/0/#inbox/\(gmailMessage.id)") else {
            return nil
        }
        
        // Extract attachments
        let attachments = extractAttachments(from: gmailMessage.payload, messageId: gmailMessage.id)
        
        return ProcessedEmail(
            id: gmailMessage.id,
            threadId: gmailMessage.threadId,
            subject: subject,
            sender: senderName,
            senderEmail: senderEmail,
            body: body,
            snippet: gmailMessage.snippet ?? "",
            receivedDate: receivedDate,
            gmailURL: gmailURL,
            attachments: attachments
        )
    }
    
    /// Parses sender name and email from a "From" header
    ///
    /// Handles formats like:
    /// - "John Doe <john@example.com>"
    /// - "john@example.com"
    ///
    /// - Parameter fromHeader: The raw "From" header value
    /// - Returns: A tuple of (display name, email address)
    private static func parseSenderInfo(from fromHeader: String) -> (String, String) {
        // Match pattern: "Name <email@example.com>"
        let pattern = #"^(.*?)\s*<(.+?)>$"#
        
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: fromHeader, range: NSRange(fromHeader.startIndex..., in: fromHeader)) {
            
            if let nameRange = Range(match.range(at: 1), in: fromHeader),
               let emailRange = Range(match.range(at: 2), in: fromHeader) {
                let name = String(fromHeader[nameRange]).trimmingCharacters(in: .whitespaces)
                let email = String(fromHeader[emailRange])
                return (name.isEmpty ? email : name, email)
            }
        }
        
        // Fallback: just use the whole string as email
        return (fromHeader, fromHeader)
    }
    
    /// Extracts the body text from a Gmail payload
    ///
    /// Recursively searches through MIME parts to find text content.
    ///
    /// - Parameter payload: The Gmail message payload
    /// - Returns: The extracted body text, or `nil` if not found
    private static func extractBody(from payload: GmailPayload?) -> String? {
        guard let payload = payload else { return nil }
        
        // Check if this part has body data
        if let bodyData = payload.body?.data,
           let decoded = decodeBase64URL(bodyData) {
            return decoded
        }
        
        // Recursively check parts (for multipart messages)
        if let parts = payload.parts {
            for part in parts {
                if let body = extractBody(from: part) {
                    return body
                }
            }
        }
        
        return nil
    }
    
    /// Extracts attachments from a Gmail payload
    ///
    /// - Parameters:
    ///   - payload: The Gmail message payload
    ///   - messageId: The message ID attachments belong to
    /// - Returns: Array of EmailAttachment objects
    private static func extractAttachments(from payload: GmailPayload?, messageId: String) -> [EmailAttachment] {
        guard let payload = payload else { return [] }
        
        var attachments: [EmailAttachment] = []
        
        // Check if this part is an attachment
        if let filename = payload.filename,
           !filename.isEmpty,
           let body = payload.body,
           let attachmentId = body.attachmentId,
           let size = body.size {
            
            let attachment = EmailAttachment(
                id: attachmentId,
                filename: filename,
                mimeType: payload.mimeType ?? "application/octet-stream",
                size: size,
                messageId: messageId
            )
            attachments.append(attachment)
        }
        
        // Recursively check parts
        if let parts = payload.parts {
            for part in parts {
                attachments.append(contentsOf: extractAttachments(from: part, messageId: messageId))
            }
        }
        
        return attachments
    }
    
    /// Parses Gmail's internal date string to a Date
    ///
    /// Gmail uses milliseconds since Unix epoch.
    ///
    /// - Parameter internalDate: The internal date string from Gmail
    /// - Returns: A Date object, or `nil` if parsing failed
    private static func parseInternalDate(_ internalDate: String?) -> Date? {
        guard let dateString = internalDate,
              let timestamp = Double(dateString) else {
            return nil
        }
        
        // Gmail uses milliseconds, convert to seconds
        return Date(timeIntervalSince1970: timestamp / 1000.0)
    }
    
    /// Decodes Base64URL-encoded string
    ///
    /// Gmail uses Base64URL encoding (RFC 4648) which uses `-` and `_`
    /// instead of `+` and `/`.
    ///
    /// - Parameter base64URL: Base64URL-encoded string
    /// - Returns: Decoded string, or `nil` if decoding failed
    private static func decodeBase64URL(_ base64URL: String) -> String? {
        // Convert Base64URL to standard Base64
        var base64 = base64URL
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        // Add padding if needed
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        
        guard let data = Data(base64Encoded: base64),
              let decoded = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return decoded
    }
}
