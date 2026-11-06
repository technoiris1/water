//
//  Theme.swift
//  water
//

import SwiftUI
import AppKit

/// A named colour palette. Colours are stored as hex strings so palettes are easy to persist.
struct Palette: Codable, Hashable, Identifiable {
    var id: String = UUID().uuidString
    var name: String
    var accent: String
    var background: String
    var surface: String
    var text: String
    var secondaryText: String

    static let paper = Palette(id: "paper", name: "Paper", accent: "#3B82F6", background: "#F5F3EE", surface: "#FFFFFF", text: "#1F2328", secondaryText: "#6B7280")
    static let sage = Palette(id: "sage", name: "Sage", accent: "#4D7C5B", background: "#EEF3EC", surface: "#FBFDF9", text: "#1E2A22", secondaryText: "#61705F")
    static let ocean = Palette(id: "ocean", name: "Ocean", accent: "#0E7490", background: "#E8F3F7", surface: "#FAFDFE", text: "#132A33", secondaryText: "#55707A")
    static let blush = Palette(id: "blush", name: "Blush", accent: "#D9467A", background: "#FBEFF2", surface: "#FFFBFC", text: "#2E1A21", secondaryText: "#7D5D68")
    static let sand = Palette(id: "sand", name: "Sand", accent: "#B7791F", background: "#F7F0E3", surface: "#FFFCF5", text: "#2B2418", secondaryText: "#7A6A50")
    static let lavender = Palette(id: "lavender", name: "Lavender", accent: "#7C5CDB", background: "#F2EFFA", surface: "#FDFCFF", text: "#221D33", secondaryText: "#6C6585")

    static let presets: [Palette] = [.paper, .sage, .ocean, .blush, .sand, .lavender]
}

/// Everything the user can customise about the look of the app.
struct ThemeSettings: Codable {
    var palette: Palette = .paper
    var customPalettes: [Palette] = []
    var backgroundImageOpacity: Double = 1
    var backgroundBlur: Double = 0
    /// How opaque cards/panels are drawn over the background.
    var surfaceOpacity: Double = 0.85
}

enum ThemeError: LocalizedError {
    case unreadableImage

    var errorDescription: String? {
        "That file couldn't be read as an image."
    }
}

/// Owns the theme settings and background image, and persists them locally.
@Observable
final class ThemeStore {
    var settings: ThemeSettings {
        didSet { saveSettings() }
    }
    private(set) var backgroundImage: NSImage?

    private static let settingsKey = "themeSettings"

    private static var storageDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "Water", directoryHint: .isDirectory)
    }

    private static var backgroundImageURL: URL {
        storageDirectory.appending(path: "background-image")
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.settingsKey),
           let saved = try? JSONDecoder().decode(ThemeSettings.self, from: data) {
            settings = saved
        } else {
            settings = ThemeSettings()
        }
        if let data = try? Data(contentsOf: Self.backgroundImageURL) {
            backgroundImage = NSImage(data: data)
        }
    }

    // MARK: Resolved colours

    var accent: Color { Color(hex: settings.palette.accent) }
    var background: Color { Color(hex: settings.palette.background) }
    var surface: Color { Color(hex: settings.palette.surface) }
    var text: Color { Color(hex: settings.palette.text) }
    var secondaryText: Color { Color(hex: settings.palette.secondaryText) }

    // MARK: Palettes

    func saveCurrentPalette(named name: String) {
        var palette = settings.palette
        palette.id = UUID().uuidString
        palette.name = name
        settings.customPalettes.append(palette)
        settings.palette = palette
    }

    func deleteCustomPalette(_ palette: Palette) {
        settings.customPalettes.removeAll { $0.id == palette.id }
    }

    func resetToDefaults() {
        let customPalettes = settings.customPalettes
        settings = ThemeSettings()
        settings.customPalettes = customPalettes
    }

    // MARK: Background image

    /// Copies the chosen image into the app's own storage so it survives the original being moved.
    func setBackgroundImage(from url: URL) throws {
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer { if isAccessing { url.stopAccessingSecurityScopedResource() } }

        let data = try Data(contentsOf: url)
        guard let image = NSImage(data: data) else { throw ThemeError.unreadableImage }

        try FileManager.default.createDirectory(at: Self.storageDirectory, withIntermediateDirectories: true)
        try data.write(to: Self.backgroundImageURL, options: .atomic)
        backgroundImage = image
    }

    func removeBackgroundImage() {
        try? FileManager.default.removeItem(at: Self.backgroundImageURL)
        backgroundImage = nil
    }

    private func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: Self.settingsKey)
        }
    }
}

