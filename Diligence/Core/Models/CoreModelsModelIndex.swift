//
//  ModelIndex.swift
//  Diligence
//
//  Quick reference index for all data models in Core/Models/
//  This file serves as documentation only - do not include in build targets
//

/*

# Diligence Data Models Reference

## Task Models (Core/Models/Task/)

### DiligenceTask
- **File**: Task.swift
- **Purpose**: Primary task model with recurring task support
- **Key Features**:
  - Basic task properties (title, description, completion)
  - Due dates and scheduling
  - Gmail integration (emailID, gmailURL)
  - Apple Reminders sync (reminderID)
  - Section organization (sectionID)
  - Financial tracking (amount)
  - Recurring task patterns
- **Relationships**:
  - Belongs to: TaskSection (via sectionID)
  - Parent of: Recurring instances (via parentRecurringTaskID)

### TaskSection
- **File**: TaskSection.swift
- **Purpose**: Organizes tasks into logical groups
- **Key Features**:
  - Unique ID for persistence
  - Display name and sort order
  - Reminders list sync (reminderID)
- **Relationships**:
  - Has many: DiligenceTask (one-to-many)

### RecurrencePattern (enum)
- **File**: RecurrenceModels.swift
- **Purpose**: Defines task repetition frequency
- **Cases**:
  - .never - No repetition
  - .daily - Every day
  - .weekdays - Monday through Friday
  - .weekly - Specific day(s) of the week
  - .biweekly - Every two weeks
  - .monthly - Same day each month
  - .yearly - Same date each year
  - .custom - User-defined pattern

### RecurrenceEndType (enum)
- **File**: RecurrenceModels.swift
- **Purpose**: Defines when recurrence stops
- **Cases**:
  - .never - Continues indefinitely
  - .afterCount - Stops after N occurrences
  - .onDate - Stops on specific date

---

## Email Models (Core/Models/Email/)

### ProcessedEmail
- **File**: ProcessedEmail.swift
- **Purpose**: Simplified email for UI display and task creation
- **Key Features**:
  - Parsed subject, sender, body
  - Attachment tracking
  - Gmail deep link URL
  - Factory method: `from(_:)` converts GmailMessage
- **Usage**:
  ```swift
  if let processed = ProcessedEmail.from(gmailMessage) {
      // Use for display or task creation
  }
  ```

### GmailMessage
- **File**: GmailModels.swift
- **Purpose**: Raw Gmail API response
- **Key Features**:
  - Complete Gmail message structure
  - Headers, body, attachments
  - MIME multipart handling
- **Note**: Use ProcessedEmail for most UI needs

### EmailAttachment
- **File**: GmailModels.swift
- **Purpose**: Represents email attachments
- **Key Features**:
  - Filename and MIME type
  - Size tracking
  - Type detection (isImage, isDocument)
  - SF Symbol icon selection

### GmailMessagesResponse
- **File**: GmailModels.swift
- **Purpose**: API response for message list
- **Key Features**:
  - Array of message references
  - Pagination support (nextPageToken)

### OAuthCredentials
- **File**: GmailModels.swift
- **Purpose**: Gmail authentication state
- **Key Features**:
  - Access and refresh tokens
  - Expiration tracking

---

## AI Models (Core/Models/AI/)

### AIProvider (enum)
- **File**: AIModels.swift
- **Purpose**: Available AI service providers
- **Cases**:
  - .appleIntelligence - On-device Apple Intelligence
  - .janAI - Local Jan.ai LLM server
- **Properties**:
  - displayName: Human-readable name
  - icon: SF Symbol name
  - description: Detailed explanation
  - color: Associated UI color

### AIServiceStatus (enum)
- **File**: AIModels.swift
- **Purpose**: Tracks AI service health
- **Cases**:
  - .available - Ready to use
  - .unavailable - Not accessible
  - .initializing - Starting up
  - .error(String) - Failed with message

### AITaskGenerationRequest
- **File**: AIModels.swift
- **Purpose**: Request model for generating tasks from emails
- **Properties**:
  - emails: Array of EmailForAI
  - preferences: User settings
  - maxTasks: Limit on generated tasks

### AITaskGenerationResponse
- **File**: AIModels.swift
- **Purpose**: Response from AI task generation
- **Properties**:
  - tasks: Array of GeneratedTask
  - warnings: Optional issues encountered
  - success: Whether processing completed

### GeneratedTask
- **File**: AIModels.swift
- **Purpose**: AI-created task from email
- **Properties**:
  - title, description
  - suggestedDueDate
  - sourceEmailID (links to email)
  - confidence (0.0-1.0 score)
  - suggestedSection

### LLMRequestConfiguration
- **File**: AIModels.swift
- **Purpose**: Configuration for LLM parameters
- **Properties**:
  - temperature (0.0-1.0 creativity)
  - maxTokens (response length)
  - topP, frequencyPenalty, presencePenalty
  - model (identifier)
- **Presets**:
  - .taskGeneration - Optimized for creating tasks
  - .summarization - Optimized for summaries

### AIAnalytics
- **File**: AIModels.swift
- **Purpose**: Track AI usage and performance
- **Properties**:
  - totalRequests, successfulRequests, failedRequests
  - totalTasksGenerated
  - averageConfidence
  - lastRequestDate
  - currentProvider

---

## Type Aliases

### Task
- **Definition**: `typealias Task = DiligenceTask`
- **File**: Task.swift
- **Purpose**: Backward compatibility
- **Note**: Use `DiligenceTask` in new code

---

## Extensions

### Collection.subscript(safe:)
- **File**: RecurrenceModels.swift
- **Purpose**: Safe array access without crashes
- **Usage**:
  ```swift
  let weekday = weekdays[safe: index] // Returns Optional
  ```

---

## Model Relationships

```
TaskSection (1)
    ↓ has many
DiligenceTask (*)
    ↓ references
ProcessedEmail (via emailID)
    ↓ created by AI
GeneratedTask → DiligenceTask (conversion)

DiligenceTask (parent)
    ↓ spawns
DiligenceTask (recurring instances)
```

---

## SwiftData Models

Models marked with `@Model`:
- DiligenceTask
- TaskSection

These are persisted in SwiftData and require:
```swift
.modelContainer(for: [DiligenceTask.self, TaskSection.self])
```

---

## Import Guide

### For Task Features
```swift
import Foundation
import SwiftData
// Core/Models/Task/ files automatically available
```

### For Email Features
```swift
import Foundation
// Core/Models/Email/ files automatically available
```

### For AI Features
```swift
import Foundation
import SwiftUI  // For Color in AIProvider
// Core/Models/AI/ files automatically available
```

---

## Common Patterns

### Creating a Task
```swift
let task = DiligenceTask(
    title: "Meeting with client",
    dueDate: Date().addingTimeInterval(86400),
    recurrencePattern: .weekly
)
modelContext.insert(task)
```

### Processing an Email
```swift
let gmailMessage: GmailMessage = // ... from API
if let processed = ProcessedEmail.from(gmailMessage) {
    // Display in UI
    print(processed.subject)
    print(processed.attachmentDescription)
}
```

### Checking Recurrence
```swift
if task.isRecurring {
    print(task.recurrenceDescription)
    if let nextDate = task.nextDueDate {
        print("Next occurrence: \(nextDate)")
    }
}
```

### AI Provider Selection
```swift
let provider: AIProvider = .appleIntelligence
print(provider.displayName)  // "Apple Intelligence"
print(provider.icon)         // "apple.logo"
```

---

## Testing Models

### Unit Test Example
```swift
import Testing

@Test("Task recurrence generates correct next date")
func testWeeklyRecurrence() throws {
    let task = DiligenceTask(
        title: "Weekly Report",
        dueDate: Date(),
        recurrencePattern: .weekly
    )
    
    let nextDate = task.calculateNextDueDate(from: Date())
    #expect(nextDate != nil)
}
```

---

## Documentation

All models use DocC-style documentation:
- `///` for types, properties, and methods
- `/// - Parameter` for parameters
- `/// - Returns` for return values
- `/// - Note` for important information

To view documentation in Xcode:
- **Option + Click** on any type or property
- Quick Help inspector shows full documentation

---

## Future Considerations

### Planned Enhancements
1. **Model Validation**: Add `validate()` methods
2. **Codable Conformance**: Full API serialization support
3. **Model Protocols**: Shared traits (Identifiable, Timestamped)
4. **Relationship Types**: Explicit relationship modeling
5. **Migration Support**: SwiftData schema versioning

### Performance Notes
- `DiligenceTask.recurrenceWeekdays` uses Data storage for SwiftData
- `ProcessedEmail.from(_:)` is a synchronous operation - consider async for large batches
- `generateRecurringInstances()` has a safety limit of 100 instances

---

## Version History

**v1.0** (Current)
- Initial refactored model structure
- Comprehensive documentation
- Three domain-based folders (Task, Email, AI)
- Backward compatibility maintained

*/
