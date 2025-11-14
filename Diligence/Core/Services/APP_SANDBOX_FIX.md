# App Sandbox Permissions Fix

## Problem

Error message:
```
Failed to create export file: You don't have permission to save the file 
"Tasks Export - 13-Nov-25.xls" in the folder "Downloads".
```

## Root Cause

Your app is running in an **App Sandbox** which restricts file system access. By default, sandboxed apps cannot write to user directories like Downloads, Documents, or Desktop.

## Solution Options

### Option 1: Enable File Access Entitlements (Recommended for Development)

1. **Open your project in Xcode**
2. **Select your project** in the Project Navigator (top-level item)
3. **Select your app target** (under TARGETS)
4. **Go to "Signing & Capabilities" tab**
5. **Find "App Sandbox"** section

6. **Enable these permissions:**
   - ✅ **User Selected File: Read/Write**
     - This allows saving files to user-chosen locations
   
   OR
   
   - ✅ **Downloads Folder: Read/Write**
     - This specifically allows Downloads folder access
   
   OR (for maximum compatibility during development)
   
   - ✅ **File Access Type: User Selected File** (Read/Write)
   - ✅ **Downloads Folder** (Read/Write)
   - ✅ **Documents Folder** (Read/Write)

### Option 2: Disable App Sandbox (Quick Fix for Development Only)

**⚠️ WARNING:** Only do this during development. Apps submitted to the Mac App Store MUST have App Sandbox enabled.

1. **Open your project in Xcode**
2. **Select your project** → **Target** → **Signing & Capabilities**
3. **Find "App Sandbox"**
4. **Click the "-" button** to remove App Sandbox capability
5. **Rebuild your app**

### Option 3: Use NSSavePanel (Best for Production)

Instead of saving directly, use `NSSavePanel` to let users choose where to save:

```swift
@MainActor
static func openInExcel(data: Data, filename: String, taskCount: Int = 0) {
    let savePanel = NSSavePanel()
    savePanel.nameFieldStringValue = filename
    savePanel.allowedContentTypes = [.init(filenameExtension: "xls")!]
    savePanel.message = "Save Excel Export"
    
    savePanel.begin { response in
        guard response == .OK, let fileURL = savePanel.url else {
            print("❌ User cancelled save")
            return
        }
        
        do {
            try data.write(to: fileURL)
            print("✅ File saved successfully: \(fileURL.path)")
            
            // Open in Excel
            let excelBundleID = "com.microsoft.Excel"
            if let excelURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: excelBundleID) {
                NSWorkspace.shared.open([fileURL], withApplicationAt: excelURL, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
            } else {
                NSWorkspace.shared.open(fileURL)
            }
        } catch {
            showErrorAlert(message: "Failed to save file: \(error.localizedDescription)")
        }
    }
}
```

## Current Code Workaround

The updated code now tries multiple locations in this order:

1. **Downloads** folder (if accessible)
2. **Documents** folder (if accessible)
3. **Desktop** folder (if accessible)
4. **Temporary** folder (always accessible, but files may be deleted)

The file WILL save to the first accessible location, even if it's just the temp folder.

## Verify Entitlements

Check your `.entitlements` file should include:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    
    <!-- File access for Downloads -->
    <key>com.apple.security.files.downloads.read-write</key>
    <true/>
    
    <!-- Or user-selected file access -->
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
</dict>
</plist>
```

## Quick Fix Steps

### For Development (Fastest):

1. **Xcode** → **Project** → **Target** → **Signing & Capabilities**
2. Find **App Sandbox** section
3. Enable **"Downloads Folder"** with **Read/Write** access
4. **Clean build** (⇧⌘K) and **rebuild** (⌘B)
5. Run app and try export again

### For Production (Best):

Use **Option 3** (NSSavePanel) to let users choose save location. This:
- ✅ Works with App Sandbox enabled
- ✅ Gives users control over where files go
- ✅ No special entitlements needed
- ✅ Mac App Store compliant

## Test It

After enabling Downloads folder access:

1. **Clean Build** (Product → Clean Build Folder or ⇧⌘K)
2. **Rebuild** (⌘B)
3. **Run** your app
4. Click **Export**
5. Console should show:
   ```
   📁 Attempting to save to Downloads: /Users/you/Downloads/Tasks Export - 13-Nov-25.xls
   ✅ File saved successfully to Downloads: Tasks Export - 13-Nov-25.xls
   📂 Final save location: Downloads - /Users/you/Downloads/Tasks Export - 13-Nov-25.xls
   ```

## Still Getting Permission Error?

If you still get permission errors after enabling Downloads folder access:

### Check 1: Restart Xcode
Sometimes Xcode needs to be restarted for entitlement changes to take effect.

### Check 2: Check Build Settings
Make sure `CODE_SIGN_ENTITLEMENTS` points to your `.entitlements` file:
- Xcode → Project → Build Settings
- Search for "Code Signing Entitlements"
- Should show: `YourApp/YourApp.entitlements`

### Check 3: Clean Derived Data
```bash
# In Terminal:
rm -rf ~/Library/Developer/Xcode/DerivedData
```

Then rebuild in Xcode.

### Check 4: Check System Preferences
- System Settings → Privacy & Security
- Files and Folders
- Find your app
- Make sure it has access to Downloads folder

## Alternative: Use Temporary Directory

If you can't enable Downloads access and need a quick workaround, files will save to the temp directory automatically. To find them:

```bash
# In Terminal:
open $TMPDIR
```

Look for files named `Tasks Export - *.xls`

## For Mac App Store Distribution

If you plan to distribute via Mac App Store:

1. ✅ Keep App Sandbox **enabled**
2. ✅ Use **NSSavePanel** (Option 3)
3. ✅ Or enable **"Downloads Folder"** entitlement
4. ✅ In App Store Connect, declare why you need file access

## Summary

**Quickest Fix:** Enable "Downloads Folder: Read/Write" in App Sandbox settings

**Best Practice:** Use `NSSavePanel` to let users choose where to save

**Current Code:** Already falls back to Temp directory if others fail

---

**After applying the fix, the export should work and the file will open automatically in Excel!**
