import Cocoa

/// Hört systemweit auf Tastendrücke (nur lesend). Speichert und sendet nichts.
/// Braucht die Erlaubnis «Eingabeüberwachung» in den Systemeinstellungen.
final class KeyMonitor {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private let handler: (KeyKind) -> Void
    var enabled = true

    init(handler: @escaping (KeyKind) -> Void) { self.handler = handler }

    static var hasAccess: Bool { CGPreflightListenEventAccess() }
    static func requestAccess() { _ = CGRequestListenEventAccess() }

    var isRunning: Bool { tap != nil }

    @discardableResult
    func start() -> Bool {
        if tap != nil { return true }
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let me = Unmanaged.passUnretained(self).toOpaque()
        guard let t = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly,
                                        eventsOfInterest: mask,
                                        callback: { _, type, event, refcon in
                                            if let refcon {
                                                Unmanaged<KeyMonitor>.fromOpaque(refcon).takeUnretainedValue().handle(type, event)
                                            }
                                            return Unmanaged.passUnretained(event)
                                        },
                                        userInfo: me) else { return false }
        tap = t
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, t, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: t, enable: true)
        return true
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        guard enabled, type == .keyDown else { return }
        if event.getIntegerValueField(.keyboardEventAutorepeat) != 0 { return }       // gedrückt gehalten
        if event.flags.contains(.maskCommand) || event.flags.contains(.maskControl) { return } // Tastenkürzel
        switch event.getIntegerValueField(.keyboardEventKeycode) {
        case 49: handler(.space)
        case 36, 76: handler(.enter)
        case 51: handler(.back)
        default:
            var length = 0
            var chars = [UniChar](repeating: 0, count: 4)
            event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &length, unicodeString: &chars)
            guard length > 0 else { return }
            let s = String(utf16CodeUnits: chars, count: length)
            guard s.count == 1, let c = s.first else { return }
            let printable = c.unicodeScalars.allSatisfy {
                !CharacterSet.controlCharacters.contains($0) && !(0xF700...0xF8FF).contains($0.value) // Pfeile, F-Tasten
            }
            if printable && !c.isWhitespace { handler(.char(c)) }
        }
    }
}
