import SwiftUI

enum AppTheme: String, Codable, CaseIterable, Identifiable, Sendable {
    case system
    case catppuccinLatte
    case catppuccinFrappe
    case catppuccinMacchiato
    case catppuccinMocha

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .catppuccinLatte: "Catppuccin Latte"
        case .catppuccinFrappe: "Catppuccin Frappé"
        case .catppuccinMacchiato: "Catppuccin Macchiato"
        case .catppuccinMocha: "Catppuccin Mocha"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .catppuccinLatte: .light
        case .catppuccinFrappe, .catppuccinMacchiato, .catppuccinMocha: .dark
        }
    }

    var palette: AppPalette {
        switch self {
        case .system:
            AppPalette(
                base: Color(nsColor: .windowBackgroundColor), mantle: Color(nsColor: .underPageBackgroundColor),
                surface0: Color(nsColor: .controlBackgroundColor), surface1: Color(nsColor: .unemphasizedSelectedContentBackgroundColor),
                text: .primary, subtext: .secondary, accent: .accentColor,
                green: .green, yellow: .orange, red: .red
            )
        case .catppuccinLatte:
            AppPalette(hex: ("eff1f5", "e6e9ef", "ccd0da", "bcc0cc", "4c4f69", "6c6f85", "8839ef", "40a02b", "df8e1d", "d20f39"))
        case .catppuccinFrappe:
            AppPalette(hex: ("303446", "292c3c", "414559", "51576d", "c6d0f5", "a5adce", "ca9ee6", "a6d189", "e5c890", "e78284"))
        case .catppuccinMacchiato:
            AppPalette(hex: ("24273a", "1e2030", "363a4f", "494d64", "cad3f5", "a5adcb", "c6a0f6", "a6da95", "eed49f", "ed8796"))
        case .catppuccinMocha:
            AppPalette(hex: ("1e1e2e", "181825", "313244", "45475a", "cdd6f4", "a6adc8", "cba6f7", "a6e3a1", "f9e2af", "f38ba8"))
        }
    }
}

struct AppPalette {
    let base: Color
    let mantle: Color
    let surface0: Color
    let surface1: Color
    let text: Color
    let subtext: Color
    let accent: Color
    let green: Color
    let yellow: Color
    let red: Color

    init(base: Color, mantle: Color, surface0: Color, surface1: Color, text: Color, subtext: Color, accent: Color, green: Color, yellow: Color, red: Color) {
        self.base = base
        self.mantle = mantle
        self.surface0 = surface0
        self.surface1 = surface1
        self.text = text
        self.subtext = subtext
        self.accent = accent
        self.green = green
        self.yellow = yellow
        self.red = red
    }

    init(hex values: (String, String, String, String, String, String, String, String, String, String)) {
        self.init(
            base: Color(hex: values.0), mantle: Color(hex: values.1),
            surface0: Color(hex: values.2), surface1: Color(hex: values.3),
            text: Color(hex: values.4), subtext: Color(hex: values.5), accent: Color(hex: values.6),
            green: Color(hex: values.7), yellow: Color(hex: values.8), red: Color(hex: values.9)
        )
    }
}

private extension Color {
    init(hex: String) {
        let value = UInt64(hex, radix: 16) ?? 0
        self.init(.sRGB, red: Double((value >> 16) & 0xff) / 255, green: Double((value >> 8) & 0xff) / 255, blue: Double(value & 0xff) / 255, opacity: 1)
    }
}

private struct OpenYapThemeKey: EnvironmentKey {
    static let defaultValue = AppTheme.system
}

extension EnvironmentValues {
    var openYapTheme: AppTheme {
        get { self[OpenYapThemeKey.self] }
        set { self[OpenYapThemeKey.self] = newValue }
    }
}

extension View {
    func openYapTheme(_ theme: AppTheme) -> some View {
        environment(\.openYapTheme, theme)
            .preferredColorScheme(theme.colorScheme)
            .tint(theme.palette.accent)
            .foregroundStyle(theme.palette.text)
    }
}
