//
//  GmailModels.swift
//  Diligence
//
//  Data models for Gmail API integration
//

import Foundation

// MARK: - Gmail API Response Models

/// Response from the Gmail API messages list endpoint
///
/// Contains a list of message references and pagination information.
struct GmailMessagesResponse: Codable {
    /// Array of message references
    let messages: [GmailMessageReference]?
    
    /// Token for fetching the next page of results
    let nextPageToken: String?
    
    /// Estimated total number of results
    let resultSizeEstimate: Int?
}

/// A lightweight reference to a Gmail message
///
/// Contains only the IDs needed to fetch the full message details.
struct GmailMessageReference: Codable, Identifiable {
    /// Unique message identifier
    let id: String
    
    /// Thread identifier this message belongs to
    let threadId: String
}

/// A complete Gmail message with full details
///
/// Represents a single email message from the Gmail API with all metadata,
/// headers, and body content.
struct GmailMessage: Codable, Identifiable {
    /// Unique message identifier
    let id: String
    
    /// Thread identifier this message belongs to
    let threadId: String
    
    /// Label IDs applied to this message (e.g., "INBOX", "STARRED")
    let labelIds: [String]?
    
    /// Short preview text from the message body
    let snippet: String?
    
    /// The message payload containing headers and body
    let payload: GmailPayload?
    
    /// Timestamp when the message was received (milliseconds since epoch)
    let internalDate: String?
    
    /// History identifier for tracking changes
    let historyId: String?
    
    /// Estimated size of the message in bytes
    let sizeEstimate: Int?
}

/// The message payload containing headers, body, and parts
///
/// Gmail messages are structured as MIME multipart messages. This payload
/// can contain nested parts for multipart messages.
struct GmailPayload: Codable {
    /// The part identifier
    let partId: String?
    
    /// MIME type of this part (e.g., "text/plain", "text/html", "multipart/alternative")
    let mimeType: String?
    
    /// Filename if this part is an attachment
    let filename: String?
    
    /// Message headers (e.g., From, To, Subject, Date)
    let headers: [GmailHeader]?
    
    /// The message body data
    let body: GmailMessageBody?
    
    /// Nested parts for multipart messages
    let parts: [GmailPayload]?
}

/// A single message header (key-value pair)
///
/// Common headers include "From", "To", "Subject", "Date", etc.
struct GmailHeader: Codable {
    /// Header name (e.g., "Subject", "From")
    let name: String
    
    /// Header value
    let value: String
}

/// The body content of a message or part
///
/// Body data is Base64URL-encoded and must be decoded to plain text.
struct GmailMessageBody: Codable {
    /// Attachment ID if this body is an attachment
    let attachmentId: String?
    
    /// Size of the body in bytes
    let size: Int?
    
    /// Base64URL-encoded body data
    let data: String?
}

// MARK: - Attachment Models

/// Represents an email attachment with metadata
///
/// Email attachments are tracked separately to enable downloading and
/// displaying them in the UI.
struct EmailAttachment: Identifiable, Equatable, Hashable, Codable {
    /// Unique attachment identifier from Gmail
    let id: String
    
    /// Filename of the attachment
    let filename: String
    
    /// MIME type (e.g., "image/png", "application/pdf")
    let mimeType: String
    
    /// Size in bytes
    let size: Int
    
    /// The email message ID this attachment belongs to
    let messageId: String
    
    /// File extension extracted from filename
    var fileExtension: String {
        return (filename as NSString).pathExtension.lowercased()
    }
    
    /// Returns `true` if the attachment is an image
    var isImage: Bool {
        return ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp"].contains(fileExtension)
    }
    
    /// Returns `true` if the attachment is a document
    var isDocument: Bool {
        return ["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "rtf"].contains(fileExtension)
    }
    
    /// SF Symbol name representing the file type
    var systemIconName: String {
        if isImage {
            return "photo"
        } else if isDocument {
            return "doc.text"
        } else if fileExtension == "pdf" {
            return "doc.richtext"
        } else if ["zip", "rar", "7z"].contains(fileExtension) {
            return "archivebox"
        } else {
            return "paperclip"
        }
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(messageId)
    }
    
    static func == (lhs: EmailAttachment, rhs: EmailAttachment) -> Bool {
        lhs.id == rhs.id && lhs.messageId == rhs.messageId
    }
}

// MARK: - OAuth Models

/// Response from the OAuth token endpoint
///
/// Contains the access token and refresh token for authenticating with Gmail.
struct OAuthTokenResponse: Codable {
    /// The access token used for API requests
    let accessToken: String
    
    /// Number of seconds until the access token expires
    let expiresIn: Int
    
    /// The refresh token used to obtain new access tokens
    let refreshToken: String?
    
    /// Space-delimited list of granted scopes
    let scope: String
    
    /// Token type (typically "Bearer")
    let tokenType: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
        case tokenType = "token_type"
    }
}

/// Stored OAuth credentials with expiration tracking
///
/// Used to maintain authenticated sessions with the Gmail API.
struct OAuthCredentials {
    /// Current access token
    let accessToken: String
    
    /// Refresh token for obtaining new access tokens
    let refreshToken: String?
    
    /// Date when the access token expires
    let expiresAt: Date
}
