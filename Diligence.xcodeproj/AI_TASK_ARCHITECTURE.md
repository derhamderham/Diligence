# AI Task Feature - Architecture Diagram

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Diligence App                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌────────────────────────────────────────────────────────┐    │
│  │                     GmailView                          │    │
│  │  ┌──────────────────────────────────────────────┐     │    │
│  │  │         EmailDetailView                      │     │    │
│  │  │  ┌────────────┐  ┌──────────────────┐       │     │    │
│  │  │  │ 🧠 AI Task │  │ Create Task      │       │     │    │
│  │  │  │   Button   │  │ (Manual)         │       │     │    │
│  │  │  └─────┬──────┘  └──────────────────┘       │     │    │
│  │  │        │                                     │     │    │
│  │  │        │ onClick()                           │     │    │
│  │  │        ▼                                     │     │    │
│  │  │  generateAITaskSuggestions()                │     │    │
│  │  └──────────────────┬───────────────────────────┘     │    │
│  │                     │                                  │    │
│  └─────────────────────┼──────────────────────────────────┘    │
│                        │                                        │
│                        ▼                                        │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │                 AITaskService                           │  │
│  │  ┌──────────────────────────────────────────────────┐  │  │
│  │  │ createAITaskSuggestions(email, sections)        │  │  │
│  │  │                                                  │  │  │
│  │  │  Step 1: buildEmailContext()                    │  │  │
│  │  │    • Extract subject, body, sender              │  │  │
│  │  │    • NLP analysis (dates, amounts, entities)    │  │  │
│  │  │    • Detect companies, people                   │  │  │
│  │  │                                                  │  │  │
│  │  │  Step 2: extractAttachmentContent()             │  │  │
│  │  │    • Download attachments via GmailService      │  │  │
│  │  │    • PDF text extraction (PDFKit)               │  │  │
│  │  │    • Word doc processing                        │  │  │
│  │  │    • OCR for images (Vision framework)          │  │  │
│  │  │                                                  │  │  │
│  │  │  Step 3: buildTaskCreationPrompt()              │  │  │
│  │  │    • Combine email + attachment context         │  │  │
│  │  │    • Include available sections                 │  │  │
│  │  │    • Add specific instructions for LLM          │  │  │
│  │  │    • Optimize for context window                │  │  │
│  │  │                                                  │  │  │
│  │  │  Step 4: Call AI Service                        │  │  │
│  │  │    ▼                                             │  │  │
│  │  └──┼──────────────────────────────────────────────┘  │  │
│  └─────┼─────────────────────────────────────────────────┘  │
│        │                                                     │
│        ▼                                                     │
│  ┌─────────────────────────────────────────────────────┐   │
│  │          EnhancedAIEmailService                     │   │
│  │  ┌──────────────────────────────────────────────┐  │   │
│  │  │ queryEmails(prompt, [email])                 │  │   │
│  │  │   • Wraps LLMService                          │  │   │
│  │  │   • Email-specific handling                   │  │   │
│  │  │   • Error recovery                            │  │   │
│  │  └────────────────┬─────────────────────────────┘  │   │
│  └───────────────────┼────────────────────────────────┘   │
│                      │                                      │
│                      ▼                                      │
│  ┌──────────────────────────────────────────────────────┐ │
│  │                 LLMService                           │ │
│  │  ┌───────────────────────────────────────────────┐  │ │
│  │  │ queryWithModelFallback(messages)             │  │ │
│  │  │                                               │  │ │
│  │  │  • Build HTTP request                         │  │ │
│  │  │  • Try primary model (Jan.ai)                 │  │ │
│  │  │  • Fallback to other running models           │  │ │
│  │  │  • Handle streaming responses                 │  │ │
│  │  │  • Parse SSE format                           │  │ │
│  │  │  • Aggregate chunks                           │  │ │
│  │  └───────────────┬───────────────────────────────┘  │ │
│  └──────────────────┼──────────────────────────────────┘ │
│                     │                                      │
└─────────────────────┼──────────────────────────────────────┘
                      │
                      ▼
        ┌─────────────────────────────┐
        │      Jan.ai / Apple AI      │
        │  (Local LLM on your Mac)    │
        │                              │
        │  • Analyzes email content    │
        │  • Identifies tasks          │
        │  • Extracts details          │
        │  • Returns JSON response     │
        └──────────────┬───────────────┘
                       │
                       │ JSON Response
                       ▼
