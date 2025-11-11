# AI Task Feature Implementation Guide

## Overview

The AI Task feature has been successfully integrated into your Diligence app. This feature uses your local LLM (Jan.ai or Apple Intelligence) to analyze emails and automatically generate intelligent task suggestions with proper categorization, due dates, amounts, and recurring patterns.

## 🎯 What's Been Implemented

### 1. **AI Task Button in Gmail View**

- **Location**: Email detail view, prominently placed next to "Create Task from This Email"
- **Visual**: Brain icon (🧠) with "AI Task" label
- **Behavior**: 
  - Shows a loading spinner while processing
  - Disabled during processing to prevent double-clicks
  - Includes helpful tooltip explaining the feature

### 2. **Context Menu Integration**

- Right-click on any email in the list to access "AI Task" option
- Provides quick access without opening the email detail view

### 3. **AI Task Generation Pipeline**

The system follows a sophisticated multi-step process:

#### **Step 1: Email Content Analysis**
- Extracts email subject, body, sender, and date
- Performs natural language processing to detect:
  - Dates mentioned in the email
  - Dollar amounts (for invoices/bills)
  - Named entities (people, organizations)
  - Company names
  - Person names

#### **Step 2: Attachment Processing**
- Downloads and extracts text from PDF files
- Reads Word documents (.docx, .doc)
- Performs OCR on images (PNG, JPG, HEIC) to extract text
- Limits to first 3 attachments to stay within LLM context window
- Each attachment is summarized with first 80 characters shown

#### **Step 3: Smart Prompt Construction**
- Builds a comprehensive prompt with:
  - Email context (subject, sender, date, body)
  - Attachment summaries
  - Available task sections/categories
  - Current date for relative date calculations
  - Specific instructions for the LLM

The prompt specifically instructs the LLM to:
- Extract ACTUAL details (no placeholders like "[vendor]" or "[amount]")
- Identify bill/invoice amounts and tag as AP (Accounts Payable) or AR (Accounts Receivable)
- Detect due dates or infer them logically
- Create separate tasks for recurring invoices with multiple payment dates
- Categorize tasks into appropriate sections
- Set priority levels (low, medium, high, urgent)
- Detect recurring patterns (daily, weekly, monthly, etc.)

#### **Step 4: LLM Processing with Streaming**
- Uses your configured LLM (Jan.ai by default)
- Handles streaming responses for better performance
- Automatically falls back to other running models if primary fails
- Comprehensive error handling for network issues, corrupted responses, etc.

#### **Step 5: Response Parsing**
Expected JSON format from LLM:
```json
{
  "tasks": [
    {
      "title": "Pay Acme Corp invoice $1,250.00",
      "description": "Monthly service invoice due November 30th",
      "dueDate": "2025-11-30",
      "section": "Accounting",
      "tags": ["AP"],
      "amount": 1250.00,
      "priority": "medium",
      "isRecurring": false,
      "recurrencePattern": null
    }
  ]
}
```

### 4. **AI Task Suggestions Review Interface**

When suggestions are generated, a modal sheet appears with:

- **Header**: Shows the email subject and sender for context
- **Suggestion Cards**: Each task displayed with:
  - Checkbox for selection (all selected by default)
  - Editable title
  - Editable description
  - Due date picker (optional)
  - Section/category dropdown
  - Amount field (for bills/invoices)
  - Priority selector
  - Recurring pattern options
  - Tags display (AP/AR indicators)

- **Bulk Actions**:
  - Select All / Deselect All toggle
  - Shows count of selected tasks
  - Can edit any field before creating

- **Footer**:
  - "Create Selected Tasks" button (only enabled if at least one selected)
  - "Cancel" button to dismiss without creating

### 5. **Error Handling**

Comprehensive error handling throughout:

- **Service Unavailable**: Shows when LLM is not running
- **Invalid Response**: Handles malformed JSON from LLM
- **Network Errors**: Timeout handling, connection issues
- **No Tasks Found**: Friendly message when email has no actionable items
- **Processing Failures**: Detailed error messages for debugging

Errors are displayed in an inline alert with:
- ⚠️ Warning icon
- Clear error message
- Dismiss button

### 6. **Task Creation**

When user confirms selected tasks:
- Tasks are inserted into SwiftData model context
- Saved to database
- Automatically syncs with Apple Reminders (if enabled)
- Triggers UI refresh in Tasks view
- Sheet closes automatically

