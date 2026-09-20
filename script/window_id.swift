import CoreGraphics
import Foundation

// Read-only helper for capturing the actual app's windows without Accessibility permission.
let kind = CommandLine.arguments.dropFirst().first ?? "main"
let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
for window in windows {
    guard let owner = window[kCGWindowOwnerName as String] as? String,
          owner == "万年历" || owner == "Wannianli",
          let bounds = window[kCGWindowBounds as String] as? [String: Any],
          let width = bounds["Width"] as? Double,
          let height = bounds["Height"] as? Double,
          let number = window[kCGWindowNumber as String] as? Int else { continue }
    if (kind == "main" && width >= 900 && height > 500)
        || (kind == "menu" && width >= 350 && width < 460 && height > 450)
        || (kind == "settings" && width >= 500 && width < 600 && height > 450) {
        print(number)
        exit(0)
    }
}
fputs("No matching visible calendar window\n", stderr)
exit(1)
