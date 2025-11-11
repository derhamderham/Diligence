//
//  GmailService.swift
//  Diligence
//
//  Created by derham on 10/24/25.
//

import Foundation
import AuthenticationServices
import Combine
import CommonCrypto
import AppKit
import Network

protocol GmailServiceProtocol {
    func downloadAttachment(messageId: String, attachmentId: String) async throws -> Data

}

@MainActor
class GmailService: ObservableObject, GmailServiceProtocol {
    func downloadAttachment(messageId: String, attachmentId: String) async throws -> Data {
        guard var credentials = credentials else {
            throw NSError(domain: "GmailService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        // Check if token needs refresh before making API call
        if credentials.expiresAt <= Date().addingTimeInterval(300) { // Refresh if expires within 5 minutes
            guard await refreshAccessToken() else {
                throw NSError(domain: "GmailService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to refresh token"])
            }
            // Update credentials reference after refresh
            guard let refreshedCredentials = self.credentials else {
                throw NSError(domain: "GmailService", code: -3, userInfo: [NSLocalizedDescriptionKey: "No credentials after refresh"])
            }
            credentials = refreshedCredentials
        }
        
        let attachmentURL = URL(string: "\(baseURL)/users/me/messages/\(messageId)/attachments/\(attachmentId)")!
        var request = URLRequest(url: attachmentURL)
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check for authentication errors
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 401 {
                print("📧 Authentication failed for attachment download, attempting token refresh...")
                guard await refreshAccessToken(),
                      let refreshedCredentials = self.credentials else {
                    throw NSError(domain: "GmailService", code: -4, userInfo: [NSLocalizedDescriptionKey: "Authentication failed"])
                }
                
                // Retry the request with refreshed token
                request.setValue("Bearer \(refreshedCredentials.accessToken)", forHTTPHeaderField: "Authorization")
                let (retryData, _) = try await URLSession.shared.data(for: request)
                
                // Parse and decode the attachment data
                let attachmentResponse = try JSONDecoder().decode(AttachmentResponse.self, from: retryData)
                
                guard let decodedData = decodeBase64URLData(attachmentResponse.data) else {
                    throw NSError(domain: "GmailService", code: -5, userInfo: [NSLocalizedDescriptionKey: "Failed to decode attachment data"])
                }
                
                return decodedData
            } else if httpResponse.statusCode >= 400 {
                throw NSError(domain: "GmailService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP error \(httpResponse.statusCode)"])
            }
        }
        
        // Parse the response to get the actual attachment data
        struct AttachmentResponse: Codable {
            let size: Int
            let data: String
        }
        
        let attachmentResponse = try JSONDecoder().decode(AttachmentResponse.self, from: data)
        
        // Decode the base64url encoded data
        guard let decodedData = decodeBase64URLData(attachmentResponse.data) else {
            throw NSError(domain: "GmailService", code: -6, userInfo: [NSLocalizedDescriptionKey: "Failed to decode attachment data"])
        }
        
