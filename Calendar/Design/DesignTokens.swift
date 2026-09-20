import SwiftUI

enum Design {
    static let red = adaptive(light: 0xCF3039, dark: 0xFF6269)
    static let green = adaptive(light: 0x21855A, dark: 0x62C99A)
    static let ink = adaptive(light: 0x171C24, dark: 0xEEECE8)
    static let secondary = adaptive(light: 0x646A73, dark: 0xADB0B7)
    static let muted = adaptive(light: 0xAFB0B4, dark: 0x70737A)
    static let background = adaptive(light: 0xFCFAF8, dark: 0x232323)
    static let surface = adaptive(light: 0xF2F0ED, dark: 0x2D2D2D)
    static let holiday = adaptive(light: 0xFCEEEF, dark: 0x3F292C)
    static let line = adaptive(light: 0xE3DFDC, dark: 0x424242)
    static let badge = adaptive(light: 0x355572, dark: 0x7599BF)
    static let selection = Color(red: 0.82, green: 0.16, blue: 0.21)
    static let windowWidth: CGFloat = 1036
    static let windowHeight: CGFloat = 876
    static let panelWidth: CGFloat = 380
    static let panelHeight: CGFloat = 660

    static func adaptive(light: UInt, dark: UInt) -> Color {
        func color(_ value: UInt) -> NSColor {
            NSColor(srgbRed: CGFloat((value >> 16) & 255) / 255,
                    green: CGFloat((value >> 8) & 255) / 255,
                    blue: CGFloat(value & 255) / 255, alpha: 1)
        }
        return Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? color(dark) : color(light)
        })
    }
    static func lunarFont(_ size: CGFloat) -> Font { .custom("Songti SC", size: size).weight(.bold) }
}

struct Hairline: View {
    var body: some View { Rectangle().fill(Design.line).frame(height: 1) }
}

struct IconButton: View {
    let symbol: String
    let label: String
    var action: () -> Void
    var body: some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: 17)).frame(width: 30, height: 30) }
            .buttonStyle(.plain).foregroundStyle(Design.secondary)
            .help(label).accessibilityLabel(label).accessibilityIdentifier(label)
    }
}
