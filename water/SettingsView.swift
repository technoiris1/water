//
//  SettingsView.swift
//  water
//

import SwiftUI
import UniformTypeIdentifiers

/// The app's Settings window (⌘,): themes, colour palette and background image.
struct SettingsView: View {
    @Environment(ThemeStore.self) private var theme

    @State private var newThemeName = ""
    @State private var isImportingImage = false
    @State private var imageError: String?

    var body: some View {
        @Bindable var theme = theme

        Form {
            Section("Themes") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 12)], spacing: 12) {
                    ForEach(Palette.presets + theme.settings.customPalettes) { palette in
                        PaletteSwatch(palette: palette, isSelected: palette == theme.settings.palette)
                            .onTapGesture { theme.settings.palette = palette }
                            .contextMenu {
                                if theme.settings.customPalettes.contains(palette) {
                                    Button("Delete Theme", systemImage: "trash", role: .destructive) {
                                        theme.deleteCustomPalette(palette)
                                    }
                                }
                            }
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                ColorPicker("Accent", selection: colorBinding(\.accent), supportsOpacity: false)
                ColorPicker("Background", selection: colorBinding(\.background), supportsOpacity: false)
                ColorPicker("Cards", selection: colorBinding(\.surface), supportsOpacity: false)
                ColorPicker("Text", selection: colorBinding(\.text), supportsOpacity: false)
                ColorPicker("Secondary Text", selection: colorBinding(\.secondaryText), supportsOpacity: false)

                HStack {
                    TextField("New theme name", text: $newThemeName)
                    Button("Save as Theme") {
                        theme.saveCurrentPalette(named: newThemeName.trimmingCharacters(in: .whitespaces))
                        newThemeName = ""
                    }
                    .disabled(newThemeName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } header: {
                Text("Colour Palette")
            } footer: {
                Text("Tweak any colour, then save it as your own theme. Right-click a custom theme to delete it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Background") {
                HStack(spacing: 12) {
                    BackgroundPreview()
                        .frame(width: 120, height: 72)
                        .clipped()

                    VStack(alignment: .leading) {
                        Button("Choose Image…") { isImportingImage = true }
                        if theme.backgroundImage != nil {
                            Button("Remove Image", role: .destructive) { theme.removeBackgroundImage() }
                        }
                    }
                }

                if theme.backgroundImage != nil {
                    Slider(value: $theme.settings.backgroundImageOpacity, in: 0.1...1) { Text("Image Opacity") }
                    Slider(value: $theme.settings.backgroundBlur, in: 0...30) { Text("Image Blur") }
                }
                Slider(value: $theme.settings.surfaceOpacity, in: 0.3...1) { Text("Card Opacity") }
            }

            Section {
                Button("Reset Appearance to Default") { theme.resetToDefaults() }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 640)
        .fileImporter(isPresented: $isImportingImage, allowedContentTypes: [.image]) { result in
            do {
                try theme.setBackgroundImage(from: result.get())
            } catch {
                imageError = error.localizedDescription
            }
        }
        .alert("Couldn't Set Background", isPresented: Binding(
            get: { imageError != nil },
            set: { if !$0 { imageError = nil } }
        )) {
            Button("OK") {}
        } message: {
            Text(imageError ?? "")
        }
    }

    /// Bridges a hex-string palette field to a `Color` for `ColorPicker`.
    private func colorBinding(_ keyPath: WritableKeyPath<Palette, String>) -> Binding<Color> {
        Binding(
            get: { Color(hex: theme.settings.palette[keyPath: keyPath]) },
            set: { theme.settings.palette[keyPath: keyPath] = $0.hexString }
        )
    }
}

/// A small card previewing a palette's colours.
private struct PaletteSwatch: View {
    let palette: Palette
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Color(hex: palette.background)
                Rectangle()
                    .fill(Color(hex: palette.surface))
                    .border(Color(hex: palette.text), width: 1.5)
                    .padding(8)
                HStack(spacing: 4) {
                    Rectangle().fill(Color(hex: palette.accent))
                    Rectangle().fill(Color(hex: palette.text))
                    Rectangle().fill(Color(hex: palette.secondaryText))
                }
                .frame(width: 48, height: 12)
            }
            .frame(height: 52)
            .overlay {
                Rectangle()
                    .strokeBorder(isSelected ? Color(hex: palette.accent) : Color(hex: palette.text).opacity(0.3), lineWidth: isSelected ? 3 : 1)
            }

            Text(palette.name)
                .font(.caption.weight(isSelected ? .heavy : .medium))
                .lineLimit(1)
        }
        .contentShape(.rect)
    }
}

private struct BackgroundPreview: View {
    var body: some View {
        ThemedBackground()
            .overlay {
                Color.clear
                    .themedSurface()
                    .padding(14)
            }
    }
}
