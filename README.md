# Diligence

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-macOS-lightgrey.svg)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/swift-5.0+-orange.svg)](https://swift.org)
[![Xcode](https://img.shields.io/badge/xcode-15.0+-blue.svg)](https://developer.apple.com/xcode/)

A powerful and intuitive task management application for macOS that seamlessly integrates with Gmail to help you stay organized and on top of your responsibilities.

## Table of Contents

- [Features](#features)
- [Screenshots](#screenshots)
- [Installation](#installation)
- [Getting Started](#getting-started)
- [Usage Guide](#usage-guide)
- [Technology Stack](#technology-stack)
- [Configuration](#configuration)
- [Contributing](#contributing)
- [License](#license)
- [Contact](#contact)
- [Acknowledgments](#acknowledgments)

## Features

### Core Task Management
- ✅ **Task Creation & Management** - Create, edit, and organize tasks with rich details
- 📋 **Sections/Categories** - Organize tasks into custom sections (AR, AP, and more)
- 🎯 **Priority Levels** - Set High, Medium, or Low priority for tasks
- 📅 **Due Dates & Reminders** - Schedule tasks and get notified via Apple Reminders
- ✔️ **Completion Tracking** - Mark tasks as complete and track your progress
- 💰 **Amount Tracking** - Add monetary values and currency to tasks for bills and payments

### Gmail Integration
- 📧 **Email Import** - Read Gmail messages and convert them to tasks
- 🔄 **Automatic Task Creation** - Create tasks directly from email content
- 📎 **Email Metadata** - Preserve sender, subject, and context from emails
- 🔗 **Seamless Sync** - Integration between Gmail inbox and task list

### Advanced Features
- 🔁 **Recurring Tasks** - Set up daily, weekly, or monthly recurring tasks
- 🔍 **Powerful Search** - Advanced search syntax with filters and operators
- 📊 **Excel Export** - Export tasks to multi-tab Excel spreadsheets (.xlsx)
- 📈 **Summary Reports** - View tasks due by next Saturday and other time periods
- 🗂️ **Section Management** - Create custom sections with color coding
- ⚙️ **Settings Panel** - Comprehensive configuration options

### Apple Reminders Integration
- 🔔 **Reminders Sync** - Two-way sync with Apple Reminders app
- 📱 **Cross-Device Access** - Access your tasks on all Apple devices via iCloud
- 🔐 **Strict Diligence Mode** - Manages only Diligence-created reminder lists
- 🔄 **Auto-Recovery** - Automatic XPC connection recovery and error handling

### User Interface
- 🎨 **Three-Pane Interface** - Navigation sidebar, list view, and detail view
- 🌓 **Dark Mode Support** - Full support for macOS Dark Mode
- ⚡ **Native Performance** - Built with SwiftUI for smooth, native experience
- 🔀 **Intuitive Navigation** - Switch seamlessly between Tasks and Gmail views

## Screenshots

> 📸 **Note**: Add screenshots of your application here to showcase the interface.

```
![Main Interface](screenshots/main-interface.png)
![Task Detail View](screenshots/task-detail.png)
![Gmail Integration](screenshots/gmail-integration.png)
![Search Feature](screenshots/search.png)
```

**Recommended Screenshots:**
1. Main three-pane interface showing tasks list
2. Task detail view with all fields filled
3. Gmail integration panel
4. Search results with advanced syntax
5. Settings/configuration panel
6. Section management view

## Installation

### Prerequisites

- **macOS**: 13.0 (Ventura) or later
- **Xcode**: 15.0 or later
- **Swift**: 5.9 or later
- **Gmail Account**: For email integration features (optional)

### Build Instructions

1. **Clone the repository**
   ```bash
   git clone https://github.com/derham/diligence.git
   cd diligence
   ```

2. **Open in Xcode**
   ```bash
   open Diligence.xcodeproj
   # or
   open Diligence.xcworkspace  # if using CocoaPods/SPM
   ```

3. **Configure Signing & Capabilities**
   - Open the project in Xcode
   - Select the "Diligence" target
   - Go to "Signing & Capabilities" tab
   - Select your development team
   - Ensure the following capabilities are enabled:
     - ✅ App Sandbox
     - ✅ Calendars (for Reminders integration)
     - ✅ Network (for Gmail integration)

4. **Build and Run**
   - Select your Mac as the destination
   - Press `⌘R` or click the "Run" button
   - Grant permissions when prompted (Reminders access, Gmail OAuth)

### First Launch Setup

On first launch, the app will:
1. Request access to Reminders (required for task sync)
2. Create a "Diligence - Tasks" list in Apple Reminders
3. Prompt for Gmail authentication (optional, for email features)

## Getting Started

### Initial Setup

1. **Grant Reminders Access**
   - When prompted, click "Allow" to grant Reminders access
   - This enables task sync across all your Apple devices

2. **Configure Gmail (Optional)**
   - Navigate to Settings → Gmail Integration
   - Click "Connect Gmail Account"
   - Authorize the app through Google OAuth
   - Select which labels/folders to monitor

3. **Create Your First Section**
   - Click the "+" button in the sidebar
   - Name your section (e.g., "Accounts Payable", "Personal")
   - Choose a color (optional)
   - Sections help organize different types of tasks

4. **Create Your First Task**
   - Click the "+" button in the task list
   - Fill in task details:
     - Title (required)
     - Description
     - Due date
     - Priority level
     - Section assignment
     - Amount (for bills/payments)

## Usage Guide

### Creating and Managing Tasks

**Manual Task Creation:**
```
1. Click the "New Task" button (+) in the toolbar
2. Enter task details:
   - Title: What needs to be done
   - Description: Additional context
   - Due Date: When it's due
   - Priority: High/Medium/Low
   - Section: Where to organize it
   - Amount: For bills or payments
3. Click "Save" or press ⌘S
```

**From Gmail:**
```
1. Switch to "Gmail" view in the sidebar
2. Browse your email messages
3. Select an email to convert
4. Click "Create Task from Email"
5. Edit the auto-filled details
6. The email sender and subject are preserved
```

### Working with Sections

Sections help you organize tasks into categories:

- **Accounts Receivable (AR)**: Money you're owed
- **Accounts Payable (AP)**: Bills you need to pay
- **Personal**: Personal tasks
- **Work**: Work-related tasks
- **Custom**: Create your own!

Each section syncs to a separate list in Apple Reminders:
- `Diligence - AR`
- `Diligence - AP`
- `Diligence - Tasks` (default, unsectioned)

### Setting Up Recurring Tasks

1. Create or edit a task
2. In the detail view, find "Recurrence"
3. Choose a pattern:
   - **Daily**: Every day at the same time
   - **Weekly**: Every week on the same day
   - **Monthly**: Same date each month
   - **Custom**: Define your own pattern
4. The task will automatically recreate when completed

### Using Search

Diligence includes a powerful search feature:

**Basic Search:**
```
Just type keywords to search task titles and descriptions
```

**Advanced Search Syntax:**
```
priority:high              # High priority tasks only
section:AP                 # Tasks in AP section
due:today                  # Due today
due:tomorrow               # Due tomorrow
due:this_week              # Due this week
amount:>100                # Amount greater than 100
amount:50..200             # Amount between 50 and 200
completed:no               # Incomplete tasks
from_email:yes             # Tasks created from email
```

**Combine Operators:**
```
priority:high section:AP due:this_week    # High priority AP tasks due this week
amount:>500 completed:no                  # Incomplete tasks over $500
```

### Exporting to Excel

1. Click the "Export" button in the toolbar
2. Choose export options:
   - All tasks or filtered results
   - Include completed tasks (optional)
3. Select save location
4. The Excel file includes:
   - **Summary Tab**: Overview and statistics
   - **By Section Tabs**: Tasks grouped by section
   - **All Tasks Tab**: Complete task list

Excel file includes columns:
- Title, Description, Status
- Due Date, Priority, Section
- Amount, Currency
- Created Date, Completed Date
- Email Metadata (if applicable)

### Gmail Integration Setup

**OAuth Configuration:**
1. Create a project in [Google Cloud Console](https://console.cloud.google.com)
2. Enable Gmail API
3. Create OAuth 2.0 credentials
4. Download client configuration
5. Add credentials to app settings
6. Authorize the app

**Email Monitoring:**
- The app can monitor specific Gmail labels
- New emails appear in the Gmail view
- Convert emails to tasks with one click
- Email context is preserved in task notes

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘N` | New Task |
| `⌘S` | Save Task |
| `⌘F` | Search |
| `⌘E` | Export to Excel |
| `⌘R` | Sync with Reminders |
| `⌘,` | Open Settings |
| `⌘W` | Close Window |
| `Delete` | Delete Selected Task |
| `Space` | Toggle Task Completion |

## Technology Stack

### Core Technologies
- **Swift 5.9+** - Modern, safe programming language
- **SwiftUI** - Declarative UI framework
- **AppKit** - macOS native UI components
- **Combine** - Reactive programming framework

### Apple Frameworks
- **EventKit** - Apple Reminders integration
- **Foundation** - Core utilities and data structures
- **SwiftData** - Modern persistence framework
- **UniformTypeIdentifiers** - File type management

### Third-Party Libraries
- **Excel Export** - XLSX file generation
- **Google APIs** - Gmail integration
- **OAuth 2.0** - Secure authentication

### Architecture
- **MVVM Pattern** - Model-View-ViewModel architecture
- **Swift Concurrency** - async/await for asynchronous operations
- **SwiftData** - Persistent storage with `@Model` objects
- **Observers** - Reactive state management with `@Published` properties

## Configuration

### App Settings

Access settings via `⌘,` or the Settings button:

**General:**
- Default section for new tasks
- Task sorting preferences
- Date format preferences

**Reminders:**
- Sync frequency
- Strict Diligence mode (manage only Diligence lists)
- Auto-create section lists
- Notification preferences

**Gmail:**
- Connected account
- Monitored labels/folders
- Sync frequency
- Email-to-task default settings

**Export:**
- Default export location
- Excel template preferences
- Include/exclude options

### Entitlements

The app requires these entitlements (configured in Xcode):

```xml
com.apple.security.app-sandbox = true
com.apple.security.network.client = true
com.apple.security.files.user-selected.read-write = true
com.apple.security.personal-information.calendars = true
```

### Privacy Permissions

The app requests:
- **Calendars/Reminders**: Required for task sync
- **Network**: Required for Gmail integration
- **File Access**: For Excel export

## Contributing

Contributions are welcome! Here's how you can help:

### Reporting Bugs

1. Check if the bug has already been reported in [Issues](https://github.com/derhamderham/diligence/issues)
2. If not, create a new issue with:
   - Clear description of the bug
   - Steps to reproduce
   - Expected vs actual behavior
   - macOS version and app version
   - Screenshots if applicable

### Suggesting Features

1. Open a new issue with the `enhancement` label
2. Describe the feature and its benefits
3. Provide use cases and examples

### Pull Requests

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Write or update tests if applicable
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

### Code Style

- Follow Swift API Design Guidelines
- Use SwiftLint for code formatting
- Write clear, self-documenting code
- Add comments for complex logic
- Update documentation as needed

## License

This project is licensed under the MIT License.

```
MIT License

Copyright (c) 2025 derham

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Contact

**Author**: derham

- GitHub: [@derhamderham](https://github.com/derhamderham)
- Email: derham@gmail.com *(update with your actual email)*

## Acknowledgments

- Apple's EventKit framework for Reminders integration
- Google Gmail API for email integration
- The Swift and SwiftUI community for excellent resources and support
- Open source contributors and beta testers

---

## Troubleshooting

### Common Issues

**Reminders Access Denied:**
```
Solution: Go to System Settings > Privacy & Security > Calendars
         Enable access for Diligence
```

**Gmail Not Connecting:**
```
Solution: 1. Check your internet connection
         2. Verify OAuth credentials are correct
         3. Re-authenticate in Settings
```

**Tasks Not Syncing:**
```
Solution: 1. Check Reminders permission
         2. Click "Force Sync" in Settings
         3. Restart the app if needed
```

**XPC Connection Errors:**
```
Solution: These are temporary connection issues
         The app auto-recovers with exponential backoff
         If persistent, restart your Mac
```

### Debug Mode

Enable debug logging:
```bash
# Run from Terminal with debug logging
open -a Diligence --args -debug
```

### Reset App Data

If experiencing persistent issues:
1. Quit the app completely
2. Open Settings → Reset
3. Choose reset option:
   - Reset Reminders (clears reminder IDs)
   - Reset Gmail (clears OAuth tokens)
   - Reset All (full reset)
4. Restart the app

---

*Last updated: November 2025*
