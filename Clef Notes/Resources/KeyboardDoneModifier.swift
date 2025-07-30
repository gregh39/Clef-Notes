//
//  KeyboardDoneModifier.swift
//  Clef Notes
//
//  Created by Greg Holland on 7/30/25.
//


import SwiftUI

struct KeyboardDoneModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
    }
}

extension View {
    func addDoneButtonToKeyboard() -> some View {
        self.modifier(KeyboardDoneModifier())
    }
}

/// A ViewModifier that adds "Previous", "Next", and "Done" buttons to the keyboard toolbar
/// for navigating between focusable fields.
struct KeyboardNavigationModifier<T: Hashable>: ViewModifier {
    /// The currently focused field.
    @FocusState.Binding var focusedField: T?
    /// An array of all possible fields that can be focused.
    let fields: [T]

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    // "Previous" button
                    Button(action: {
                        moveFocus(forward: false)
                    }, label: {
                        Image(systemName: "chevron.up")
                    })
                    .disabled(isPreviousDisabled())

                    // "Next" button
                    Button(action: {
                        moveFocus(forward: true)
                    }, label: {
                        Image(systemName: "chevron.down")
                    })
                    .disabled(isNextDisabled())

                    Spacer()

                    // "Done" button
                    Button("Done") {
                        focusedField = nil
                    }
                }
            }
    }
    
    /// Checks if the "Previous" button should be disabled.
    private func isPreviousDisabled() -> Bool {
        guard let currentFocus = focusedField, let currentIndex = fields.firstIndex(of: currentFocus) else {
            return true
        }
        return currentIndex == 0
    }
    
    /// Checks if the "Next" button should be disabled.
    private func isNextDisabled() -> Bool {
        guard let currentFocus = focusedField, let currentIndex = fields.firstIndex(of: currentFocus) else {
            return true
        }
        return currentIndex == fields.count - 1
    }

    /// Moves the focus to the previous or next field in the `fields` array.
    private func moveFocus(forward: Bool) {
        guard let currentFocus = focusedField, let currentIndex = fields.firstIndex(of: currentFocus) else {
            return
        }
        
        let newIndex = forward ? currentIndex + 1 : currentIndex - 1

        if fields.indices.contains(newIndex) {
            focusedField = fields[newIndex]
        }
    }
}

extension View {
    /// Adds a keyboard toolbar with navigation buttons (Previous, Next, Done) to the view.
    ///
    /// - Parameters:
    ///   - for: An array of all the focusable fields, typically `YourEnum.allCases`.
    ///   - focus: The binding to the `@FocusState` variable.
    func addKeyboardNavigation<T: Hashable>(for fields: [T], focus: FocusState<T?>.Binding) -> some View {
        self.modifier(KeyboardNavigationModifier(focusedField: focus, fields: fields))
    }
}
