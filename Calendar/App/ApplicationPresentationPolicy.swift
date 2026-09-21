import AppKit

enum ApplicationPresentationPolicy {
    static func activationPolicy(
        mainWindowVisible: Bool,
        settingsWindowVisible: Bool
    ) -> NSApplication.ActivationPolicy {
        mainWindowVisible || settingsWindowVisible ? .regular : .accessory
    }
}
