import AppKit
import Combine

@MainActor
final class CalendarState: ObservableObject {
    @Published var selected: CivilDate
    @Published var year: Int
    @Published var month: Int
    @Published private(set) var today: CivilDate
    @Published var mondayFirst: Bool { didSet { defaults.set(mondayFirst, forKey: "mondayFirst") } }
    @Published var appearance: String { didSet { defaults.set(appearance, forKey: "appearance"); applyAppearance() } }
    @Published var menuFormat: String { didSet { defaults.set(menuFormat, forKey: "menuFormat") } }
    let engine = CalendarEngine()
    private let defaults: UserDefaults
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private let fixedToday: CivilDate?

    init(defaults: UserDefaults = .standard, now: Date = Date(), fixedToday: CivilDate? = nil) {
        self.defaults = defaults
        self.fixedToday = fixedToday
        let civil = fixedToday ?? CivilDate(now)
        today = civil; selected = civil; year = civil.year; month = civil.month
        mondayFirst = defaults.object(forKey: "mondayFirst") as? Bool ?? true
        appearance = defaults.string(forKey: "appearance") ?? "system"
        menuFormat = defaults.string(forKey: "menuFormat") ?? "icon"
    }

    var days: [AlmanacDay] { engine.month(year: year, month: month, mondayFirst: mondayFirst) }
    var detail: AlmanacDay { engine.day(selected) }
    var upcoming: (name: String, date: CivilDate)? { engine.nextFestival(after: today) }
    var canGoBack: Bool { year > 1901 || month > 1 }
    var canGoForward: Bool { year < 2100 || month < 12 }

    func select(_ date: CivilDate) {
        guard date.supported else { return }
        selected = date; year = date.year; month = date.month
    }
    func goToday(now: Date = Date()) { refreshClock(now: now); select(today) }
    func changeMonth(_ delta: Int) {
        let first = CivilDate(year: year, month: month, day: 1)
        guard let date = CivilDate.calendar.date(byAdding: .month, value: delta, to: first.date) else { return }
        let civil = CivilDate(date, timeZone: .gmt)
        guard civil.supported else { return }
        setMonth(year: civil.year, month: civil.month)
    }
    func setMonth(year: Int, month: Int) {
        let first = CivilDate(year: year, month: month, day: 1)
        let lastDay = CivilDate.calendar.range(of: .day, in: .month, for: first.date)!.count
        select(CivilDate(year: year, month: month, day: min(selected.day, lastDay)))
    }
    func moveSelection(days: Int) { select(selected.adding(days: days)) }

    func startClock() {
        applyAppearance()
        for name in [Notification.Name.NSSystemTimeZoneDidChange, .NSCalendarDayChanged, NSApplication.didBecomeActiveNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.refreshClock() }
            })
        }
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refreshClock() }
        })
        scheduleMidnight()
    }

    func refreshClock(now: Date = Date()) {
        let newToday = fixedToday ?? CivilDate(now)
        let wasToday = selected == today
        if newToday != today {
            today = newToday
            if wasToday { select(newToday) }
        }
        scheduleMidnight()
    }

    private func scheduleMidnight() {
        timer?.invalidate()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let next = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!
        timer = Timer.scheduledTimer(withTimeInterval: max(1, next.timeIntervalSinceNow + 1), repeats: false) { [weak self] _ in
            Task { @MainActor in self?.refreshClock() }
        }
    }
    private func applyAppearance() {
        NSApp?.appearance = appearance == "system" ? nil : NSAppearance(named: appearance == "dark" ? .darkAqua : .aqua)
    }
}