// MARK: - Hex colour helpers

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    var hexString: String {
        guard let color = NSColor(self).usingColorSpace(.sRGB) else { return "#000000" }
        func component(_ value: CGFloat) -> Int { Int((min(max(value, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", component(color.redComponent), component(color.greenComponent), component(color.blueComponent))
    }
}

// MARK: - Themed views

/// The window backdrop: palette background colour with the optional custom image on top.
struct ThemedBackground: View {
    @Environment(ThemeStore.self) private var theme

    var body: some View {
        ZStack {
            theme.background
            if let image = theme.backgroundImage {
                // Overlaying on a flexible clear view keeps scaledToFill from growing the layout.
                Color.clear
                    .overlay {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFill()
                    }
                    .clipped()
                    .blur(radius: theme.settings.backgroundBlur)
                    .opacity(theme.settings.backgroundImageOpacity)
            }
        }
        .ignoresSafeArea()
    }
}

/// Shared measurements for the app's boxy, bold look.
enum BoxStyle {
    static let borderWidth: CGFloat = 2
}

/// Draws content on a square card: surface colour and a thick border.
struct ThemedSurface: ViewModifier {
    @Environment(ThemeStore.self) private var theme

    func body(content: Content) -> some View {
        content
            .background(theme.surface.opacity(theme.settings.surfaceOpacity))
            .overlay {
                Rectangle().strokeBorder(theme.text, lineWidth: BoxStyle.borderWidth)
            }
    }
}

extension View {
    func themedSurface() -> some View {
        modifier(ThemedSurface())
    }
}

/// Big, heavy page title with an optional subtitle.
struct PageHeader: View {
    @Environment(ThemeStore.self) private var theme
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 40, weight: .black))
                .foregroundStyle(theme.text)
            if let subtitle {
                Text(subtitle)
                    .font(.headline)
                    .foregroundStyle(theme.secondaryText)
            }
        }
        // A boxed "sticker" keeps titles readable over busy background images.
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .themedSurface()
    }
}

/// Uppercase, heavy label used for card and section headings.
struct SectionLabel: View {
    @Environment(ThemeStore.self) private var theme
    let title: String
    var systemImage: String?

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            Text(title)
                .textCase(.uppercase)
                .tracking(0.8)
        }
        .font(.system(.subheadline, weight: .black))
        .foregroundStyle(theme.accent)
        .lineLimit(1)
    }
}

/// A flat progress bar with a border, matching the boxy style.
struct BoxProgressBar: View {
    @Environment(ThemeStore.self) private var theme
    let value: Double
    var color: Color?
    var height: CGFloat = 10

    var body: some View {
        Rectangle()
            .fill(theme.surface)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Rectangle()
                        .fill(color ?? theme.accent)
                        .frame(width: proxy.size.width * min(max(value, 0), 1))
                }
            }
            .overlay { Rectangle().strokeBorder(theme.text, lineWidth: BoxStyle.borderWidth) }
            .frame(height: height)
    }
}

/// Square, bordered button that darkens while pressed.
struct BoldButtonStyle: ButtonStyle {
    var isProminent = true

    func makeBody(configuration: Configuration) -> some View {
        BoldButton(configuration: configuration, isProminent: isProminent)
    }

    private struct BoldButton: View {
        @Environment(ThemeStore.self) private var theme
        @Environment(\.isEnabled) private var isEnabled
        let configuration: ButtonStyleConfiguration
        let isProminent: Bool

        var body: some View {
            configuration.label
                .font(.system(.body, weight: .heavy))
                .foregroundStyle(isProminent ? Color.white : theme.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isProminent ? theme.accent : theme.surface)
                .overlay { Rectangle().strokeBorder(theme.text, lineWidth: BoxStyle.borderWidth) }
                .brightness(configuration.isPressed ? -0.12 : 0)
                .opacity(isEnabled ? 1 : 0.4)
                .contentShape(.rect)
        }
    }
}

extension ButtonStyle where Self == BoldButtonStyle {
    static var bold: BoldButtonStyle { BoldButtonStyle() }
    static var boldSecondary: BoldButtonStyle { BoldButtonStyle(isProminent: false) }
}
