//
//  GmailService.swift
//  Diligence
//
//  Gmail service implementation for email operations
//

import Foundation
import AuthenticationServices

/// Gmail service implementation
///
/// Provides Gmail API integration including OAuth authentication,
/// message fetching, and attachment downloads.
@MainActor
final class CoreGmailService: NSObject, EmailServiceProtocol {
    
    // MARK: - Properties
    
    private var configuration: EmailServiceConfiguration?
    private var credentials: OAuthCredentials?
    private var authSession: ASWebAuthenticationSession?
    
    /// Current authentication state
    var isAuthenticated: Bool {
        guard let credentials = credentials else { return false }
        return credentials.expiresAt > Date()
    }
    
    /// User's email address
    var userEmail: String?
    
    // MARK: - Configuration
    
    func configure(_ configuration: EmailServiceConfiguration) throws {
        guard !configuration.clientId.isEmpty else {
            throw EmailServiceError.invalidConfiguration("Client ID is required")
        }
        
        self.configuration = configuration
        
        // Try to restore saved credentials
        restoreCredentials()
        
        print("✅ GmailService configured")
    }
    
    // MARK: - Authentication
    
    func authenticate() async throws -> String {
        guard let config = configuration else {
            throw EmailServiceError.notConfigured
        }
        
        // Build authorization URL
        let authURL = try buildAuthorizationURL(config: config)
        
        // Perform OAuth flow
        let authCode = try await performOAuthFlow(authURL: authURL, redirectURI: config.redirectUri)
        
        // Exchange code for tokens
        let tokenResponse = try await exchangeCodeForTokens(code: authCode, config: config)
        
        // Store credentials
        let expiresAt = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
        credentials = OAuthCredentials(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken,
            expiresAt: expiresAt
        )
        
        // Save credentials
        saveCredentials()
        
        // Fetch user profile to get email
        let email = try await fetchUserEmail()
        userEmail = email
        
        print("✅ Gmail authentication successful: \(email)")
        return email
    }
    
    func signOut() throws {
        credentials = nil
        userEmail = nil
        clearSavedCredentials()
        print("✅ Signed out from Gmail")
    }
    
    func refreshToken() async throws -> Bool {
        guard let currentCredentials = credentials,
              let refreshToken = currentCredentials.refreshToken,
              let config = configuration else {
            throw EmailServiceError.notAuthenticated
        }
        
        // Build token refresh request
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let parameters = [
            "client_id": config.clientId,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]
        
        request.httpBody = parameters
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw EmailServiceError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw EmailServiceError.tokenRefreshFailed("HTTP \(httpResponse.statusCode)")
        }
        
        let tokenResponse = try JSONDecoder().decode(OAuthTokenResponse.self, from: data)
        
        // Update credentials
        let expiresAt = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
        credentials = OAuthCredentials(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken ?? refreshToken,
            expiresAt: expiresAt
        )
        
        saveCredentials()
        