        return decodedData
    }
    
    @Published var isAuthenticated = false
    @Published var emails: [ProcessedEmail] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var sessionStatus: SessionStatus = .notAuthenticated
    @Published var userEmail: String?
    
    enum SessionStatus {
        case notAuthenticated
        case authenticated
        case expired
        case refreshing
    }
    
    private var credentials: OAuthCredentials?
    private let keychainService = "DiligenceGmailCredentials"
    private var localServer: NWListener?
    private var codeVerifier: String?
    
    // Blacklist for removed emails (stored in UserDefaults)
    private let blacklistKey = "DiligenceRemovedEmails"
    private var removedEmailIds: Set<String> {
        get {
            let array = UserDefaults.standard.stringArray(forKey: blacklistKey) ?? []
            return Set(array)
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: blacklistKey)
        }
    }
    
    // Email caching
    private let emailCacheKey = "DiligenceCachedEmails"
    private let cacheTimestampKey = "DiligenceEmailCacheTimestamp"
    
    // Gmail OAuth configuration
    private let clientID = GmailConfiguration.clientID
    private let clientSecret = GmailConfiguration.clientSecret
    private let redirectURI = GmailConfiguration.redirectURI
    private let scope = GmailConfiguration.scopes.joined(separator: " ")
    
    private let baseURL = "https://www.googleapis.com/gmail/v1"
    
    init() {
        loadCredentialsFromKeychain()
        loadEmailsFromCache()
        
        // Fetch user profile if authenticated
        if isAuthenticated {
            _Concurrency.Task {
                await fetchUserProfile()
            }
        }
    }
    
    // MARK: - Authentication
    
    func startOAuthFlow() {
        // Validate configuration first
        guard !clientID.isEmpty,
              !redirectURI.isEmpty else {
            self.errorMessage = "Gmail OAuth configuration is not set up."
            return
        }
        
        // Generate PKCE parameters
        let codeVerifier = generateCodeVerifier()
        self.codeVerifier = codeVerifier
        let codeChallenge = generateCodeChallenge(from: codeVerifier)
        let state = UUID().uuidString
        
        // Start local server to handle callback and wait for it to be ready
        let serverStarted = startLocalServer()
        
        guard serverStarted else {
            self.errorMessage = "Failed to start local server on port 3000. Please check if another app is using this port."
            return
        }
        
        // Give the server a moment to fully initialize
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            
            var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
            components.queryItems = [
                URLQueryItem(name: "client_id", value: self.clientID),
                URLQueryItem(name: "redirect_uri", value: self.redirectURI),
                URLQueryItem(name: "response_type", value: "code"),
                URLQueryItem(name: "scope", value: self.scope),
                URLQueryItem(name: "state", value: state),
                URLQueryItem(name: "code_challenge", value: codeChallenge),
                URLQueryItem(name: "code_challenge_method", value: "S256"),
                URLQueryItem(name: "access_type", value: "offline"),
                URLQueryItem(name: "prompt", value: "consent")
            ]
            
            guard let url = components.url else {
                self.errorMessage = "Failed to construct OAuth URL"
                return
            }
            
            print("📧 Opening OAuth URL in browser...")
            NSWorkspace.shared.open(url)
        }
    }
    
    @discardableResult
    private func startLocalServer() -> Bool {
        // Stop any existing server first
        stopLocalServer()
        
        do {
            // Try port 3000
            localServer = try NWListener(using: .tcp, on: 3000)
            
            localServer?.newConnectionHandler = { [weak self] connection in
                print("📧 New connection received")
                DispatchQueue.main.async {
                    self?.handleNewConnection(connection)
                }
            }
            
            localServer?.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    print("📧 ✅ Local server is READY on port 3000")
                case .failed(let error):
                    print("📧 ❌ Server failed: \(error)")
                    DispatchQueue.main.async {
                        self?.errorMessage = "Server failed: \(error.localizedDescription)"
                    }
                case .waiting(let error):
                    print("📧 ⏳ Server waiting: \(error)")
                case .cancelled:
                    print("📧 🚫 Server cancelled")
                default:
                    break
                }
            }
            
            localServer?.start(queue: .main)
            print("📧 Local server starting on port 3000...")
            return true
        } catch {
            print("📧 ❌ Failed to start server: \(error)")
            self.errorMessage = "Failed to start local server: \(error.localizedDescription). Please check if port 3000 is already in use."
            return false
        }
    }
    
    private func handleNewConnection(_ connection: NWConnection) {
        connection.start(queue: .main)
        
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, isComplete, error in
            if let data = data, let request = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self?.processHTTPRequest(request, connection: connection)
                }
            }
            
            if isComplete {
                connection.cancel()
            }
        }
    }
    
    private func processHTTPRequest(_ request: String, connection: NWConnection) {
        // Parse the HTTP request to extract the authorization code
        let lines = request.components(separatedBy: "\r\n")
        guard let firstLine = lines.first,
              firstLine.hasPrefix("GET /oauth/callback"),
              let urlPath = firstLine.dropFirst(4).components(separatedBy: " ").first,
              let url = URL(string: "http://localhost:8080" + urlPath) else {
            sendHTTPResponse(connection: connection, statusCode: "400 Bad Request", body: "Invalid request")
            return
        }
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            sendHTTPResponse(connection: connection, statusCode: "400 Bad Request", body: "No query parameters")
            return
        }
        
        let code = queryItems.first { $0.name == "code" }?.value
        let error = queryItems.first { $0.name == "error" }?.value
        
        if let error = error {
            self.errorMessage = "OAuth error: \(error)"
            sendHTTPResponse(connection: connection, statusCode: "400 Bad Request", body: "OAuth error: \(error)")
            stopLocalServer()
            return
        }
        
        guard let code = code else {
            self.errorMessage = "No authorization code received"
            sendHTTPResponse(connection: connection, statusCode: "400 Bad Request", body: "No authorization code received")
            stopLocalServer()
            return
        }
        
        // Send success response to browser
        sendHTTPResponse(connection: connection, statusCode: "200 OK", body: """
        <html>
        <body>
        <h1>Authorization Successful!</h1>
        <p>You can now close this window and return to Diligence.</p>
        </body>
        </html>
        """)
        
        // Stop the server
        stopLocalServer()
        
        // Exchange code for token - call async method directly since we're already on main actor
        exchangeCodeForTokenSync(code: code)
    }
    
    private func sendHTTPResponse(connection: NWConnection, statusCode: String, body: String) {
        let response = """
        HTTP/1.1 \(statusCode)
        Content-Type: text/html
        Content-Length: \(body.count)
        Connection: close
        
        \(body)
        """
        
        let responseData = response.data(using: .utf8)!
        connection.send(content: responseData, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
    
    private func stopLocalServer() {
        if localServer != nil {
            print("📧 Stopping local server...")
        }
        localServer?.cancel()
        localServer = nil
    }
    
    private func generateCodeVerifier() -> String {
        return UUID().uuidString + UUID().uuidString
    }
    
    private func generateCodeChallenge(from verifier: String) -> String {
        guard let data = verifier.data(using: .utf8),
              let hash = data.sha256() else {
            return verifier
        }
        return hash.base64URLEncodedString()
    }
    
    private func exchangeCodeForToken(code: String) async {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyParams = [
            "client_id": clientID,
            "client_secret": clientSecret,
            "code": code,
            "grant_type": "authorization_code",
            "redirect_uri": redirectURI,
            "code_verifier": codeVerifier ?? ""
        ]
        
        let bodyString = bodyParams.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }.joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let tokenResponse = try JSONDecoder().decode(OAuthTokenResponse.self, from: data)
            
            let expiresAt = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
            self.credentials = OAuthCredentials(
                accessToken: tokenResponse.accessToken,
                refreshToken: tokenResponse.refreshToken,
                expiresAt: expiresAt
            )
            
            saveCredentialsToKeychain()
            self.isAuthenticated = true
            self.sessionStatus = .authenticated
            self.errorMessage = nil
            
            // Load emails after successful authentication
            await loadRecentEmails()
            
            // Fetch user profile information
            await fetchUserProfile()
            
        } catch {
            self.errorMessage = "Failed to exchange code for token: \(error.localizedDescription)"
        }
    }
    
    private func exchangeCodeForTokenSync(code: String) {
        URLSession.shared.dataTask(with: createTokenRequest(code: code)) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.handleTokenResponse(data: data, response: response, error: error)
            }
        }.resume()
    }
    
    private func createTokenRequest(code: String) -> URLRequest {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyParams = [
            "client_id": clientID,
            "client_secret": clientSecret,
            "code": code,
            "grant_type": "authorization_code",
            "redirect_uri": redirectURI,
            "code_verifier": codeVerifier ?? ""
        ]
        
        let bodyString = bodyParams.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }.joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)
        
        return request
    }
    
    private func handleTokenResponse(data: Data?, response: URLResponse?, error: Error?) {
        if let error = error {
            self.errorMessage = "Failed to exchange code for token: \(error.localizedDescription)"
            return
        }
        
        guard let data = data else {
            self.errorMessage = "No data received from token exchange"
            return
        }
        
        do {
            let tokenResponse = try JSONDecoder().decode(OAuthTokenResponse.self, from: data)
            
            let expiresAt = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
            self.credentials = OAuthCredentials(
                accessToken: tokenResponse.accessToken,
                refreshToken: tokenResponse.refreshToken,
                expiresAt: expiresAt
            )
            
            saveCredentialsToKeychain()
            self.isAuthenticated = true
            self.sessionStatus = .authenticated
            self.errorMessage = nil
            
            // Load emails after successful authentication
            loadRecentEmailsSync()
            
            // Fetch user profile information (async)
            _Concurrency.Task {
                await fetchUserProfile()
            }
            
        } catch {
            self.errorMessage = "Failed to decode token response: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Token Refresh
    
    private func refreshAccessToken() async -> Bool {
        guard let credentials = credentials,
              let refreshToken = credentials.refreshToken else {
            print("📧 No refresh token available")
            return false
        }
        
        print("📧 Refreshing access token...")
        self.sessionStatus = .refreshing
        
        do {
            var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            
            let bodyParams = [
                "client_id": clientID,
                "client_secret": clientSecret,
                "refresh_token": refreshToken,
                "grant_type": "refresh_token"
            ]
            
            let bodyString = bodyParams.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }.joined(separator: "&")
            request.httpBody = bodyString.data(using: .utf8)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Check for HTTP errors
            if let httpResponse = response as? HTTPURLResponse {
                guard httpResponse.statusCode == 200 else {
                    print("📧 Token refresh failed with status: \(httpResponse.statusCode)")
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("📧 Error response: \(responseString)")
                    }
                    return false
                }
            }
            
            let tokenResponse = try JSONDecoder().decode(OAuthTokenResponse.self, from: data)
            
            let expiresAt = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
            self.credentials = OAuthCredentials(
                accessToken: tokenResponse.accessToken,
                refreshToken: tokenResponse.refreshToken ?? refreshToken, // Use new refresh token if provided, otherwise keep existing
                expiresAt: expiresAt
            )
            
            saveCredentialsToKeychain()
            self.sessionStatus = .authenticated
            print("📧 Access token refreshed successfully")
            return true
            
        } catch {
            print("📧 Token refresh error: \(error)")
            self.sessionStatus = .expired
            return false
        }
    }
    
    // MARK: - Session Management
    
    @MainActor
    func validateAndRefreshSession() async {
        guard let credentials = credentials else {
            if isAuthenticated {
                print("📧 No credentials found, marking as not authenticated")
                isAuthenticated = false
                clearEmailCache()
            }
            return
        }
        
        // Check if token is expired or will expire soon
        if credentials.expiresAt <= Date().addingTimeInterval(600) { // Refresh if expires within 10 minutes
            print("📧 Token expired or expiring soon, attempting refresh...")
            
            let refreshSuccess = await refreshAccessToken()
            
            if !refreshSuccess {
                print("📧 Token refresh failed, user needs to re-authenticate")
                isAuthenticated = false
                sessionStatus = .expired
                clearEmailCache()
                errorMessage = "Session expired. Please sign in again."
            } else {
                print("📧 Session refreshed successfully")
                sessionStatus = .authenticated
                errorMessage = nil
            }
        } else {
            print("📧 Session is still valid")
        }
    }
    
    // MARK: - User Profile
    
    private func fetchUserProfile() async {
        guard let credentials = credentials else {
            return
        }
        
        let profileURL = URL(string: "https://www.googleapis.com/oauth2/v2/userinfo")!
        var request = URLRequest(url: profileURL)
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let email = json["email"] as? String {
                    await MainActor.run {
                        self.userEmail = email
                    }
                }
            }
        } catch {
            print("📧 Failed to fetch user profile: \(error)")
        }
    }
    
    // MARK: - Email Loading
    
    private func loadRecentEmailsSync() {
        guard let credentials = credentials else {
            self.errorMessage = "Not authenticated"
            return
        }
        
        self.isLoading = true
        
        let messageListURL = URL(string: "\(baseURL)/users/me/messages?maxResults=50&q=in:inbox")!
        var request = URLRequest(url: messageListURL)
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Failed to load emails: \(error.localizedDescription)"
                    return
                }
                
                guard let data = data else {
                    self?.errorMessage = "No data received"
                    return
                }
                
                do {
                    let messagesResponse = try JSONDecoder().decode(GmailMessagesResponse.self, from: data)
                    
                    guard messagesResponse.messages != nil else {
                        self?.emails = []
                        return
                    }
                    
                    // For now, just set empty emails array to show authentication worked
                    // TODO: Implement async email detail fetching
                    self?.emails = []
                    
                } catch {
                    self?.errorMessage = "Failed to decode messages: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
    
    func loadRecentEmails(maxResults: Int = 50, forceRefresh: Bool = false) async {
        guard var credentials = credentials else {
            self.errorMessage = "Not authenticated"
            return
        }
        
        // Check network connectivity first
        guard await checkNetworkConnectivity() else {
            self.errorMessage = "Unable to connect to Gmail servers. Please check your internet connection."
            return
        }
        
        // Check if token needs refresh
        if credentials.expiresAt <= Date().addingTimeInterval(300) { // Refresh if expires within 5 minutes
            print("📧 Access token expired or expiring soon, attempting refresh...")
            
            guard await refreshAccessToken() else {
                self.errorMessage = "Session expired. Please sign in again."
                self.isAuthenticated = false
                clearEmailCache()
                return
            }
            
            // Update credentials reference after refresh
            guard let refreshedCredentials = self.credentials else {
                self.errorMessage = "Failed to refresh token"
                self.isAuthenticated = false
                return
            }
            credentials = refreshedCredentials
        }
        
        // Check if we should skip API call if cache is fresh and we have emails
        if !forceRefresh && !emails.isEmpty {
            let cacheTimestamp = UserDefaults.standard.double(forKey: cacheTimestampKey)
            let cacheDate = Date(timeIntervalSince1970: cacheTimestamp)
            let cacheAge = Date().timeIntervalSince(cacheDate)
            
            if cacheAge < 900 { // Less than 15 minutes old
                print("📧 Using fresh cached emails (age: \(Int(cacheAge/60)) minutes)")
                return
            }
        }

        self.isLoading = true
        defer { self.isLoading = false }
        
        do {
            // First, get the list of message IDs
            let messageListURL = URL(string: "\(baseURL)/users/me/messages?maxResults=\(maxResults)&q=in:inbox")!
            var request = URLRequest(url: messageListURL)
            request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 30.0 // Set explicit timeout
            
            print("📧 Making Gmail API request to: \(messageListURL)")
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Check for authentication errors
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 401 {
                    print("📧 Authentication failed, attempting token refresh...")
                    guard await refreshAccessToken(),
                          let refreshedCredentials = self.credentials else {
                        self.isAuthenticated = false
                        self.sessionStatus = .expired
                        self.errorMessage = "Session expired. Please sign in again."
                        clearEmailCache()
                        return
                    }
                    
                    // Retry the request with refreshed token
                    request.setValue("Bearer \(refreshedCredentials.accessToken)", forHTTPHeaderField: "Authorization")
                    let (retryData, _) = try await URLSession.shared.data(for: request)
                    let messagesResponse = try JSONDecoder().decode(GmailMessagesResponse.self, from: retryData)
                    
                    guard let messageRefs = messagesResponse.messages else {
                        self.emails = []
                        return
                    }
                    
                    // Fetch detailed information for each message
                    var processedEmails: [ProcessedEmail] = []
                    
                    for messageRef in messageRefs.prefix(maxResults) {
                        if let email = await fetchEmailDetails(messageId: messageRef.id) {
                            processedEmails.append(email)
                        }
                    }
                    
                    self.emails = processedEmails
                        .filter { !removedEmailIds.contains($0.id) } // Filter out blacklisted emails
                        .sorted { $0.receivedDate > $1.receivedDate }
                    
                    // Save emails to cache after loading
                    saveEmailsToCache(processedEmails)
                    
                    return
                }
            }
            
            let messagesResponse = try JSONDecoder().decode(GmailMessagesResponse.self, from: data)
            
            guard let messageRefs = messagesResponse.messages else {
                self.emails = []
                return
            }
            
            // Fetch detailed information for each message
            var processedEmails: [ProcessedEmail] = []
            
            for messageRef in messageRefs.prefix(maxResults) {
                if let email = await fetchEmailDetails(messageId: messageRef.id) {
                    processedEmails.append(email)
                }
            }
            
            self.emails = processedEmails
                .filter { !removedEmailIds.contains($0.id) } // Filter out blacklisted emails
                .sorted { $0.receivedDate > $1.receivedDate }
            
            // Save emails to cache after loading
            saveEmailsToCache(processedEmails)
            
        } catch {
            self.errorMessage = "Failed to load emails: \(error.localizedDescription)"
        }
    }
    
    private func fetchEmailDetails(messageId: String) async -> ProcessedEmail? {
        guard var credentials = credentials else { return nil }
        
        // Check if token needs refresh before making API call
        if credentials.expiresAt <= Date().addingTimeInterval(300) { // Refresh if expires within 5 minutes
            guard await refreshAccessToken() else {
                return nil
            }
            // Update credentials reference after refresh
            guard let refreshedCredentials = self.credentials else { return nil }
            credentials = refreshedCredentials
        }
        
        let messageURL = URL(string: "\(baseURL)/users/me/messages/\(messageId)")!
        var request = URLRequest(url: messageURL)
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30.0 // Set explicit timeout
        
        do {
            print("📧 Fetching email details for message: \(messageId)")
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Check for authentication errors
            if let httpResponse = response as? HTTPURLResponse {
                print("📧 Email details response: HTTP \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 401 {
                    print("📧 Authentication failed for message \(messageId), attempting token refresh...")
                    guard await refreshAccessToken(),
                          let refreshedCredentials = self.credentials else {
                        return nil
                    }
                    
                    // Retry the request with refreshed token
                    request.setValue("Bearer \(refreshedCredentials.accessToken)", forHTTPHeaderField: "Authorization")
                    let (retryData, _) = try await URLSession.shared.data(for: request)
                    let message = try JSONDecoder().decode(GmailMessage.self, from: retryData)
                    return processGmailMessage(message)
                }
                
                // Check for other HTTP errors
                if httpResponse.statusCode >= 400 {
                    print("📧 HTTP error \(httpResponse.statusCode) for message \(messageId)")
                    return nil
                }
            }
            
            let message = try JSONDecoder().decode(GmailMessage.self, from: data)
            return processGmailMessage(message)
        } catch {
            print("📧 Failed to fetch email details for \(messageId): \(error)")
            
            // Provide specific error information
            if let urlError = error as? URLError {
                switch urlError.code {
                case .cannotFindHost:
                    print("📧 Cannot find Gmail server host - check DNS settings")
                case .cannotConnectToHost:
                    print("📧 Cannot connect to Gmail servers - check firewall/proxy")
                case .timedOut:
                    print("📧 Request timed out - slow connection or server issues")
                case .notConnectedToInternet:
                    print("📧 No internet connection")
                default:
                    print("📧 Network error: \(urlError.localizedDescription)")
                }
            }
            
            return nil
        }
    }
    
    private func processGmailMessage(_ message: GmailMessage) -> ProcessedEmail? {
        guard let headers = message.payload?.headers else { return nil }
        
        let subject = headers.first { $0.name.lowercased() == "subject" }?.value ?? "No Subject"
        let fromHeader = headers.first { $0.name.lowercased() == "from" }?.value ?? "Unknown Sender"
        let dateHeader = headers.first { $0.name.lowercased() == "date" }?.value
        
        // Parse sender name and email
        let (senderName, senderEmail) = parseSenderInfo(fromHeader)
        
        // Parse date with fallback to Gmail's internal date
        let receivedDate = parseEmailDate(dateHeader) ?? 
                          parseGmailInternalDate(message.internalDate) ?? 
                          Date()
        
        // Extract body
        let body = extractEmailBody(from: message.payload) ?? message.snippet ?? ""
        
        // Create Gmail URL
        let gmailURL = URL(string: "https://mail.google.com/mail/u/0/#inbox/\(message.id)")!
        
        return ProcessedEmail(
            id: message.id,
            threadId: message.threadId,
            subject: subject,
            sender: senderName,
            senderEmail: senderEmail,
            body: body,
            snippet: message.snippet ?? "",
            receivedDate: receivedDate,
            gmailURL: gmailURL,
            attachments: extractAttachments(from: message.payload, messageId: message.id)
        )
    }
    
    // MARK: - Email Caching
    
    private func loadEmailsFromCache() {
        guard let cachedData = UserDefaults.standard.data(forKey: emailCacheKey),
              let cachedEmails = try? JSONDecoder().decode([ProcessedEmail].self, from: cachedData) else {
            print("📧 No cached emails found")
            return
        }
        
        // Check cache age - refresh if older than 15 minutes
        let cacheTimestamp = UserDefaults.standard.double(forKey: cacheTimestampKey)
        let cacheDate = Date(timeIntervalSince1970: cacheTimestamp)
        let cacheAge = Date().timeIntervalSince(cacheDate)
        
        if cacheAge > 900 { // 15 minutes = 900 seconds
            print("📧 Email cache is too old (\(Int(cacheAge/60)) minutes), will refresh")
            // Don't return early, still load cached emails for immediate display
        }
        
        // Filter out blacklisted emails and load into emails array
        let filteredEmails = cachedEmails
            .filter { !removedEmailIds.contains($0.id) }
            .sorted { $0.receivedDate > $1.receivedDate }
        
        self.emails = filteredEmails
        print("📧 Loaded \(filteredEmails.count) emails from cache")
    }
    
    private func saveEmailsToCache(_ emails: [ProcessedEmail]) {
        guard let encodedData = try? JSONEncoder().encode(emails) else {
            print("📧 Failed to encode emails for caching")
            return
        }
        
        UserDefaults.standard.set(encodedData, forKey: emailCacheKey)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: cacheTimestampKey)
        
        print("📧 Saved \(emails.count) emails to cache")
    }
    
    private func clearEmailCache() {
        UserDefaults.standard.removeObject(forKey: emailCacheKey)
        UserDefaults.standard.removeObject(forKey: cacheTimestampKey)
        print("📧 Cleared email cache")
    }
    
    // MARK: - Network Connectivity
    
    private func checkNetworkConnectivity() async -> Bool {
        do {
            // Test connectivity to Gmail API
            let testURL = URL(string: "https://www.googleapis.com/gmail/v1")!
            var request = URLRequest(url: testURL)
            request.httpMethod = "HEAD"
            request.timeoutInterval = 10.0
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                // Any HTTP response (even 401/403) means we can reach the server
                print("📧 Network connectivity check: HTTP \(httpResponse.statusCode)")
                return true
            }
            
            return false
        } catch {
            print("📧 Network connectivity check failed: \(error)")
            
            // Check for specific network errors
            if let urlError = error as? URLError {
                switch urlError.code {
                case .notConnectedToInternet:
                    print("📧 No internet connection")
                case .cannotFindHost, .cannotConnectToHost:
                    print("📧 Cannot reach Gmail servers - DNS or connectivity issue")
                case .timedOut:
                    print("📧 Request timed out")
                case .networkConnectionLost:
                    print("📧 Network connection lost")
                default:
                    print("📧 Network error: \(urlError.localizedDescription)")
                }
            }
            
            return false
        }
    }
    
    // MARK: - Helper Methods
    
    private func parseSenderInfo(_ fromHeader: String) -> (name: String, email: String) {
        // Parse "Name <email@domain.com>" format
        let emailPattern = #"<([^>]+)>"#
        let namePattern = #"^([^<]+)"#
        
        let emailRegex = try? NSRegularExpression(pattern: emailPattern)
        let nameRegex = try? NSRegularExpression(pattern: namePattern)
        
        let emailMatch = emailRegex?.firstMatch(in: fromHeader, range: NSRange(fromHeader.startIndex..., in: fromHeader))
        let nameMatch = nameRegex?.firstMatch(in: fromHeader, range: NSRange(fromHeader.startIndex..., in: fromHeader))
        
        let email = emailMatch.flatMap { Range($0.range(at: 1), in: fromHeader) }.map { String(fromHeader[$0]) } ?? fromHeader
        let name = nameMatch.flatMap { Range($0.range(at: 1), in: fromHeader) }.map { String(fromHeader[$0]).trimmingCharacters(in: .whitespacesAndNewlines) } ?? email
        
        return (name, email)
    }
    
    private func parseEmailDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        
        // Common email date formats to try
        let dateFormats = [
            "EEE, d MMM yyyy HH:mm:ss Z",        // RFC 2822: "Mon, 02 Jan 2006 15:04:05 -0700"
            "EEE, dd MMM yyyy HH:mm:ss Z",       // With zero-padded day
            "d MMM yyyy HH:mm:ss Z",             // Without day of week
            "dd MMM yyyy HH:mm:ss Z",            // Without day of week, zero-padded day
            "EEE, d MMM yyyy HH:mm:ss zzz",      // With timezone name
            "EEE, dd MMM yyyy HH:mm:ss zzz",     // With timezone name, zero-padded
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",       // ISO 8601 with milliseconds
            "yyyy-MM-dd'T'HH:mm:ssZ",           // ISO 8601 basic
            "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",     // ISO 8601 with milliseconds, literal Z
            "yyyy-MM-dd'T'HH:mm:ss'Z'",         // ISO 8601 basic, literal Z
            "yyyy-MM-dd HH:mm:ss Z",            // Date time with timezone
            "yyyy-MM-dd HH:mm:ss"               // Simple date time
        ]
        
        for format in dateFormats {
            formatter.dateFormat = format
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        
        // If all formats fail, try to extract just the date part and parse again
        let trimmedDate = dateString.trimmingCharacters(in: .whitespacesAndNewlines)
        for format in dateFormats {
            formatter.dateFormat = format
            if let date = formatter.date(from: trimmedDate) {
                return date
            }
        }
        
        print("⚠️ Failed to parse email date: \(dateString)")
        return nil
    }
    
    private func parseGmailInternalDate(_ internalDateString: String?) -> Date? {
        guard let internalDateString = internalDateString else { return nil }
        
        // Gmail's internalDate is in milliseconds since epoch
        guard let timestamp = Int64(internalDateString) else { return nil }
        
        return Date(timeIntervalSince1970: Double(timestamp) / 1000.0)
    }
    
    private func extractEmailBody(from payload: GmailPayload?) -> String? {
        guard let payload = payload else { return nil }
        
        // Handle multipart emails properly
        if let parts = payload.parts, !parts.isEmpty {
            // Look for the best body part in order of preference
            
            // 1. First try to find text/html in multipart/alternative
            for part in parts {
                if part.mimeType == "multipart/alternative" || part.mimeType == "multipart/mixed" {
                    if let nestedBody = extractEmailBody(from: part) {
                        return nestedBody
                    }
                }
            }
            
            // 2. Look for text/html directly
            for part in parts {
                if part.mimeType == "text/html", let bodyData = part.body?.data {
                    return decodeBase64URLString(bodyData)
                }
            }
            
            // 3. Look for text/plain as fallback
            for part in parts {
                if part.mimeType == "text/plain", let bodyData = part.body?.data {
                    return decodeBase64URLString(bodyData)
                }
            }
            
            // 4. Recursively search nested parts
            for part in parts {
                if let nestedBody = extractEmailBody(from: part) {
                    return nestedBody
                }
            }
        }
        
        // Handle single-part emails
        if let mimeType = payload.mimeType, let bodyData = payload.body?.data {
            if mimeType == "text/html" || mimeType == "text/plain" {
                return decodeBase64URLString(bodyData)
            }
        }
        
        return nil
    }
    
    private func findBodyPart(_ payload: GmailPayload, mimeType: String) -> String? {
        if payload.mimeType == mimeType, let bodyData = payload.body?.data {
            return decodeBase64URLString(bodyData)
        }
        
        if let parts = payload.parts {
            for part in parts {
                if let body = findBodyPart(part, mimeType: mimeType) {
                    return body
                }
            }
        }
        
        return nil
    }
    
    private func decodeBase64URLString(_ base64URLString: String) -> String? {
        var base64 = base64URLString
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        // Add padding if necessary
        while base64.count % 4 != 0 {
            base64 += "="
        }
        
        guard let data = Data(base64Encoded: base64),
              let decodedString = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        // Filter out email headers and raw email data
        let cleanedString = cleanEmailContent(decodedString)
        
        return cleanedString.isEmpty ? nil : cleanedString
    }
    
    private func cleanEmailContent(_ content: String) -> String {
        let lines = content.components(separatedBy: .newlines)
        var cleanLines: [String] = []
        var inHeaders = true
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip email headers (lines that look like "Header: Value")
            if inHeaders {
                // Check if this looks like an email header
                if trimmedLine.isEmpty {
                    inHeaders = false
                    continue
                }
                
                // Skip lines that look like email headers
                if trimmedLine.contains(":") && (
                    trimmedLine.hasPrefix("Delivered-To:") ||
                    trimmedLine.hasPrefix("Received:") ||
                    trimmedLine.hasPrefix("Return-Path:") ||
                    trimmedLine.hasPrefix("X-") ||
                    trimmedLine.hasPrefix("DKIM-") ||
                    trimmedLine.hasPrefix("ARC-") ||
                    trimmedLine.hasPrefix("Authentication-Results:") ||
                    trimmedLine.hasPrefix("MIME-Version:") ||
                    trimmedLine.hasPrefix("Content-Type:") ||
                    trimmedLine.hasPrefix("Content-Transfer-Encoding:") ||
                    trimmedLine.hasPrefix("References:") ||
                    trimmedLine.hasPrefix("In-Reply-To:") ||
                    trimmedLine.hasPrefix("Message-ID:") ||
                    trimmedLine.starts(with: "        ") // Continued header lines
                ) {
                    continue
                }
                
                // If we find content that doesn't look like a header, we're past headers
                if !trimmedLine.contains(":") || trimmedLine.count > 200 {
                    inHeaders = false
                }
            }
            
            // Skip MIME boundary markers
            if trimmedLine.hasPrefix("--") && trimmedLine.count > 10 {
                continue
            }
            
            // Skip Content-Type declarations within MIME parts
            if trimmedLine.hasPrefix("Content-Type:") || 
               trimmedLine.hasPrefix("Content-Transfer-Encoding:") {
                continue
            }
            
            // If we're past headers and this isn't a boundary, include the line
            if !inHeaders {
                cleanLines.append(line)
            }
        }
        
        let result = cleanLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If result is still very long and looks like raw email data, return empty
        if result.count > 10000 && result.contains("Content-Type:") {
            return ""
        }
        
        return result
    }
    
    private func stripHTMLTags(_ html: String) -> String {
        return html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }
    
    // MARK: - Keychain Management
    
    private func saveCredentialsToKeychain() {
        guard let credentials = credentials else { return }
        
        let credentialsData = try? JSONEncoder().encode([
            "accessToken": credentials.accessToken,
            "refreshToken": credentials.refreshToken ?? "",
            "expiresAt": String(credentials.expiresAt.timeIntervalSince1970)
        ])
        
        guard let data = credentialsData else { return }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "gmail",
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    private func loadCredentialsFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "gmail",
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let dict = try? JSONDecoder().decode([String: String].self, from: data),
              let accessToken = dict["accessToken"],
              let expiresAtString = dict["expiresAt"],
              let expiresAtInterval = Double(expiresAtString) else {
            return
        }
        
        let expiresAt = Date(timeIntervalSince1970: expiresAtInterval)
        let refreshToken = dict["refreshToken"]?.isEmpty == false ? dict["refreshToken"] : nil
        
        // Load credentials even if expired, as long as we have a refresh token
        if expiresAt > Date() || refreshToken != nil {
            self.credentials = OAuthCredentials(
                accessToken: accessToken,
                refreshToken: refreshToken,
                expiresAt: expiresAt
            )
            
            self.isAuthenticated = true
            
            // If token is expired but we have refresh token, log this state
            if expiresAt <= Date() && refreshToken != nil {
                print("📧 Loaded expired credentials, will refresh on next API call")
                sessionStatus = .expired
            } else {
                print("📧 Loaded valid credentials from keychain")
                sessionStatus = .authenticated
            }
        } else {
            print("📧 No valid credentials or refresh token found")
        }
    }
    
    // MARK: - Attachment Functions
    
    private func extractAttachments(from payload: GmailPayload?, messageId: String) -> [EmailAttachment] {
        guard let payload = payload else { return [] }
        
        var attachments: [EmailAttachment] = []
        
        // Check current payload for attachments
        if let filename = payload.filename, 
           !filename.isEmpty,
           let attachmentId = payload.body?.attachmentId,
           let size = payload.body?.size {
            
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
    
    @MainActor
    func downloadAttachment(_ attachment: EmailAttachment) async -> URL? {
        guard var credentials = credentials else { return nil }
        
        // Check if token needs refresh before making API call
        if credentials.expiresAt <= Date().addingTimeInterval(300) { // Refresh if expires within 5 minutes
            guard await refreshAccessToken() else {
                return nil
            }
            // Update credentials reference after refresh
            guard let refreshedCredentials = self.credentials else { return nil }
            credentials = refreshedCredentials
        }
        
        let attachmentURL = URL(string: "\(baseURL)/users/me/messages/\(attachment.messageId)/attachments/\(attachment.id)")!
        var request = URLRequest(url: attachmentURL)
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Check for authentication errors
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 401 {
                    print("📧 Authentication failed for attachment download, attempting token refresh...")
                    guard await refreshAccessToken(),
                          let refreshedCredentials = self.credentials else {
                        return nil
                    }
                    
                    // Retry the request with refreshed token
                    request.setValue("Bearer \(refreshedCredentials.accessToken)", forHTTPHeaderField: "Authorization")
                    let (retryData, _) = try await URLSession.shared.data(for: request)
                    
                    // Continue with original processing logic using retryData
                    let attachmentResponse = try JSONDecoder().decode(AttachmentResponse.self, from: retryData)
                    
                    // Decode the base64url encoded data
                    guard let decodedData = decodeBase64URLData(attachmentResponse.data) else {
                        print("Failed to decode attachment data")
                        return nil
                    }
                    
                    // Create a temporary file
                    let tempDirectory = FileManager.default.temporaryDirectory
                    let tempFile = tempDirectory.appendingPathComponent(attachment.filename)
                    
                    // Write the data to the temporary file
                    try decodedData.write(to: tempFile)
                    
                    return tempFile
                }
            }
            
            // Parse the response to get the actual attachment data
            struct AttachmentResponse: Codable {
                let size: Int
                let data: String
            }
            
            let attachmentResponse = try JSONDecoder().decode(AttachmentResponse.self, from: data)
            
            // Decode the base64url encoded data
            guard let decodedData = decodeBase64URLData(attachmentResponse.data) else {
                print("Failed to decode attachment data")
                return nil
            }
            
            // Create a temporary file
            let tempDirectory = FileManager.default.temporaryDirectory
            let tempFile = tempDirectory.appendingPathComponent(attachment.filename)
            
            // Write the data to the temporary file
            try decodedData.write(to: tempFile)
            
            return tempFile
            
        } catch {
            print("Failed to download attachment: \(error)")
            return nil
        }
    }
    
    private func decodeBase64URLData(_ base64URLString: String) -> Data? {
        // Convert base64url to base64
        var base64 = base64URLString
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        // Add padding if needed
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        
        return Data(base64Encoded: base64)
    }
    
    // MARK: - Diagnostics
    
    @MainActor
    func runConnectivityDiagnostics() async -> String {
        var diagnostics = "📧 Gmail Service Connectivity Diagnostics\n\n"
        
        // 1. Check internet connectivity
        diagnostics += "1. Internet Connectivity:\n"
        do {
            let testURL = URL(string: "https://www.google.com")!
            var request = URLRequest(url: testURL)
            request.httpMethod = "HEAD"
            request.timeoutInterval = 10.0
            
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                diagnostics += "   ✅ Can reach google.com (HTTP \(httpResponse.statusCode))\n"
            }
        } catch {
            diagnostics += "   ❌ Cannot reach google.com: \(error.localizedDescription)\n"
        }
        
        // 2. Check Gmail API endpoint
        diagnostics += "\n2. Gmail API Endpoint:\n"
        do {
            let apiURL = URL(string: "https://www.googleapis.com/gmail/v1")!
            var request = URLRequest(url: apiURL)
            request.httpMethod = "HEAD"
            request.timeoutInterval = 10.0
            
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                diagnostics += "   ✅ Can reach Gmail API (HTTP \(httpResponse.statusCode))\n"
            }
        } catch {
            diagnostics += "   ❌ Cannot reach Gmail API: \(error.localizedDescription)\n"
        }
        
        // 3. Check OAuth endpoint
        diagnostics += "\n3. OAuth Endpoint:\n"
        do {
            let oauthURL = URL(string: "https://oauth2.googleapis.com/token")!
            var request = URLRequest(url: oauthURL)
            request.httpMethod = "HEAD"
            request.timeoutInterval = 10.0
            
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                diagnostics += "   ✅ Can reach OAuth endpoint (HTTP \(httpResponse.statusCode))\n"
            }
        } catch {
            diagnostics += "   ❌ Cannot reach OAuth endpoint: \(error.localizedDescription)\n"
        }
        
        // 4. Check authentication status
        diagnostics += "\n4. Authentication Status:\n"
        diagnostics += "   Authentication: \(isAuthenticated ? "✅ Authenticated" : "❌ Not authenticated")\n"
        diagnostics += "   Session: \(sessionStatus)\n"
        
        if let credentials = credentials {
            let tokenValid = credentials.expiresAt > Date()
            diagnostics += "   Token: \(tokenValid ? "✅ Valid" : "❌ Expired")\n"
            diagnostics += "   Expires: \(credentials.expiresAt)\n"
            diagnostics += "   Has Refresh Token: \(credentials.refreshToken != nil ? "✅ Yes" : "❌ No")\n"
        } else {
            diagnostics += "   Token: ❌ No credentials found\n"
        }
        
        // 5. Check configuration
        diagnostics += "\n5. Configuration:\n"
        diagnostics += "   Client ID: \(clientID.isEmpty ? "❌ Empty" : "✅ Set")\n"
        diagnostics += "   Client Secret: \(clientSecret.isEmpty ? "❌ Empty" : "✅ Set")\n"
        diagnostics += "   Redirect URI: \(redirectURI)\n"
        
        // 6. Check cached emails
        diagnostics += "\n6. Email Cache:\n"
        diagnostics += "   Cached emails: \(emails.count)\n"
        
        let cacheTimestamp = UserDefaults.standard.double(forKey: cacheTimestampKey)
        if cacheTimestamp > 0 {
            let cacheDate = Date(timeIntervalSince1970: cacheTimestamp)
            let cacheAge = Date().timeIntervalSince(cacheDate)
            diagnostics += "   Cache age: \(Int(cacheAge/60)) minutes\n"
        } else {
            diagnostics += "   Cache: No cached data\n"
        }
        
        return diagnostics
    }
    
    @MainActor
    func signOut() {
        // Clear credentials from keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "gmail"
        ]
        SecItemDelete(query as CFDictionary)
        
        // Clear in-memory state
        credentials = nil
        isAuthenticated = false
        sessionStatus = .notAuthenticated
        emails = []
        userEmail = nil
        errorMessage = nil
        
        // Clear cached data
        clearEmailCache()
        
        print("📧 User signed out and all data cleared")
    }
    
    @MainActor
    func removeEmailFromList(_ email: ProcessedEmail) {
        // Add email ID to blacklist for persistent removal
        var blacklist = removedEmailIds
        blacklist.insert(email.id)
        removedEmailIds = blacklist
        
        // Remove from current list
        emails.removeAll { $0.id == email.id }
        print("Permanently removed email from Diligence: \(email.subject)")
    }
    
    @MainActor
    func removeBatchEmailsFromList(_ emailsToRemove: [ProcessedEmail]) {
        print("🗑️ Service: removeBatchEmailsFromList called with \(emailsToRemove.count) emails")
        print("🗑️ Service: Email count before removal: \(emails.count)")
        
        // Add all email IDs to blacklist for persistent removal
        var blacklist = removedEmailIds
        for email in emailsToRemove {
            blacklist.insert(email.id)
            print("🗑️ Service: Adding to blacklist: \(email.subject)")
        }
        removedEmailIds = blacklist
        
        // Remove all emails from current list in one operation
        let idsToRemove = Set(emailsToRemove.map { $0.id })
        emails.removeAll { idsToRemove.contains($0.id) }
        
        print("🗑️ Service: Email count after removal: \(emails.count)")
        print("🗑️ Service: Permanently removed \(emailsToRemove.count) emails from Diligence")
    }
    
    @MainActor
    func clearRemovedEmailsList() {
        // Clear the blacklist (for settings or reset functionality)
        removedEmailIds = Set<String>()
        print("Cleared removed emails blacklist")
    }
    
    @MainActor
    func getRemovedEmailsCount() -> Int {
        return removedEmailIds.count
    }
}

// MARK: - Data Extensions

extension Data {
    func sha256() -> Data? {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        self.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(self.count), &hash)
        }
        return Data(hash)
    }
    
    func base64URLEncodedString() -> String {
        return self.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

