//
//  DependencyContainer.swift
//  Diligence
//
//  Created by derham on 11/10/25.
//

import SwiftUI
import SwiftData
import Combine

@MainActor
class DependencyContainer: ObservableObject {
    static let shared = DependencyContainer()
    
    private(set) var recurringTaskService: RecurringTaskService!
    private(set) var llmService: LLMService!
    
    private init() {}
    
    func configure(modelContext: ModelContext) {
        self.recurringTaskService = RecurringTaskService(modelContext: modelContext)
        self.llmService = LLMService()
    }
}

// MARK: - Environment Key

struct DependencyContainerKey: EnvironmentKey {
    static let defaultValue: DependencyContainer = DependencyContainer.shared
}

extension EnvironmentValues {
    var dependencyContainer: DependencyContainer {
        get { self[DependencyContainerKey.self] }
        set { self[DependencyContainerKey.self] = newValue }
    }
}