┌──────────────────────────────────────────────────────────────────┐
│                    Response Processing                           │
│                                                                   │
│  parseAIResponse(jsonString)                                    │
│    • Decode JSON                                                 │
│    • Validate structure                                          │
│    • Create AITaskSuggestion objects                            │
│    • Handle errors                                               │
└─────────────────────────┬────────────────────────────────────────┘
                          │
                          │ [AITaskSuggestion]
                          ▼
        ┌─────────────────────────────────────────┐
        │     AITaskSuggestionsView (Sheet)       │
        │  ┌───────────────────────────────────┐  │
        │  │  📋 Task 1: Pay Invoice           │  │
        │  │     ☑ Selected                    │  │
        │  │     Title: [editable]             │  │
        │  │     Due: [date picker]            │  │
        │  │     Section: [dropdown]           │  │
        │  │     Amount: $1,250.00             │  │
        │  │     Tags: AP                      │  │
        │  ├───────────────────────────────────┤  │
        │  │  📋 Task 2: Schedule Meeting      │  │
        │  │     ☑ Selected                    │  │
        │  │     ...                           │  │
        │  └───────────────────────────────────┘  │
        │                                          │
        │  [Cancel]  [Create Selected Tasks]      │
        └────────────────┬─────────────────────────┘
                         │
                         │ User Confirms
                         ▼
        ┌─────────────────────────────────────┐
        │   handleAITasksCreated(tasks)       │
        │                                      │
        │  • Convert AITaskSuggestion          │
        │    to DiligenceTask                  │
        │  • Insert into SwiftData             │
        │  • Save to database                  │
        │  • Trigger Reminders sync            │
        │  • Close sheet                       │
        └──────────────┬───────────────────────┘
                       │
                       ▼
        ┌─────────────────────────────────────┐
        │         SwiftData Storage           │
        │  ┌──────────────────────────────┐   │
        │  │     DiligenceTask Objects    │   │
        │  │  • title                     │   │
        │  │  • description               │   │
        │  │  • dueDate                   │   │
        │  │  • amount                    │   │
        │  │  • sectionID                 │   │
        │  │  • recurrencePattern         │   │
        │  │  • ...                       │   │
        │  └──────────────────────────────┘   │
        └──────────────┬───────────────────────┘
                       │
                       ├──────────────────┐
                       │                  │
                       ▼                  ▼
        ┌──────────────────────┐   ┌──────────────────┐
        │    Tasks View        │   │  Apple Reminders │
        │  (Displays tasks)    │   │  (Sync enabled)  │
        └──────────────────────┘   └──────────────────┘
```

## Data Flow

```
Email Selected → AI Task Clicked
    ↓
Email Context Building
    ├─ Subject
    ├─ Body (truncated to 1000 chars)
    ├─ Sender info
    ├─ Date
    ├─ Detected dates
    ├─ Detected amounts
    ├─ Named entities
    └─ Company/person names
    ↓
Attachment Processing (max 3)
    ├─ PDF → PDFKit → Text
    ├─ Word → Document processing → Text
    ├─ Image → Vision OCR → Text
    └─ Summary (first 80 chars each)
    ↓
Prompt Construction
    ├─ Email context
    ├─ Attachment summaries
    ├─ Available sections
    ├─ Current date
    └─ LLM instructions
    ↓
LLM Query (Jan.ai/Apple AI)
    ├─ HTTP POST to /v1/chat/completions
    ├─ Streaming enabled
    ├─ Model: Jan-v1-4B-Q4_K_M (or selected)
    ├─ Temperature: 0.7
    └─ Max tokens: 4096
    ↓
Streaming Response
    ├─ Server-Sent Events format
    ├─ JSON chunks aggregated
    └─ Parse when [DONE]
    ↓
JSON Parsing
    {
      "tasks": [
        {
          "title": "string",
          "description": "string",
          "dueDate": "YYYY-MM-DD",
          "section": "string",
          "tags": ["AP"],
          "amount": 1250.00,
          "priority": "medium",
          "isRecurring": false,
          "recurrencePattern": null
        }
      ]
    }
    ↓
Suggestion Objects Created
    [AITaskSuggestion]
    ↓
Sheet Displayed
    User reviews, edits, selects
    ↓
Confirmation
    ↓
DiligenceTask Objects Created
    ├─ Map AITaskSuggestion fields
    ├─ Parse dates
    ├─ Link sections
    └─ Set recurrence
    ↓
SwiftData Insert & Save
    ├─ modelContext.insert(task)
    └─ try modelContext.save()
    ↓
