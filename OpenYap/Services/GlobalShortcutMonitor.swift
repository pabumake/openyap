import AppKit
import CoreGraphics

@MainActor
final class GlobalShortcutMonitor {
    static var hasInputMonitoringAccess: Bool { CGPreflightListenEventAccess() }

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var shortcut: ShortcutDefinition
    private let action: () -> Void

    init(shortcut: ShortcutDefinition, action: @escaping () -> Void) {
        self.shortcut = shortcut
        self.action = action
    }

    @discardableResult
    static func requestInputMonitoringAccess() -> Bool {
        CGRequestListenEventAccess()
    }

    func update(shortcut: ShortcutDefinition) {
        self.shortcut = shortcut
    }

    @discardableResult
    func start() -> Bool {
        stop()
        guard Self.hasInputMonitoringAccess else { return false }

        let mask = CGEventMask(1) << CGEventType.keyDown.rawValue
            | CGEventMask(1) << CGEventType.flagsChanged.rawValue
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: openYapShortcutCallback,
            userInfo: context
        ) else {
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        self.eventTap = eventTap
        runLoopSource = source
        return true
    }

    func stop() {
        if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: false) }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    fileprivate func receive(
        type: CGEventType,
        keyCode: UInt16,
        flagsRawValue: UInt64,
        isRepeat: Bool
    ) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
            return
        }

        let eventKind: ShortcutEventKind
        switch type {
        case .keyDown: eventKind = .keyDown
        case .flagsChanged: eventKind = .flagsChanged
        default: return
        }

        let modifiers = Self.modifiers(from: CGEventFlags(rawValue: flagsRawValue))
        guard shortcut.matches(
            keyCode: keyCode,
            eventKind: eventKind,
            modifiers: modifiers,
            isRepeat: isRepeat
        ) else {
            return
        }
        action()
    }

    private static func modifiers(from flags: CGEventFlags) -> NSEvent.ModifierFlags {
        var modifiers: NSEvent.ModifierFlags = []
        if flags.contains(.maskCommand) { modifiers.insert(.command) }
        if flags.contains(.maskAlternate) { modifiers.insert(.option) }
        if flags.contains(.maskControl) { modifiers.insert(.control) }
        if flags.contains(.maskShift) { modifiers.insert(.shift) }
        if flags.contains(.maskSecondaryFn) { modifiers.insert(.function) }
        return modifiers
    }
}

private func openYapShortcutCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let monitor = Unmanaged<GlobalShortcutMonitor>.fromOpaque(userInfo).takeUnretainedValue()
    let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
    let flagsRawValue = event.flags.rawValue
    let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
    MainActor.assumeIsolated {
        monitor.receive(
            type: type,
            keyCode: keyCode,
            flagsRawValue: flagsRawValue,
            isRepeat: isRepeat
        )
    }
    return Unmanaged.passUnretained(event)
}
