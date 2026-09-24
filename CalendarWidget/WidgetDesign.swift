import SwiftUI

enum WidgetDesign {
    static let lightBackground = Color(red: 0.988, green: 0.980, blue: 0.973)
    static let darkBackground = Color(red: 0.137, green: 0.137, blue: 0.137)
    static let lightInk = Color(red: 0.090, green: 0.110, blue: 0.141)
    static let darkInk = Color(red: 0.933, green: 0.925, blue: 0.910)
    static let lightSecondary = Color(red: 0.392, green: 0.416, blue: 0.451)
    static let darkSecondary = Color(red: 0.678, green: 0.690, blue: 0.718)
    static let lightRed = Color(red: 0.812, green: 0.188, blue: 0.224)
    static let darkRed = Color(red: 1.000, green: 0.384, blue: 0.412)
    static let lightGreen = Color(red: 0.129, green: 0.522, blue: 0.353)
    static let darkGreen = Color(red: 0.384, green: 0.788, blue: 0.604)
    static let lightLine = Color(red: 0.890, green: 0.875, blue: 0.863)
    static let darkLine = Color(red: 0.259, green: 0.259, blue: 0.259)

    static func background(for scheme: ColorScheme) -> Color {
        scheme == .dark ? darkBackground : lightBackground
    }

    static func ink(for scheme: ColorScheme) -> Color {
        scheme == .dark ? darkInk : lightInk
    }

    static func secondary(for scheme: ColorScheme) -> Color {
        scheme == .dark ? darkSecondary : lightSecondary
    }

    static func red(for scheme: ColorScheme) -> Color {
        scheme == .dark ? darkRed : lightRed
    }

    static func green(for scheme: ColorScheme) -> Color {
        scheme == .dark ? darkGreen : lightGreen
    }

    static func line(for scheme: ColorScheme) -> Color {
        scheme == .dark ? darkLine : lightLine
    }

    static func lunarFont(_ size: CGFloat) -> Font {
        .custom("Songti SC", size: size).weight(.bold)
    }
}
