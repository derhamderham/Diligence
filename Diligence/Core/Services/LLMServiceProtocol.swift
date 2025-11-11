//
//  LLMServiceProtocol.swift
//  Diligence
//
//  Created by Assistant on 11/10/25.
//

import Foundation

/// Protocol defining the contract for LLM service implementations
///
/// LLM services provide natural language query capabilities for
/// analyzing and searching through emails using large language models.
///
/// ## Topics
///
/// ### Initialization
/// - ``initialize()``
/// - ``detectAndSetCurrentModel()``
///
/// ### Querying
/// - ``queryEmails(query:emails:)``
///
/// ### Service Management
/// - ``checkServiceAvailability(autoDetectModel:)``
/// - ``setModel(_:)``
/// - ``getAvailableModels()``
/// - ``getAvailableModelsFromServer()``
/// - ``getRunningModels()``
/// - ``isModelRunning(_:)``
/// - ``refreshCurrentModel()``
///
/// ### Configuration
/// - ``getCurrentConfiguration()``
/// - ``forceIPv4Connection()``
@MainActor
protocol LLMServiceProtocol: AnyObject {
    
    // MARK: - Initialization
    
    /// Initialize the LLM service and detect current model if enabled
    func initialize() async
    
    /// Detect the current model from the LLM server and update settings
    func detectAndSetCurrentModel() async
    
    // MARK: - Querying
    
    /// Query emails using the local LLM
    /// - Parameters:
    ///   - query: User's natural language query
    ///   - emails: Array of emails to analyze
    /// - Returns: LLM's response as a string
    /// - Throws: Error if the query fails
    func queryEmails(query: String, emails: [ProcessedEmail]) async throws -> String
    
    // MARK: - Service Management
    
    /// Check if the LLM service is available and optionally update model
    /// - Parameter autoDetectModel: Whether to automatically detect and update the current model
    /// - Returns: `true` if the service is available and responding
    func checkServiceAvailability(autoDetectModel: Bool) async -> Bool
    
    /// Set the model name to use
    /// - Parameter model: The model identifier to use for queries
    func setModel(_ model: String)
    
    /// Get available models from local configuration
    /// - Returns: Array of model identifiers
    func getAvailableModels() -> [String]
    
    /// Get available models from the LLM server
    /// - Returns: Array of model identifiers available on the server
    func getAvailableModelsFromServer() async -> [String]
    
    /// Get currently running/loaded models from the server
    /// - Returns: Array of model identifiers that are currently loaded
    func getRunningModels() async -> [String]
    
    /// Check if a specific model is currently loaded/running
    /// - Parameter modelId: The model identifier to check
    /// - Returns: `true` if the model is currently running
    func isModelRunning(_ modelId: String) async -> Bool
    
    /// Manually refresh the current model detection
    /// - Returns: The detected model identifier, if any
    func refreshCurrentModel() async -> String?
    
    /// Force connection to use IPv4 (127.0.0.1) instead of localhost
    func forceIPv4Connection()
    
    // MARK: - Configuration
    
    /// Get current configuration for debugging
    /// - Returns: Dictionary containing current configuration values
    func getCurrentConfiguration() -> [String: Any]
}
