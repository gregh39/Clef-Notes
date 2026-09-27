// Clef Notes/Views/ThemeView.swift

import SwiftUI

struct ThemeView: View {
    @EnvironmentObject var settingsManager: SettingsManager

    /// Appearance mode is free. Accent colors beyond the default, the custom color, and the
    /// alternate app icons are Pro; while locked, tapping them shows the paywall.
    @State private var showingPaywall = false

    private var isLocked: Bool { !settingsManager.proAppearanceUnlocked }

    // Define adaptive columns for the grids
    private let colorColumns = [GridItem(.adaptive(minimum: 60))]
    private let iconColumns = [GridItem(.adaptive(minimum: 80))]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                
                // --- APPEARANCE MODE SECTION ---
                VStack(alignment: .leading, spacing: 12) {
                    Text("Appearance Mode")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    Picker("Appearance Mode", selection: $settingsManager.colorSchemeSetting) {
                        ForEach(ColorSchemeSetting.allCases) { scheme in
                            Text(scheme.rawValue).tag(scheme)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                }
                
                Divider()
                
                // --- ACCENT COLOR SECTION ---
                VStack(alignment: .leading, spacing: 16) {
                    Text("Accent Color")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: colorColumns, spacing: 20) {
                        ForEach(AccentColor.allCases.filter { $0 != .custom }) { color in
                            colorSwatch(for: color)
                        }

                        if isLocked {
                            lockedCustomColorSwatch()
                        } else {
                            customColorSwatch()
                        }
                    }
                    .padding(.horizontal)

                    if isLocked {
                        proFooter
                    }
                }
                
                Divider()

                // --- APP ICON SECTION ---
                VStack(alignment: .leading, spacing: 16) {
                    Text("App Icon")
                        .font(.headline)
                        .padding(.horizontal)

                    LazyVGrid(columns: iconColumns, spacing: 20) {
                        ForEach(AppIcon.allCases) { icon in
                            iconSwatch(for: icon)
                        }
                    }
                    .padding(.horizontal)
                    .onChange(of: settingsManager.appIcon) {
                        settingsManager.setAppIcon()
                    }
                }
            }
            .padding(.vertical)
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
        .navigationTitle("Theme & Appearance")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
    }

    /// A view for a single predefined color swatch.
    private func colorSwatch(for color: AccentColor) -> some View {
        let requiresPro = isLocked && color != SettingsManager.freeAccentColor
        return Button {
            if requiresPro {
                showingPaywall = true
            } else {
                settingsManager.accentColor = color
            }
        } label: {
            ZStack {
                Circle()
                    .fill(color.color ?? .clear)
                    .frame(width: 50, height: 50)

                if settingsManager.effectiveAccentColor == color {
                    Image(systemName: "checkmark")
                        .font(.headline.bold())
                        .foregroundColor(.white)
                }
            }
            .overlay(
                Circle()
                    .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
            )
            .overlay(alignment: .bottomTrailing) {
                if requiresPro { ProLockBadge() }
            }
        }
        .accessibilityLabel(requiresPro ? "\(color.rawValue), requires ClefNotes Pro" : color.rawValue)
    }

    /// Custom color entry point shown while Pro appearance is locked.
    private func lockedCustomColorSwatch() -> some View {
        Button {
            showingPaywall = true
        } label: {
            Image(systemName: "eyedropper.halffull")
                .font(.headline)
                .foregroundColor(.secondary)
                .frame(width: 50, height: 50)
                .background(Color(UIColor.secondarySystemGroupedBackground), in: Circle())
                .overlay(Circle().stroke(Color.secondary.opacity(0.5), lineWidth: 1))
                .overlay(alignment: .bottomTrailing) { ProLockBadge() }
        }
        .accessibilityLabel("Custom color, requires ClefNotes Pro")
    }

    private var proFooter: some View {
        Button {
            showingPaywall = true
        } label: {
            Label("More colors and app icons with ClefNotes Pro", systemImage: "crown.fill")
                .font(.footnote)
        }
        .padding(.horizontal)
    }
    
    /// A view that acts as a color swatch but is actually a `ColorPicker`.
    private func customColorSwatch() -> some View {
        ColorPicker(selection: $settingsManager.customAccentColor, supportsOpacity: false) {
            // Intentionally empty label
        }
        .labelsHidden()
        .frame(width: 50, height: 50)
        .background(settingsManager.customAccentColor)
        .clipShape(Circle())
        .overlay(
            ZStack {
                if settingsManager.accentColor == .custom {
                    Image(systemName: "checkmark")
                        .font(.headline.bold())
                        .foregroundColor(settingsManager.customAccentColor.isDark() ? .white : .black)
                } else {
                     Image(systemName: "eyedropper.halffull")
                        .font(.headline)
                        .foregroundColor(settingsManager.customAccentColor.isDark() ? .white.opacity(0.8) : .black.opacity(0.8))
                }
            }
        )
        .overlay(
            Circle()
                .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
        )
        .onChange(of: settingsManager.customAccentColor) {
            // Automatically select "Custom" when the color picker is used
            settingsManager.accentColor = .custom
        }
    }
    
    /// A view for a single app icon swatch.
    private func iconSwatch(for icon: AppIcon) -> some View {
        let requiresPro = isLocked && icon != SettingsManager.freeAppIcon
        let isSelected = settingsManager.effectiveAppIcon == icon
        return Button {
            if requiresPro {
                showingPaywall = true
            } else {
                settingsManager.appIcon = icon
            }
        } label: {
            VStack(spacing: 8) {
                Image(icon.preview)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? settingsManager.activeAccentColor : Color.secondary.opacity(0.5), lineWidth: isSelected ? 3 : 1)
                    )
                    .overlay(alignment: .bottomTrailing) {
                        if requiresPro { ProLockBadge().offset(x: 4, y: 4) }
                    }
                
              /*  Text(icon.rawValue)
                    .font(.caption)
                    .foregroundColor(settingsManager.appIcon == icon ? .primary : .secondary)*/
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(requiresPro ? "App icon, requires ClefNotes Pro" : "App icon")
    }
}

/// Small lock shown on Pro-only swatches.
private struct ProLockBadge: View {
    var body: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .padding(4)
            .background(Color.black.opacity(0.6), in: Circle())
    }
}


// A helper to determine if a color is dark, for placing light/dark text on top of it.
fileprivate extension Color {
    func isDark() -> Bool {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0
        UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: nil)
        let luminance = 0.299 * red + 0.587 * green + 0.114 * blue
        return luminance < 0.5
    }
}
