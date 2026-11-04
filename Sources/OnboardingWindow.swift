import Cocoa

/// Kurzes Einrichtungsfenster: erklärt die Erlaubnis «Eingabeüberwachung» und führt hin.
final class OnboardingWindow: NSWindowController {
    private let status = NSTextField(labelWithString: "")
    private let openButton = NSButton(title: "Einstellungen öffnen", target: nil, action: nil)
    private let restartButton = NSButton(title: "App neu starten", target: nil, action: nil)

    convenience init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 320),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Tastenklavier einrichten"
        window.isReleasedWhenClosed = false
        self.init(window: window)
        build()
    }

    private func build() {
        let title = NSTextField(labelWithString: "Ein Schritt noch: Zugriff auf die Tastatur")
        title.font = .systemFont(ofSize: 17, weight: .semibold)

        let body = NSTextField(wrappingLabelWithString:
            "Damit jede Taste einen Ton spielt, muss macOS erlauben, dass Tastenklavier Tastendrücke mithört. " +
            "Die App speichert und sendet nichts und nutzt kein Internet.\n\n" +
            "1.  Klick auf «Einstellungen öffnen».\n" +
            "2.  Schalte «Tastenklavier» unter «Eingabeüberwachung» ein.\n" +
            "3.  Fertig. Ein Ton bestätigt, dass es klappt.")
        body.font = .systemFont(ofSize: 13)
        body.preferredMaxLayoutWidth = 400

        status.font = .systemFont(ofSize: 12)
        status.textColor = .secondaryLabelColor
        status.stringValue = "Wartet auf die Erlaubnis …"

        openButton.target = self
        openButton.action = #selector(openSettings)
        openButton.bezelStyle = .rounded
        openButton.keyEquivalent = "\r"

        restartButton.target = self
        restartButton.action = #selector(restart)
        restartButton.bezelStyle = .rounded
        restartButton.toolTip = "Falls die Erlaubnis gesetzt ist, aber noch nichts klingt"

        let buttons = NSStackView(views: [openButton, restartButton])
        buttons.spacing = 10

        let stack = NSStackView(views: [title, body, status, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 28, bottom: 24, right: 28)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor),
        ])
        window?.contentView = content
    }

    func present() {
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    func showSuccess() {
        status.stringValue = "Geschafft. Schreib irgendwo los, das Symbol findest du oben in der Menüleiste."
        status.textColor = .systemGreen
        openButton.isHidden = true
        restartButton.isHidden = true
        NSSound(named: "Glass")?.play()
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in self?.close() }
    }

    @objc private func openSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!
        NSWorkspace.shared.open(url)
    }

    @objc private func restart() {
        let path = Bundle.main.bundlePath
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 0.8; /usr/bin/open \"\(path)\""]
        try? task.run()
        NSApp.terminate(nil)
    }
}
