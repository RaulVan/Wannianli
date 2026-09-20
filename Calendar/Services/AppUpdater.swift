import Combine
import Sparkle

@MainActor
final class AppUpdater: ObservableObject {
    enum UpdateFrequency: String, CaseIterable, Identifiable {
        case never
        case daily
        case weekly

        var id: Self { self }
        var interval: TimeInterval? {
            switch self {
            case .never: nil
            case .daily: 24 * 60 * 60
            case .weekly: 7 * 24 * 60 * 60
            }
        }
        var title: String {
            switch self {
            case .never: "从不"
            case .daily: "每天"
            case .weekly: "每周"
            }
        }

        static func resolve(automaticallyChecks: Bool, interval: TimeInterval) -> Self {
            guard automaticallyChecks else { return .never }
            return interval >= 7 * 24 * 60 * 60 ? .weekly : .daily
        }
    }

    let controller: SPUStandardUpdaterController
    @Published private(set) var canCheckForUpdates = false
    private var subscriptions: Set<AnyCancellable> = []

    init(startingUpdater: Bool = true) {
        controller = SPUStandardUpdaterController(
            startingUpdater: startingUpdater,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        let updater = controller.updater
        let savedFrequency = UpdateFrequency.resolve(
            automaticallyChecks: updater.automaticallyChecksForUpdates,
            interval: updater.updateCheckInterval
        )
        if let interval = savedFrequency.interval {
            // Normalize legacy hourly and six-hour preferences to the supported daily cadence.
            updater.updateCheckInterval = interval
        }
        controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .sink { [weak self] value in self?.canCheckForUpdates = value }
            .store(in: &subscriptions)
    }

    var automaticallyChecksForUpdates: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set {
            controller.updater.automaticallyChecksForUpdates = newValue
            objectWillChange.send()
        }
    }

    var updateCheckInterval: TimeInterval {
        get { controller.updater.updateCheckInterval }
        set {
            controller.updater.updateCheckInterval = newValue
            objectWillChange.send()
        }
    }

    var updateFrequency: UpdateFrequency {
        get {
            UpdateFrequency.resolve(
                automaticallyChecks: automaticallyChecksForUpdates,
                interval: updateCheckInterval
            )
        }
        set {
            switch newValue {
            case .never:
                automaticallyChecksForUpdates = false
            case .daily, .weekly:
                guard let interval = newValue.interval else { return }
                updateCheckInterval = interval
                automaticallyChecksForUpdates = true
            }
        }
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
