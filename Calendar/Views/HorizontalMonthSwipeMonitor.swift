import AppKit
import SwiftUI

struct HorizontalMonthSwipeRecognizer {
    private(set) var accumulatedX: CGFloat = 0
    private(set) var hasTriggered = false
    let threshold: CGFloat

    init(threshold: CGFloat = 45) {
        self.threshold = threshold
    }

    mutating func begin() {
        accumulatedX = 0
        hasTriggered = false
    }

    mutating func update(deltaX: CGFloat, deltaY: CGFloat) -> Int? {
        guard !hasTriggered, abs(deltaX) > abs(deltaY), abs(deltaX) > 0.5 else { return nil }
        accumulatedX += deltaX
        guard abs(accumulatedX) >= threshold else { return nil }
        hasTriggered = true
        return accumulatedX < 0 ? -1 : 1
    }

    mutating func end() {
        accumulatedX = 0
        hasTriggered = false
    }
}

struct HorizontalMonthSwipeMonitor: NSViewRepresentable {
    let onMonthChange: (Int) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onMonthChange: onMonthChange)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.monitoredView = view
        context.coordinator.installMonitor()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.monitoredView = nsView
        context.coordinator.onMonthChange = onMonthChange
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.removeMonitor()
    }

    final class Coordinator {
        weak var monitoredView: NSView?
        var onMonthChange: (Int) -> Void
        private var recognizer = HorizontalMonthSwipeRecognizer()
        private var monitor: Any?
        private var resetWorkItem: DispatchWorkItem?

        init(onMonthChange: @escaping (Int) -> Void) {
            self.onMonthChange = onMonthChange
        }

        func installMonitor() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                self?.handle(event) ?? event
            }
        }

        func removeMonitor() {
            resetWorkItem?.cancel()
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }

        private func handle(_ event: NSEvent) -> NSEvent? {
            guard let view = monitoredView,
                  event.window === view.window,
                  view.bounds.contains(view.convert(event.locationInWindow, from: nil)),
                  event.momentumPhase.isEmpty else { return event }

            if event.phase.contains(.began) { recognizer.begin() }

            // Convert AppKit's content-scrolling delta back to the physical two-finger direction.
            let physicalX = event.scrollingDeltaX * (event.isDirectionInvertedFromDevice ? -1 : 1)
            let physicalY = event.scrollingDeltaY * (event.isDirectionInvertedFromDevice ? -1 : 1)
            let isHorizontal = abs(physicalX) > abs(physicalY) && abs(physicalX) > 0.5
            if let monthDelta = recognizer.update(deltaX: physicalX, deltaY: physicalY) {
                onMonthChange(monthDelta)
            }

            scheduleResetIfNeeded(for: event)
            return isHorizontal ? nil : event
        }

        private func scheduleResetIfNeeded(for event: NSEvent) {
            resetWorkItem?.cancel()
            if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
                recognizer.end()
                return
            }
            // Some mice and older trackpads deliver scroll events without gesture phases.
            let work = DispatchWorkItem { [weak self] in self?.recognizer.end() }
            resetWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: work)
        }
    }
}
