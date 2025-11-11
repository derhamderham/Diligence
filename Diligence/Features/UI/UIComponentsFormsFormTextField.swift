//
//  FormTextField.swift
//  Diligence
//
//  Standardized form text field with validation
//

import SwiftUI

// MARK: - Form Text Field

/// A standardized text field for forms with validation and consistent styling
///
/// FormTextField provides a consistent text input experience with:
/// - Built-in validation
/// - Error message display
/// - Character count (optional)
/// - Required field indicator
/// - Placeholder text
/// - Icon support
///
/// ## Example
/// ```swift
/// @State private var email = ""
///
/// FormTextField(
///     title: "Email",
///     text: $email,
///     placeholder: "you@example.com",
///     icon: "envelope",
///     keyboardType: .emailAddress,
///     validation: { text in
///         text.isValidEmail ? nil : "Invalid email address"
///     }
/// )
/// ```
///
/// ## Accessibility
/// - Includes label for VoiceOver
/// - Error messages are announced
/// - Supports dynamic type
/// - Keyboard navigation
struct FormTextField: View {
    
    // MARK: - Properties
    
    /// Field title/label
    private let title: String
    
    /// Binding to the text value
    @Binding private var text: String
    
    /// Placeholder text
    private let placeholder: String
    
    /// Optional SF Symbol icon
    private let icon: String?
    
    /// Whether this field is required
    private let isRequired: Bool
    
    /// Whether to show character count
    private let showCharacterCount: Bool
    
    /// Maximum character count (0 = unlimited)
    private let maxCharacters: Int
    
    /// Keyboard type
    private let keyboardType: KeyboardType
    
    /// Whether the field is secure (password)
    private let isSecure: Bool
    
    /// Validation function
    private let validation: ((String) -> String?)?
    
    /// Help text shown below the field
    private let helpText: String?
    
    // MARK: - State
    
    @State private var isFocused: Bool = false
    @State private var validationError: String?
    @FocusState private var focusState: Bool
    
    // MARK: - Initialization
    
