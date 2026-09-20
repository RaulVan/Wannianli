import AppKit
import EventKit

@MainActor
final class LocalCalendarStore: ObservableObject {
    enum AccessState: Equatable {
        case notDetermined
        case requesting
        case granted
        case denied
        case restricted
        case failed(String)
    }

    @Published private(set) var events: [LocalCalendarEvent] = []
    @Published private(set) var accessState: AccessState = .notDetermined

    private let eventStore: EKEventStore
    private var selectedDate: CivilDate?
    private var observers: [NSObjectProtocol] = []

    init(eventStore: EKEventStore = EKEventStore()) {
        self.eventStore = eventStore
        updateAuthorizationState()
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    func start(for date: CivilDate, requestAccess shouldRequestAccess: Bool = true) {
        selectedDate = date
        guard observers.isEmpty else {
            Task { await reload(for: date, requestAccess: shouldRequestAccess) }
            return
        }

        eventStore.refreshSourcesIfNecessary()
        observers.append(NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: eventStore,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.reloadSelectedDate() }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.reloadSelectedDate(requestAccess: false) }
        })

        Task { await reload(for: date, requestAccess: shouldRequestAccess) }
    }

    func reload(for date: CivilDate, requestAccess shouldRequestAccess: Bool = false) async {
        selectedDate = date
        updateAuthorizationState()

        if accessState == .notDetermined, shouldRequestAccess {
            await requestAccess()
        }
        guard accessState == .granted else {
            events = []
            return
        }

        let interval = Self.dayInterval(for: date)
        let predicate = eventStore.predicateForEvents(
            withStart: interval.start,
            end: interval.end,
            calendars: nil
        )
        events = eventStore.events(matching: predicate)
            .filter { $0.status != .canceled }
            .sorted {
                if $0.isAllDay != $1.isAllDay { return $0.isAllDay }
                return $0.compareStartDate(with: $1) == .orderedAscending
            }
            .map { event in
                LocalCalendarEvent(
                    id: "\(event.eventIdentifier ?? UUID().uuidString)-\(event.startDate.timeIntervalSinceReferenceDate)",
                    title: event.title?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "无标题事件",
                    startDate: event.startDate,
                    endDate: event.endDate,
                    isAllDay: event.isAllDay,
                    calendarTitle: event.calendar.title,
                    calendarColor: event.calendar.color,
                    location: event.location?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
                )
            }
    }

    func requestAccess() async {
        guard accessState == .notDetermined || accessState == .denied else { return }
        if accessState == .denied {
            openCalendarPrivacySettings()
            return
        }

        accessState = .requesting
        let result: Result<Bool, Error> = await withCheckedContinuation { continuation in
            eventStore.requestFullAccessToEvents { granted, error in
                if let error { continuation.resume(returning: .failure(error)) }
                else { continuation.resume(returning: .success(granted)) }
            }
        }
        switch result {
        case .success(true):
            accessState = .granted
            await reloadSelectedDate(requestAccess: false)
        case .success(false):
            updateAuthorizationState()
        case .failure(let error):
            accessState = .failed(error.localizedDescription)
            events = []
        }
    }

    func openCalendarPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") else { return }
        NSWorkspace.shared.open(url)
    }

    static func dayInterval(for date: CivilDate, timeZone: TimeZone = .current) -> DateInterval {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let start = calendar.date(from: DateComponents(year: date.year, month: date.month, day: date.day))!
        return DateInterval(start: start, end: calendar.date(byAdding: .day, value: 1, to: start)!)
    }

    private func reloadSelectedDate(requestAccess: Bool = false) async {
        guard let selectedDate else { return }
        await reload(for: selectedDate, requestAccess: requestAccess)
    }

    private func updateAuthorizationState() {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess, .authorized: accessState = .granted
        case .writeOnly: accessState = .denied
        case .denied: accessState = .denied
        case .restricted: accessState = .restricted
        case .notDetermined: accessState = .notDetermined
        @unknown default: accessState = .restricted
        }
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
