import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Observation

/// Registers global shortcuts.
///
/// * Key + modifier combos use Carbon `RegisterEventHotKey` (works without any permission).
/// * Modifier-only combos (e.g. ⌃⇧) use `NSEvent` global monitors for `flagsChanged`,
///   which only receive events once the app has Accessibility access. They fire when all
///   modifiers are released, no other key/click happened in between and the press was short.
@MainActor
@Observable
final class HotkeyManager {
    static let shared = HotkeyManager()

    @ObservationIgnored var handler: ((HotkeyAction) -> Void)?
    private(set) var isAccessibilityTrusted = AXIsProcessTrusted()

    @ObservationIgnored private var bindings: [HotkeyAction: Hotkey] = [:]
    @ObservationIgnored private var carbonRefs: [EventHotKeyRef] = []
    @ObservationIgnored private var carbonActions: [UInt32: HotkeyAction] = [:]
    @ObservationIgnored private var carbonHandler: EventHandlerRef?
    @ObservationIgnored private var monitors: [Any] = []
    @ObservationIgnored private var trustTimer: Timer?
    @ObservationIgnored private var paused = false

    // Modifier-only tracking
    @ObservationIgnored private var peakFlags: NSEvent.ModifierFlags = []
    @ObservationIgnored private var sequenceInterrupted = false
    @ObservationIgnored private var sequenceStart = Date()
    /// Carbon hotkeys and NSEvent monitors are delivered through different paths, so a Carbon
    /// hotkey (e.g. ⌃⇧⌫) can arrive *before* the flagsChanged event of its own modifiers.
    /// Remembering when it fired lets the release check catch that case.
    @ObservationIgnored private var lastCarbonFire = Date.distantPast
    private let maxModifierTapDuration: TimeInterval = 1.0

    private static let signature: OSType = 0x5449_434B // 'TICK'

    var needsAccessibility: Bool { bindings.values.contains(where: \.isModifierOnly) }

    func apply(_ bindings: [HotkeyAction: Hotkey]) {
        self.bindings = bindings
        guard !paused else { return }
        registerCarbon()
        installMonitors()
    }

    /// Temporarily disables all shortcuts (used while recording a new one).
    func pause() {
        paused = true
        unregisterCarbon()
        removeMonitors()
    }

    func resume() {
        paused = false
        apply(bindings)
    }

    func requestAccessibility() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        isAccessibilityTrusted = AXIsProcessTrustedWithOptions(options)
        startTrustPolling()
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        startTrustPolling()
    }

    // MARK: Carbon

    private func registerCarbon() {
        unregisterCarbon()
        if carbonHandler == nil {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), carbonHotKeyCallback, 1, &spec, nil, &carbonHandler)
        }
        var nextID: UInt32 = 1
        for (action, hotkey) in bindings {
            guard let keyCode = hotkey.keyCode else { continue }
            var ref: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(signature: Self.signature, id: nextID)
            let status = RegisterEventHotKey(UInt32(keyCode), hotkey.carbonModifiers, hotKeyID,
                                             GetApplicationEventTarget(), 0, &ref)
            if status == noErr, let ref {
                carbonRefs.append(ref)
                carbonActions[nextID] = action
            } else {
                NSLog("Ticker: could not register hotkey \(hotkey.displayString) (status \(status))")
            }
            nextID += 1
        }
    }

    private func unregisterCarbon() {
        carbonRefs.forEach { UnregisterEventHotKey($0) }
        carbonRefs.removeAll()
        carbonActions.removeAll()
    }

    fileprivate func carbonHotKeyPressed(id: UInt32) {
        // A key combo was pressed while modifiers are held: that is not a modifier-only tap.
        sequenceInterrupted = true
        lastCarbonFire = Date()
        if let action = carbonActions[id] { handler?(action) }
    }

    // MARK: Modifier-only monitors

    private func installMonitors() {
        removeMonitors()
        guard needsAccessibility else { return }
        isAccessibilityTrusted = AXIsProcessTrusted()
        if !isAccessibilityTrusted { startTrustPolling() }

        let interrupting: NSEvent.EventTypeMask = [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel]
        if let m = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: { [weak self] e in
            MainActor.assumeIsolated { self?.handleFlags(e.modifierFlags) }
        }) { monitors.append(m) }
        if let m = NSEvent.addGlobalMonitorForEvents(matching: interrupting, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.sequenceInterrupted = true }
        }) { monitors.append(m) }
        // Local monitors so shortcuts also work while one of our own windows is focused.
        if let m = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: { [weak self] e in
            MainActor.assumeIsolated { self?.handleFlags(e.modifierFlags) }
            return e
        }) { monitors.append(m) }
        if let m = NSEvent.addLocalMonitorForEvents(matching: interrupting, handler: { [weak self] e in
            MainActor.assumeIsolated { self?.sequenceInterrupted = true }
            return e
        }) { monitors.append(m) }
    }

    private func removeMonitors() {
        monitors.forEach { NSEvent.removeMonitor($0) }
        monitors.removeAll()
        peakFlags = []
    }

    private func handleFlags(_ rawFlags: NSEvent.ModifierFlags) {
        let flags = rawFlags.intersection(Hotkey.relevantModifiers)
        if flags.isEmpty {
            defer { peakFlags = []; sequenceInterrupted = false }
            guard !peakFlags.isEmpty, !sequenceInterrupted,
                  lastCarbonFire < sequenceStart.addingTimeInterval(-0.25),
                  Date().timeIntervalSince(sequenceStart) <= maxModifierTapDuration else { return }
            for (action, hotkey) in bindings where hotkey.isModifierOnly && hotkey.modifiers == peakFlags {
                handler?(action)
            }
        } else {
            if peakFlags.isEmpty {
                sequenceStart = Date()
                sequenceInterrupted = false
            }
            peakFlags.formUnion(flags)
        }
    }

    // MARK: Accessibility polling

    private func startTrustPolling() {
        guard trustTimer == nil else { return }
        trustTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let trusted = AXIsProcessTrusted()
                if trusted != self.isAccessibilityTrusted {
                    self.isAccessibilityTrusted = trusted
                    // Monitors created before access was granted stay deaf: re-create them.
                    if !self.paused { self.installMonitors() }
                }
                if trusted {
                    self.trustTimer?.invalidate()
                    self.trustTimer = nil
                }
            }
        }
    }
}

private func carbonHotKeyCallback(_: EventHandlerCallRef?, _ event: EventRef?, _: UnsafeMutableRawPointer?) -> OSStatus {
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                   nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
    guard status == noErr else { return status }
    let id = hotKeyID.id
    MainActor.assumeIsolated { HotkeyManager.shared.carbonHotKeyPressed(id: id) }
    return noErr
}
