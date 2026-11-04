import Cocoa
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let audio = AudioEngine()
    private lazy var music = Music(audio: audio)
    private lazy var keys = KeyMonitor { [weak self] key in self?.music.handle(key) }
    private var onboarding: OnboardingWindow?
    private var accessTimer: Timer?
    private let defaults = UserDefaults.standard

    private var paused = false {
        didSet {
            keys.enabled = !paused
            statusItem.button?.appearsDisabled = paused
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let icon = NSImage(systemSymbolName: "pianokeys", accessibilityDescription: "Tastenklavier")
        icon?.isTemplate = true
        statusItem.button?.image = icon
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        music.setInstrument(defaults.integer(forKey: "instrument"), announce: false)
        music.setSong(defaults.integer(forKey: "song"), announce: false)
        audio.volume = defaults.object(forKey: "volume") as? Float ?? 0.8

        startListening()
    }

    // MARK: Tastaturzugriff

    private func startListening() {
        if KeyMonitor.hasAccess && keys.start() { return }
        showOnboarding()
        KeyMonitor.requestAccess()
        accessTimer?.invalidate()
        accessTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            if KeyMonitor.hasAccess && self.keys.start() {
                timer.invalidate()
                self.onboarding?.showSuccess()
            }
        }
    }

    @objc private func showOnboarding() {
        if onboarding == nil { onboarding = OnboardingWindow() }
        onboarding?.present()
    }

    // MARK: Menü

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        menu.addItem(header("Instrument"))
        for (i, inst) in INSTRUMENTS.enumerated() {
            let item = NSMenuItem(title: inst.name, action: #selector(pickInstrument(_:)), keyEquivalent: "")
            item.target = self; item.tag = i; item.indentationLevel = 1
            item.state = i == music.instrumentIndex ? .on : .off
            menu.addItem(item)
        }
        menu.addItem(.separator())

        menu.addItem(header("Song"))
        for (i, song) in SONGS.enumerated() {
            let item = NSMenuItem(title: song.name, action: #selector(pickSong(_:)), keyEquivalent: "")
            item.target = self; item.tag = i; item.indentationLevel = 1
            item.state = i == music.songIndex ? .on : .off
            menu.addItem(item)
        }
        menu.addItem(.separator())

        menu.addItem(header("Lautstärke"))
        let sliderItem = NSMenuItem()
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 26))
        let slider = NSSlider(value: Double(audio.volume), minValue: 0.05, maxValue: 1.5,
                              target: self, action: #selector(volumeChanged(_:)))
        slider.frame = NSRect(x: 20, y: 3, width: 165, height: 20)
        container.addSubview(slider)
        sliderItem.view = container
        menu.addItem(sliderItem)
        menu.addItem(.separator())

        let pause = NSMenuItem(title: "Pause", action: #selector(togglePause), keyEquivalent: "")
        pause.target = self; pause.state = paused ? .on : .off
        menu.addItem(pause)

        let login = NSMenuItem(title: "Beim Anmelden starten", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        if !keys.isRunning {
            let setup = NSMenuItem(title: "Tastaturzugriff einrichten …", action: #selector(showOnboarding), keyEquivalent: "")
            setup.target = self
            menu.addItem(setup)
        }
        if !audio.soundBankAvailable {
            let warn = NSMenuItem(title: "Instrumentenklänge fehlen auf diesem Mac", action: nil, keyEquivalent: "")
            warn.isEnabled = false
            menu.addItem(warn)
        }
        menu.addItem(.separator())

        let about = NSMenuItem(title: "Über Tastenklavier", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)
        menu.addItem(NSMenuItem(title: "Beenden", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    private func header(_ title: String) -> NSMenuItem {
        if #available(macOS 14.0, *) { return NSMenuItem.sectionHeader(title: title) }
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    @objc private func pickInstrument(_ sender: NSMenuItem) {
        music.setInstrument(sender.tag)
        defaults.set(sender.tag, forKey: "instrument")
    }

    @objc private func pickSong(_ sender: NSMenuItem) {
        music.setSong(sender.tag)
        defaults.set(sender.tag, forKey: "song")
    }

    @objc private func volumeChanged(_ sender: NSSlider) {
        audio.volume = Float(sender.doubleValue)
        defaults.set(audio.volume, forKey: "volume")
    }

    @objc private func togglePause() { paused.toggle() }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
        } catch {
            NSLog("Tastenklavier: Anmeldeobjekt nicht geändert: \(error)")
        }
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        let credits = NSAttributedString(
            string: "Jede Taste ein Ton.\nTastenklavier hört nur zu, um Töne zu spielen. Es speichert und sendet nichts und nutzt kein Internet.",
            attributes: [.font: NSFont.systemFont(ofSize: 11)])
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }
}
