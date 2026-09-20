import AppKit
import SwiftUI
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSPopoverDelegate {
    private var state: CalendarState!
    private var holidays: HolidayStore!
    private let calendarEvents = LocalCalendarStore()
    private let updater = AppUpdater()
    private var mainWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var menuController: NSHostingController<MenuCalendar>?
    private var subscriptions: Set<AnyCancellable> = []
    private var localDismissMonitor: Any?
    private var globalDismissMonitor: Any?
    private var resignActiveObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let args = ProcessInfo.processInfo.arguments
        #if DEBUG
        let testing = args.contains("--ui-testing")
        #else
        let testing = false
        #endif
        let defaults = testing ? UserDefaults(suiteName: "local.Calendar.UITests.Settings")! : .standard
        if testing { defaults.removePersistentDomain(forName: "local.Calendar.UITests.Settings") }
        let requestedFixedToday = args.firstIndex(of: "--fixed-today").flatMap { index in
            args.indices.contains(index + 1) ? CivilDate(iso: args[index + 1]) : nil
        }
        // A fixed date is test-only and must be explicit; normal launches always use the system date.
        let fixed = testing ? requestedFixedToday : nil
        state = CalendarState(defaults: defaults, fixedToday: fixed)
        if testing { state.appearance = "light" }
        holidays = HolidayStore()
        makeMenus()
        makeStatusItem()
        state.startClock()
        let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        calendarEvents.start(for: state.selected, requestAccess: !testing && !isRunningTests)
        state.$selected.removeDuplicates().dropFirst().sink { [weak self] date in
            guard let self else { return }
            Task { await self.calendarEvents.reload(for: date) }
        }.store(in: &subscriptions)
        showMainWindow()
        #if DEBUG
        if testing && args.contains("--dark") { state.appearance = "dark" }
        if testing && args.contains("--show-menu") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.togglePopover() }
        }
        if testing && args.contains("--show-settings") { showSettings() }
        if testing && args.contains("--minimum-window") {
            mainWindow?.setContentSize(NSSize(width: 920, height: 720))
        }
        #endif
        if !testing { Task { await holidays.refresh(year: state.year) } }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) { removePopoverDismissalMonitors() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    @objc func showMainWindow() {
        closePopover()
        if mainWindow == nil {
            let content = CalendarWindow(state: state, holidays: holidays, calendarEvents: calendarEvents,
                                         openSettings: { [weak self] in self?.showSettings() })
            let hosting = NSHostingView(rootView: content)
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: Design.windowWidth, height: Design.windowHeight),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable],
                                  backing: .buffered, defer: false)
            window.title = "万年历"
            window.identifier = NSUserInterfaceItemIdentifier("calendarMainWindow")
            window.contentView = hosting
            window.minSize = NSSize(width: 920, height: 748)
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            mainWindow = window
        }
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func showSettings() {
        closePopover()
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 510, height: 510),
                                  styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "设置"
            window.contentView = NSHostingView(rootView: SettingsView(state: state, holidays: holidays, updater: updater))
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.setAccessibilityIdentifier("calendarStatusItem")
        statusItem.button?.setAccessibilityLabel("万年历菜单栏")
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        let controller = NSHostingController(rootView:
            MenuCalendar(state: state, holidays: holidays, calendarEvents: calendarEvents,
                         openWindow: { [weak self] in self?.showMainWindow() },
                         openSettings: { [weak self] in self?.showSettings() },
                         checkForUpdates: { [weak self] in self?.updater.checkForUpdates() },
                         canCheckForUpdates: updater.canCheckForUpdates))
        // Fix the final size before presentation; late intrinsic-size growth can move the popover off-screen.
        controller.sizingOptions = []
        menuController = controller
        popover.contentViewController = controller
        popover.contentSize = NSSize(width: Design.panelWidth, height: Design.panelHeight)
        state.$today.combineLatest(state.$menuFormat).sink { [weak self] date, format in
            guard let self, let button = self.statusItem.button else { return }
            self.updateApplicationIcon(for: date.day)
            let symbol = NSImage(systemSymbolName: "calendar", accessibilityDescription: "万年历")
            symbol?.isTemplate = true
            button.image = symbol
            switch format {
            case "lunar": button.title = " \(date.month)月\(date.day)日 \(self.state.engine.day(date).lunarTitle)"
            case "weekday": button.title = " \(date.month)月\(date.day)日 \(self.state.engine.day(date).weekday)"
            default: button.title = " \(date.day)"
            }
            button.toolTip = "\(date.id) \(self.state.engine.day(date).lunarTitle)"
        }.store(in: &subscriptions)
        calendarEvents.$events.combineLatest(calendarEvents.$accessState).sink { [weak self] _, _ in
            guard let self, self.popover.isShown else { return }
            self.updateMenuPanelSize()
        }.store(in: &subscriptions)
        updater.$canCheckForUpdates.removeDuplicates().sink { [weak self] _ in
            guard let self, self.popover.isShown else { return }
            self.updateMenuPanelSize()
        }.store(in: &subscriptions)
    }

    private func updateApplicationIcon(for day: Int) {
        guard let base = DynamicAppIconRenderer.bundledBaseImage(),
              let icon = DynamicAppIconRenderer.render(day: day, baseImage: base) else { return }
        NSApp.applicationIconImage = icon
        NSApp.dockTile.display()
    }

    @objc private func togglePopover() {
        if popover.isShown { closePopover(); return }
        state.refreshClock()
        // Status bar windows otherwise inherit the menu bar's appearance instead of the app preference.
        popover.appearance = NSApp.effectiveAppearance
        guard let button = statusItem.button else { return }
        let height = menuPanelHeight()
        menuController?.rootView = MenuCalendar(state: state, holidays: holidays, calendarEvents: calendarEvents,
            openWindow: { [weak self] in self?.showMainWindow() },
            openSettings: { [weak self] in self?.showSettings() },
            checkForUpdates: { [weak self] in self?.updater.checkForUpdates() },
            canCheckForUpdates: updater.canCheckForUpdates,
            panelHeight: height)
        popover.contentSize = NSSize(width: Design.panelWidth, height: height)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        installPopoverDismissalMonitors()
    }

    private func menuPanelHeight() -> CGFloat {
        let screen = statusItem.button?.window?.screen ?? NSScreen.main
        let availableHeight = max(Design.panelHeight, (screen?.visibleFrame.height ?? 800) - 32)
        let preferredHeight = MenuCalendar.preferredPanelHeight(
            eventCount: calendarEvents.events.count,
            accessState: calendarEvents.accessState
        )
        return min(preferredHeight, availableHeight)
    }

    private func updateMenuPanelSize() {
        let height = menuPanelHeight()
        menuController?.rootView = MenuCalendar(
            state: state,
            holidays: holidays,
            calendarEvents: calendarEvents,
            openWindow: { [weak self] in self?.showMainWindow() },
            openSettings: { [weak self] in self?.showSettings() },
            checkForUpdates: { [weak self] in self?.updater.checkForUpdates() },
            canCheckForUpdates: updater.canCheckForUpdates,
            panelHeight: height
        )
        popover.contentSize = NSSize(width: Design.panelWidth, height: height)
    }

    private func closePopover() {
        guard popover.isShown else {
            removePopoverDismissalMonitors()
            return
        }
        popover.performClose(nil)
    }

    private func installPopoverDismissalMonitors() {
        removePopoverDismissalMonitors()

        localDismissMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] event in
            guard let self else { return event }
            if event.type == .keyDown, event.keyCode == 53 {
                self.closePopover()
                return nil
            }
            guard event.type == .leftMouseDown || event.type == .rightMouseDown else { return event }

            if event.window === self.popover.contentViewController?.view.window { return event }
            if let button = self.statusItem.button,
               event.window === button.window,
               button.bounds.contains(button.convert(event.locationInWindow, from: nil)) {
                return event
            }
            self.closePopover()
            return event
        }

        globalDismissMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            DispatchQueue.main.async { self?.closePopover() }
        }

        resignActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: NSApp,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.closePopover() }
        }
    }

    private func removePopoverDismissalMonitors() {
        if let localDismissMonitor { NSEvent.removeMonitor(localDismissMonitor) }
        if let globalDismissMonitor { NSEvent.removeMonitor(globalDismissMonitor) }
        if let resignActiveObserver { NotificationCenter.default.removeObserver(resignActiveObserver) }
        localDismissMonitor = nil
        globalDismissMonitor = nil
        resignActiveObserver = nil
    }

    func popoverDidClose(_ notification: Notification) {
        removePopoverDismissalMonitors()
    }
    @objc private func goToday() { state.goToday() }
    @objc private func previousMonth() { state.changeMonth(-1) }
    @objc private func nextMonth() { state.changeMonth(1) }
    @objc private func previousDay() { state.moveSelection(days: -1) }
    @objc private func nextDay() { state.moveSelection(days: 1) }
    @objc private func checkForUpdates() { updater.checkForUpdates() }

    private func makeMenus() {
        let main = NSMenu()
        let appMenu = NSMenu()
        let appItem = NSMenuItem(); appItem.submenu = appMenu; main.addItem(appItem)
        appMenu.addItem(withTitle: "关于万年历", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        add(appMenu, "设置…", #selector(showSettings), ",")
        add(appMenu, "检查更新…", #selector(checkForUpdates), "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "隐藏万年历", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "退出万年历", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let calendar = NSMenu(title: "日历")
        let item = NSMenuItem(title: "日历", action: nil, keyEquivalent: ""); item.submenu = calendar; main.addItem(item)
        add(calendar, "打开完整日历", #selector(showMainWindow), "0")
        add(calendar, "显示菜单栏日历", #selector(togglePopover), "m", [.command, .shift])
        add(calendar, "今天", #selector(goToday), "t")
        add(calendar, "上个月", #selector(previousMonth), "[")
        add(calendar, "下个月", #selector(nextMonth), "]")
        add(calendar, "前一天", #selector(previousDay), String(UnicodeScalar(NSLeftArrowFunctionKey)!), [])
        add(calendar, "后一天", #selector(nextDay), String(UnicodeScalar(NSRightArrowFunctionKey)!), [])
        let windowMenu = NSMenu(title: "窗口")
        let windowItem = NSMenuItem(title: "窗口", action: nil, keyEquivalent: ""); windowItem.submenu = windowMenu; main.addItem(windowItem)
        windowMenu.addItem(withTitle: "最小化", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "关闭窗口", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        NSApp.mainMenu = main
        NSApp.windowsMenu = windowMenu
    }
    private func add(_ menu: NSMenu, _ title: String, _ action: Selector, _ key: String, _ modifiers: NSEvent.ModifierFlags = [.command]) {
        let item = menu.addItem(withTitle: title, action: action, keyEquivalent: key)
        item.target = self; item.keyEquivalentModifierMask = modifiers
    }
}
