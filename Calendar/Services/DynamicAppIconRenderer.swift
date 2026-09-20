import AppKit

enum DynamicAppIconRenderer {
    static func render(day: Int, baseImage: NSImage) -> NSImage? {
        guard (1...31).contains(day), baseImage.size.width > 0, baseImage.size.height > 0 else { return nil }
        let size = baseImage.size
        let output = NSImage(size: size)
        output.lockFocus()
        defer { output.unlockFocus() }

        baseImage.draw(in: NSRect(origin: .zero, size: size),
                       from: .zero, operation: .sourceOver, fraction: 1)

        let value = String(day) as NSString
        let fontSize = size.width * (day < 10 ? 0.52 : 0.43)
        let font = NSFont(name: "Baskerville-SemiBold", size: fontSize)
            ?? NSFont(name: "Baskerville", size: fontSize)
            ?? NSFont.systemFont(ofSize: fontSize, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(srgbRed: 0.81, green: 0.15, blue: 0.18, alpha: 1)
        ]
        let textSize = value.size(withAttributes: attributes)
        // The generated base reserves the paper region below its red binding strip.
        let origin = NSPoint(x: (size.width - textSize.width) / 2,
                             y: size.height * 0.25 - textSize.height * 0.05)
        value.draw(at: origin, withAttributes: attributes)
        return output
    }

    static func bundledBaseImage(bundle: Bundle = .main) -> NSImage? {
        let candidates = [
            bundle.url(forResource: "calendar-base", withExtension: "png", subdirectory: "Icon"),
            bundle.url(forResource: "calendar-base", withExtension: "png")
        ]
        return candidates.compactMap { $0 }.compactMap(NSImage.init(contentsOf:)).first
    }
}