        print("✅ Token refreshed successfully")
        return true
    }
    
    // MARK: - Message Operations
    
    func fetchMessages(
        query: String?,
        maxResults: Int,
        pageToken: String?
    ) async throws -> GmailMessagesResponse {
        guard isAuthenticated else {
            throw EmailServiceError.notAuthenticated
        }
        
        guard let config = configuration else {
            throw EmailServiceError.notConfigured
        }
        
        // Build URL with query parameters
        var urlComponents = URLComponents(string: "\(config.baseURL)/users/me/messages")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "maxResults", value: "\(maxResults)")
        ]
        
        if let query = query {
            queryItems.append(URLQueryItem(name: "q", value: query))
        }
        
        if let pageToken = pageToken {
            queryItems.append(URLQueryItem(name: "pageToken", value: pageToken))
        }
        
        urlComponents.queryItems = queryItems
        
        // Make request
        var request = URLRequest(url: urlComponents.url!)
        request.setValue("Bearer \(credentials!.accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw EmailServiceError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                // Try to refresh token and retry
                if try await refreshToken() {
                    return try await fetchMessages(query: query, maxResults: maxResults, pageToken: pageToken)
                }
            }
            throw EmailServiceError.serverError(statusCode: httpResponse.statusCode, message: nil)
        }
        
        let messagesResponse = try JSONDecoder().decode(GmailMessagesResponse.self, from: data)
        
        print("✅ Fetched \(messagesResponse.messages?.count ?? 0) message references")
        return messagesResponse
    }
    
    func getMessage(id: String) async throws -> GmailMessage {
        guard isAuthenticated else {
            throw EmailServiceError.notAuthenticated
        }
        
        guard let config = configuration else {
            throw EmailServiceError.notConfigured
        }
        
        // Build URL
        let url = URL(string: "\(config.baseURL)/users/me/messages/\(id)?format=full")!
        
        // Make request
        var request = URLRequest(url: url)
        request.setValue("Bearer \(credentials!.accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw EmailServiceError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                // Try to refresh token and retry
                if try await refreshToken() {
                    return try await getMessage(id: id)
                }
            }
            if httpResponse.statusCode == 404 {
                throw EmailServiceError.messageNotFound(id)
            }
            throw EmailServiceError.serverError(statusCode: httpResponse.statusCode, message: nil)
        }
        
        let message = try JSONDecoder().decode(GmailMessage.self, from: data)
        return message
    }
    
    func getAttachment(messageId: String, attachmentId: String) async throws -> Data {
        guard isAuthenticated else {
            throw EmailServiceError.notAuthenticated
        }
        
        guard let config = configuration else {
            throw EmailServiceError.notConfigured
        }
        
        // Build URL
        let url = URL(string: "\(config.baseURL)/users/me/messages/\(messageId)/attachments/\(attachmentId)")!
        
        // Make request
        var request = URLRequest(url: url)
        request.setValue("Bearer \(credentials!.accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw EmailServiceError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                // Try to refresh token and retry
                if try await refreshToken() {
                    return try await getAttachment(messageId: messageId, attachmentId: attachmentId)
                }
            }
            if httpResponse.statusCode == 404 {
                throw EmailServiceError.attachmentNotFound(attachmentId)
            }
            throw EmailServiceError.serverError(statusCode: httpResponse.statusCode, message: nil)
        }
        
        // Decode the attachment body (Base64URL encoded)
        struct AttachmentBody: Codable {
            let data: String
            let size: Int
        }
        
        let attachmentBody = try JSONDecoder().decode(AttachmentBody.self, from: data)
        
        // Decode Base64URL data
        guard let decodedData = Data(base64URLEncoded: attachmentBody.data) else {
            throw EmailServiceError.invalidResponse
        }
        
        return decodedData
    }
    
    // MARK: - Private Methods
    
    private func buildAuthorizationURL(config: EmailServiceConfiguration) throws -> URL {
        var urlComponents = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        
        urlComponents.queryItems = [
            URLQueryItem(name: "client_id", value: config.clientId),
            URLQueryItem(name: "redirect_uri", value: config.redirectUri),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: config.scopes.joined(separator: " ")),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]
        
        guard let url = urlComponents.url else {
            throw EmailServiceError.invalidConfiguration("Failed to build authorization URL")
        }
        
        return url
    }
    
    private func performOAuthFlow(authURL: URL, redirectURI: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: URL(string: redirectURI)!.scheme
            ) { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: EmailServiceError.authenticationFailed(error.localizedDescription))
                    return
                }
                
                guard let callbackURL = callbackURL,
                      let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                    .queryItems?
                    .first(where: { $0.name == "code" })?
                    .value else {
                    continuation.resume(throwing: EmailServiceError.authenticationFailed("No authorization code received"))
                    return
                }
                
                continuation.resume(returning: code)
            }
            
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            
            if session.start() {
                self.authSession = session
            } else {
                continuation.resume(throwing: EmailServiceError.authenticationFailed("Failed to start authentication session"))
            }
        }
    }
    
    private func exchangeCodeForTokens(code: String, config: EmailServiceConfiguration) async throws -> OAuthTokenResponse {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let parameters = [
            "code": code,
            "client_id": config.clientId,
            "redirect_uri": config.redirectUri,
            "grant_type": "authorization_code"
        ]
        
        request.httpBody = parameters
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw EmailServiceError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw EmailServiceError.authenticationFailed("Token exchange failed with status \(httpResponse.statusCode)")
        }
        
        let tokenResponse = try JSONDecoder().decode(OAuthTokenResponse.self, from: data)
        return tokenResponse
    }
    
    private func fetchUserEmail() async throws -> String {
        guard let config = configuration else {
            throw EmailServiceError.notConfigured
        }
        
        let url = URL(string: "\(config.baseURL)/users/me/profile")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(credentials!.accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw EmailServiceError.invalidResponse
        }
        
        struct Profile: Codable {
            let emailAddress: String
        }
        
        let profile = try JSONDecoder().decode(Profile.self, from: data)
        return profile.emailAddress
    }
    
    // MARK: - Credential Persistence
    
    private func saveCredentials() {
        guard let credentials = credentials else { return }
        
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode([
            "accessToken": credentials.accessToken,
            "refreshToken": credentials.refreshToken ?? "",
            "expiresAt": String(credentials.expiresAt.timeIntervalSince1970)
        ]) {
            UserDefaults.standard.set(encoded, forKey: "gmail_credentials")
        }
    }
    
    private func restoreCredentials() {
        guard let data = UserDefaults.standard.data(forKey: "gmail_credentials"),
              let dict = try? JSONDecoder().decode([String: String].self, from: data),
              let accessToken = dict["accessToken"],
              let refreshToken = dict["refreshToken"],
              let expiresAtString = dict["expiresAt"],
              let expiresAtInterval = Double(expiresAtString) else {
            return
        }
        
        let expiresAt = Date(timeIntervalSince1970: expiresAtInterval)
        credentials = OAuthCredentials(
            accessToken: accessToken,
            refreshToken: refreshToken.isEmpty ? nil : refreshToken,
            expiresAt: expiresAt
        )
        
        // Also restore email
        userEmail = UserDefaults.standard.string(forKey: "gmail_user_email")
    }
    
    private func clearSavedCredentials() {
        UserDefaults.standard.removeObject(forKey: "gmail_credentials")
        UserDefaults.standard.removeObject(forKey: "gmail_user_email")
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension CoreGmailService: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Return the key window
        // ASWebAuthenticationSession calls this method on the main thread, so we can safely assume main actor isolation
        return MainActor.assumeIsolated {
            return NSApplication.shared.windows.first { $0.isKeyWindow } ?? NSApplication.shared.windows.first!
        }
    }
}

// MARK: - Base64URL Extension

extension Data {
    /// Initializes Data from a Base64URL-encoded string
    init?(base64URLEncoded string: String) {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        // Add padding if necessary
        let paddingLength = (4 - base64.count % 4) % 4
        base64 += String(repeating: "=", count: paddingLength)
        
        self.init(base64Encoded: base64)
    }
}