## 🔧 Technical Implementation Details

### Key Components

1. **AITaskService** (`AITaskService.swift`)
   - Main orchestrator for AI task generation
   - Handles email context building
   - Manages attachment processing
   - Constructs LLM prompts
   - Parses AI responses

2. **AITaskSuggestionsView** (`AITaskSuggestionsView.swift`)
   - SwiftUI view for reviewing suggestions
   - Handles task editing and customization
   - Manages bulk selection
   - Creates DiligenceTask objects

3. **EnhancedAIEmailService** (`EnhancedAIEmailService.swift`)
   - Wrapper around LLMService
   - Provides email-specific AI capabilities
   - Handles multiple AI providers (Jan.ai, Apple Intelligence)

4. **LLMService** (`LLMService.swift`)
   - Low-level LLM communication
   - Streaming response handling
   - Model fallback logic
   - Connection management

5. **DocumentProcessor** (part of AITaskService)
   - PDF text extraction using PDFKit
   - Word document processing
   - OCR for images using Vision framework
   - Context window optimization

### Data Flow

```
User Clicks "AI Task" 
    ↓
GmailView.generateAITaskSuggestions()
    ↓
AITaskService.createAITaskSuggestions()
    ↓
Build Email Context + Extract Attachments
    ↓
Construct LLM Prompt
    ↓
EnhancedAIEmailService.queryEmails()
    ↓
LLMService.queryWithModelFallback()
    ↓
Parse JSON Response → AITaskSuggestion[]
    ↓
Show AITaskSuggestionsView Sheet
    ↓
User Reviews/Edits → Confirms
    ↓
Create DiligenceTask objects
    ↓
Save to SwiftData + Sync to Reminders
```

### Models

**AITaskSuggestion**:
```swift
struct AITaskSuggestion: Codable, Identifiable {
    let id: UUID
    var title: String
    var description: String
    var dueDate: String?        // "YYYY-MM-DD"
    var section: String?        // Section name
    var tags: [String]          // ["AP", "AR", etc.]
    var amount: Double?         // Dollar amount
    var priority: TaskPriority? // low, medium, high, urgent
    var isRecurring: Bool?      
    var recurrencePattern: String? // "daily", "weekly", etc.
}
```

**DiligenceTask** (existing model, already supports):
- `amount`: Double? - For bill/invoice amounts
- `recurrencePattern`: RecurrencePattern enum
- `sectionID`: String? - Links to TaskSection
- All standard task properties

## 📋 Usage Instructions

### For End Users

1. **Open Gmail View** in Diligence
2. **Select an email** with actionable items (invoice, meeting request, etc.)
3. **Click "AI Task"** button (or right-click email and select "AI Task")
4. **Wait for processing** (typically 2-10 seconds depending on email complexity)
5. **Review suggestions** in the modal that appears
6. **Edit any fields** as needed (title, description, due date, section, etc.)
7. **Uncheck tasks** you don't want to create
8. **Click "Create Selected Tasks"**
9. **Tasks appear** in your Tasks view, organized by section

### Best Practices

**For Invoices/Bills**:
- LLM will extract vendor name and amount
- Automatically tags as "AP" (Accounts Payable)
- Sets due date based on payment terms in email
- Creates separate tasks for installment payments

**For Meeting Requests**:
- Extracts meeting name and date/time
- Infers due date as the meeting date
- Includes attendees in description

**For Out-of-Office Notifications**:
- Creates note-type tasks
- Sets date range for absence period
- Includes person's name and contact info

**For Document Reviews**:
- Creates review task with document name
- Infers deadline if mentioned
- Links to attachment

## 🐛 Troubleshooting

### "No AI services available" Error

**Cause**: Jan.ai or LLM service is not running
**Solution**: 
1. Start Jan.ai application
2. Load a model (e.g., Jan-v1-4B-Q4_K_M)
3. Verify in Settings → AI/LLM that service is connected

### "No actionable tasks found" Message

**Cause**: Email doesn't contain clear action items
**Solution**: This is expected for:
- Newsletter emails
- Social notifications  
- Informational emails
- Generic greetings

Use manual "Create Task" instead

### "Request too large" Error