Reminders Sync
    Notification posted
    ↓
UI Update
    ├─ Sheet closes
    └─ Tasks view refreshes
```

## Component Dependencies

```
GmailView
  ├─ EmailDetailView
  ├─ AITaskService
  │   ├─ EnhancedAIEmailService
  │   │   └─ LLMService
  │   ├─ GmailService (for attachments)
  │   └─ DocumentProcessor
  │       ├─ PDFKit (PDF parsing)
  │       ├─ Vision (OCR)
  │       └─ NaturalLanguage (entity detection)
  ├─ AITaskSuggestionsView
  └─ SwiftData ModelContext
```

## Error Handling Flow

```
generateAITaskSuggestions()
    ├─ Try: AITaskService.createAITaskSuggestions()
    │   ├─ Try: buildEmailContext()
    │   │   └─ Catch: Throw AITaskError.processingFailed
    │   ├─ Try: extractAttachmentContent()
    │   │   └─ Log errors, continue with available content
    │   ├─ Try: buildPrompt()
    │   │   └─ Never fails (string concatenation)
    │   └─ Try: aiService.queryEmails()
    │       ├─ Try: LLMService.query()
    │       │   ├─ Network error → Throw LLMError.networkError
    │       │   ├─ Timeout → Throw LLMError.networkError(timeout)
    │       │   ├─ Invalid response → Throw LLMError.invalidResponse
    │       │   └─ Model not found → Throw LLMError.modelSessionNotFound
    │       └─ Try: parseAIResponse()
    │           ├─ Invalid JSON → Throw AITaskError.invalidResponse
    │           └─ No tasks → Throw AITaskError.noTasksFound
    └─ Catch: Display error in UI
        ├─ Set aiTaskError = error.localizedDescription
        ├─ Show error banner
        └─ Stop spinner
```

## State Management

```
GmailView State:
  ├─ selectedEmail: ProcessedEmail?
  ├─ isGeneratingAITasks: Bool
  ├─ aiTaskSuggestions: [AITaskSuggestion]
  ├─ aiTaskError: String?
  ├─ showingAITaskSuggestions: Bool
  └─ sections: [TaskSection] (@Query)

EmailDetailView State:
  ├─ @Binding isGeneratingAITasks
  ├─ @Binding aiTaskError
  └─ onGenerateAITasks: () -> Void

AITaskService State (@Published):
  ├─ isProcessing: Bool
  ├─ processingProgress: Double
  ├─ processingStatus: String
  └─ lastError: String?

AITaskSuggestionsView State:
  ├─ selectedSuggestions: Set<UUID>
  └─ editedSuggestions: [UUID: EditableTaskSuggestion]
```

## API Communication

```
App → Jan.ai

POST http://127.0.0.1:1337/v1/chat/completions
Headers:
  Content-Type: application/json
  Accept: application/json
  Authorization: Bearer [API_KEY] (if set)

Body:
{
  "model": "Jan-v1-4B-Q4_K_M",
  "messages": [
    {
      "role": "system",
      "content": "You are an intelligent email assistant..."
    },
    {
      "role": "user",
      "content": "Analyze this email...[email content]"
    }
  ],
  "temperature": 0.7,
  "max_tokens": 4096,
  "stream": true
}

Response (streaming):
data: {"choices":[{"delta":{"content":"{"}}],...}
data: {"choices":[{"delta":{"content":"\"tasks\""}}],...}
...
data: [DONE]
```

## Database Schema

```
DiligenceTask (@Model)
  ├─ id: String (UUID)
  ├─ title: String
  ├─ taskDescription: String
  ├─ isCompleted: Bool
  ├─ createdDate: Date
  ├─ dueDate: Date?
  ├─ amount: Double?              ← For invoices
  ├─ sectionID: String?           ← Links to TaskSection
  ├─ reminderID: String?          ← Sync with Reminders
  ├─ recurrencePattern: RecurrencePattern
  ├─ recurrenceInterval: Int
  ├─ isFromEmail: Bool
  ├─ emailID: String?
  ├─ emailSubject: String?
  ├─ emailSender: String?
  └─ gmailURL: String?

TaskSection (@Model)
  ├─ id: String (UUID)
  ├─ title: String
  ├─ sortOrder: Int
  ├─ reminderID: String?
  └─ createdDate: Date
```

---

**Legend**:
- `→` Data flow
- `├─` Component/dependency
- `└─` Final item in list
- `▼` Next step/continuation
- `↓` Vertical flow