    /// Creates a form text field
    ///
    /// - Parameters:
    ///   - title: Field label
    ///   - text: Binding to text value
    ///   - placeholder: Placeholder text
    ///   - icon: Optional SF Symbol name
    ///   - isRequired: Whether field is required
    ///   - showCharacterCount: Whether to show character count
    ///   - maxCharacters: Max character limit (0 = unlimited)
    ///   - keyboardType: Keyboard type for input
    ///   - isSecure: Whether this is a password field
    ///   - helpText: Optional help text
    ///   - validation: Optional validation function returning error message or nil
    init(
        title: String,
        text: Binding<String>,
        placeholder: String = "",
        icon: String? = nil,
        isRequired: Bool = false,
        showCharacterCount: Bool = false,
        maxCharacters: Int = 0,
        keyboardType: KeyboardType = .default,
        isSecure: Bool = false,
        helpText: String? = nil,
        validation: ((String) -> String?)? = nil
    ) {
        self.title = title
        self._text = text
        self.placeholder = placeholder
        self.icon = icon
        self.isRequired = isRequired
        self.showCharacterCount = showCharacterCount
        self.maxCharacters = maxCharacters
        self.keyboardType = keyboardType
        self.isSecure = isSecure
        self.helpText = helpText
        self.validation = validation
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Label
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                
                if isRequired {
                    Text("*")
                        .foregroundColor(.red)
                }
                
                Spacer()
                
                if showCharacterCount {
                    Text("\(text.count)\(maxCharacters > 0 ? "/\(maxCharacters)" : "")")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            
            // Text field container
            HStack(spacing: 8) {
                // Icon
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(iconColor)
                        .frame(width: 20)
                }
                
                // Text field
                Group {
                    if isSecure {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                            .textFieldStyle(.plain)
                    }
                }
                .font(.system(size: 13))
                .focused($focusState)
                .onChange(of: text) { _, newValue in
                    handleTextChange(newValue)
                }
                .onChange(of: focusState) { _, focused in
                    isFocused = focused
                    if !focused {
                        validateField()
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(backgroundColor)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            
            // Help text or error message
            if let error = validationError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                    Text(error)
                        .font(.system(size: 11))
                }
                .foregroundColor(.red)
            } else if let help = helpText {
                Text(help)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(text)
        .accessibilityHint(accessibilityHint)
    }
    
    // MARK: - Computed Properties
    
    /// Background color based on state
    private var backgroundColor: Color {
        if validationError != nil {
            return Color.red.opacity(0.05)
        } else if isFocused {
            return Color.accentColor.opacity(0.05)
        } else {
            return Color(NSColor.controlBackgroundColor)
        }
    }
    
    /// Border color based on state
    private var borderColor: Color {
        if validationError != nil {
            return Color.red
        } else if isFocused {
            return Color.accentColor
        } else {
            return Color.gray.opacity(0.3)
        }
    }
    
    /// Border width based on state
    private var borderWidth: CGFloat {
        (isFocused || validationError != nil) ? 1.5 : 1.0
    }
    
    /// Icon color based on state
    private var iconColor: Color {
        if validationError != nil {
            return Color.red
        } else if isFocused {
            return Color.accentColor
        } else {
            return Color.secondary
        }
    }
    
    /// Accessibility label
    private var accessibilityLabel: String {
        var label = title
        if isRequired {
            label += ", required field"
        }
        return label
    }
    
    /// Accessibility hint
    private var accessibilityHint: String {
        if let error = validationError {
            return "Error: \(error)"
        } else if let help = helpText {
            return help
        } else {
            return "Text field"
        }
    }
    
    // MARK: - Methods
    
    /// Handles text change with character limit
    private func handleTextChange(_ newValue: String) {
        if maxCharacters > 0 && newValue.count > maxCharacters {
            text = String(newValue.prefix(maxCharacters))
        }
        
        // Clear error on change
        if validationError != nil {
            validationError = nil
        }
    }
    
    /// Validates the field
    private func validateField() {
        if let validation = validation {
            validationError = validation(text)
        } else if isRequired && text.isEmpty {
            validationError = "This field is required"
        } else {
            validationError = nil
        }
    }
}

// MARK: - Keyboard Type

enum KeyboardType {
    case `default`
    case emailAddress
    case url
    case numberPad
    case phonePad
    
    #if os(iOS)
    var uiKeyboardType: UIKeyboardType {
        switch self {
        case .default: return .default
        case .emailAddress: return .emailAddress
        case .url: return .URL
        case .numberPad: return .numberPad
        case .phonePad: return .phonePad
        }
    }
    #endif
}

// MARK: - Preview

#Preview("Form Text Field States") {
    VStack(spacing: 20) {
        // Basic field
        FormTextField(
            title: "Full Name",
            text: .constant("John Doe"),
            placeholder: "Enter your name",
            icon: "person"
        )
        
        // Required field with validation
        FormTextField(
            title: "Email",
            text: .constant("invalid-email"),
            placeholder: "you@example.com",
            icon: "envelope",
            isRequired: true,
            keyboardType: .emailAddress,
            validation: { text in
                text.isValidEmail ? nil : "Please enter a valid email address"
            }
        )
        
        // Field with character count
        FormTextField(
            title: "Description",
            text: .constant("Sample text"),
            placeholder: "Enter description",
            showCharacterCount: true,
            maxCharacters: 100,
            helpText: "Brief description of the task"
        )
        
        // Secure field
        FormTextField(
            title: "Password",
            text: .constant(""),
            placeholder: "Enter password",
            icon: "lock",
            isRequired: true,
            isSecure: true
        )
        
        // Focused state
        FormTextField(
            title: "Task Title",
            text: .constant(""),
            placeholder: "What needs to be done?",
            icon: "checkmark.circle",
            isRequired: true
        )
    }
    .padding()
    .frame(width: 400)
}

#Preview("Dark Mode") {
    VStack(spacing: 20) {
        FormTextField(
            title: "Email",
            text: .constant("user@example.com"),
            placeholder: "you@example.com",
            icon: "envelope",
            isRequired: true
        )
        
        FormTextField(
            title: "Password",
            text: .constant("password123"),
            icon: "lock",
            isSecure: true
        )
    }
    .padding()
    .preferredColorScheme(.dark)
}