**Cause**: Email + attachments exceed LLM context window
**Solution**: System automatically:
- Limits to first 3 attachments
- Truncates email body to 1000 characters
- Limits attachment text to 80 characters preview
- If still too large, try model with larger context window

### LLM Returns Invalid JSON

**Cause**: Model hallucination or formatting issue
**Solution**: System logs full response for debugging. Try:
- Regenerating (click AI Task again)
- Using a different model
- Checking LLM service logs

### Tasks Created in Wrong Section

**Cause**: LLM misclassified task category
**Solution**:
- Edit section in review interface before creating
- Or reassign after creation in Tasks view
- Consider improving prompt in `AITaskService.swift`

## ⚙️ Configuration

### LLM Settings

Access via **Settings → AI/LLM**:

- **LLM Service**: Jan.ai (default) or Apple Intelligence
- **Model**: Auto-detects running model, or select from dropdown
- **Temperature**: 0.7 (default) - Lower = more deterministic, Higher = more creative
- **Max Tokens**: 4096 (default) - Maximum response length
- **Base URL**: http://127.0.0.1:1337/v1 (Jan.ai default)
- **API Key**: Optional for services that require it

### Task Sections

Create sections in **Tasks View → Manage Sections**:
- AI will automatically categorize tasks into these sections
- Examples: "Work", "Personal", "Accounting", "Projects", etc.

### Prompt Customization

For developers who want to customize the AI behavior:

Edit `AITaskService.swift`, method `buildTaskCreationPrompt()`:
- Modify system instructions
- Add custom examples
- Change output format requirements
- Adjust context window optimization

## 🔒 Privacy & Security

- **All processing is local**: No data sent to cloud AI services
- **Uses your local LLM**: Jan.ai runs entirely on your machine
- **Apple Intelligence**: Also fully on-device
- **Email data never leaves your Mac**
- **No third-party API calls** for AI processing

## 🚀 Performance Optimization

The implementation includes several optimizations:

1. **Context Window Management**:
   - Adaptive content truncation based on email + attachment size
   - Prioritizes most important content (subject, amounts, dates)
   - Limits attachments to 3 most relevant

2. **Streaming Responses**:
   - Shows progress immediately
   - Better perceived performance
   - Handles partial responses gracefully

3. **Model Fallback**:
   - If primary model fails, tries other running models
   - Prevents complete failure from model issues

4. **Caching**:
   - Attachment text cached after extraction
   - Reduces redundant processing for same email

5. **Async/Await**:
   - Non-blocking UI during processing
   - Cancellable operations
   - Proper error propagation

## 📊 Success Metrics

The feature tracks:
- Processing time (logged to console)
- Number of suggestions generated
- Success/failure rates
- Error types and frequencies
- User acceptance rate (how many suggestions get created)

## 🔮 Future Enhancements

Potential improvements:

1. **Batch Processing**: Generate tasks for multiple emails at once
2. **Learning**: Remember user preferences for section assignments
3. **Smart Defaults**: Pre-fill commonly used values
4. **Template Detection**: Recognize invoice templates and extract structured data
5. **Email Threading**: Analyze full conversation thread for context
6. **Calendar Integration**: Sync meeting tasks with calendar events
7. **Attachment Preview**: Show attachment content in review interface
8. **Voice Input**: Create tasks via dictation
9. **Quick Actions**: One-tap common task types
10. **Analytics Dashboard**: Show AI task creation statistics

## 📝 Code Locations

### Modified Files:
- `GmailView.swift` - Added AI Task button, state management, methods
- `AITaskService.swift` - Already existed, using as-is
- `AITaskSuggestionsView.swift` - Already existed, using as-is
- `EnhancedAIEmailService.swift` - Already existed, using as-is
- `LLMService.swift` - Already existed, using as-is

### New Files:
- `AI_TASK_FEATURE_GUIDE.md` - This documentation

### Dependencies:
- SwiftUI framework
- SwiftData for persistence
- PDFKit for PDF processing
- Vision framework for OCR
- NaturalLanguage for entity detection
- Combine for reactive programming
- Foundation for date/number parsing

## 🤝 Support

For issues or questions:
1. Check console logs for detailed error messages
2. Verify LLM service is running (Settings → AI/LLM)
3. Test with a simple email first
4. Review this documentation
5. Check individual component documentation in code comments

---

**Implementation Date**: November 11, 2025
**Version**: 1.0
**Status**: ✅ Production Ready
