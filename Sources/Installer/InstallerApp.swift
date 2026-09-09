import AppKit

@main
enum SolsticeInstallerApp {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = InstallerDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
        withExtendedLifetime(delegate) {}
    }
}

@MainActor
final class InstallerDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: NSWindow!
    private var statusLabel: NSTextField!
    private let fm = FileManager.default

    private var russian: Bool {
        Locale.preferredLanguages.first?.lowercased().hasPrefix("ru") == true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.applicationIconImage = NSImage(named: "Hero")
        let size = NSSize(width: 720, height: 520)
        window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = russian ? "Установка Solstice" : "Install Solstice"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()

        let effect = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        effect.material = .underWindowBackground
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.autoresizingMask = [.width, .height]
        window.contentView = effect

        let hero = NSImageView(frame: NSRect(x: 0, y: 220, width: 720, height: 300))
        hero.image = NSImage(named: "Hero")
        hero.imageScaling = .scaleProportionallyUpOrDown
        hero.imageAlignment = .alignCenter
        hero.wantsLayer = true
        hero.layer?.masksToBounds = true
        effect.addSubview(hero)

        let title = label("Solstice", size: 30, weight: .semibold)
        title.frame = NSRect(x: 44, y: 166, width: 632, height: 40)
        effect.addSubview(title)

        let subtitleText = russian
            ? "Живая Земля, Луна и время ваших городов — прямо на экране Mac."
            : "The living Earth, Moon, and the time of your cities — on your Mac."
        let subtitle = label(subtitleText, size: 14, weight: .regular)
        subtitle.textColor = .secondaryLabelColor
        subtitle.frame = NSRect(x: 44, y: 132, width: 632, height: 26)
        effect.addSubview(subtitle)

        statusLabel = label(russian ? "Готово к установке на этот Mac" : "Ready to install on this Mac", size: 12, weight: .regular)
        statusLabel.textColor = .tertiaryLabelColor
        statusLabel.frame = NSRect(x: 44, y: 91, width: 430, height: 22)
        effect.addSubview(statusLabel)

        let preview = NSButton(title: russian ? "Предпросмотр" : "Preview", target: self, action: #selector(showPreview))
        preview.bezelStyle = .rounded
        preview.frame = NSRect(x: 432, y: 38, width: 116, height: 36)
        effect.addSubview(preview)

        let install = NSButton(title: russian ? "Установить" : "Install", target: self, action: #selector(install))
        install.bezelStyle = .rounded
        install.keyEquivalent = "\r"
        install.frame = NSRect(x: 556, y: 38, width: 120, height: 36)
        effect.addSubview(install)

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func label(_ text: String, size: CGFloat, weight: NSFont.Weight) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .systemFont(ofSize: size, weight: weight)
        field.lineBreakMode = .byTruncatingTail
        return field
    }

    @objc private func showPreview() {
        guard let app = Bundle.main.url(forResource: "Solstice Preview", withExtension: "app") else {
            showError(russian ? "Файл предпросмотра не найден." : "The preview application could not be found.")
            return
        }
        NSWorkspace.shared.openApplication(at: app, configuration: .init())
    }

    @objc private func install() {
        guard let source = Bundle.main.url(forResource: "Solstice", withExtension: "saver") else {
            showError(russian ? "Файл заставки не найден." : "The screen saver could not be found.")
            return
        }
        let directory = fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Screen Savers", isDirectory: true)
        let destination = directory.appendingPathComponent("Solstice.saver", isDirectory: true)
        do {
            try fm.createDirectory(at: directory, withIntermediateDirectories: true)
            if fm.fileExists(atPath: destination.path) {
                try fm.removeItem(at: destination)
            }
            try fm.copyItem(at: source, to: destination)
            statusLabel.stringValue = russian ? "Solstice установлена успешно" : "Solstice was installed successfully"
            let alert = NSAlert()
            alert.alertStyle = .informational
            alert.messageText = russian ? "Solstice установлена" : "Solstice is installed"
            alert.informativeText = russian
                ? "Откроются настройки заставки macOS. Выберите Solstice в списке."
                : "macOS Screen Saver settings will open. Select Solstice from the list."
            alert.addButton(withTitle: russian ? "Открыть настройки" : "Open Settings")
            alert.addButton(withTitle: russian ? "Готово" : "Done")
            alert.beginSheetModal(for: window) { response in
                if response == .alertFirstButtonReturn {
                    let urls = [
                        URL(string: "x-apple.systempreferences:com.apple.ScreenSaver-Settings.extension"),
                        URL(string: "x-apple.systempreferences:com.apple.preference.desktopscreeneffect")
                    ].compactMap { $0 }
                    if let url = urls.first { NSWorkspace.shared.open(url) }
                }
            }
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func showError(_ text: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = russian ? "Не удалось установить Solstice" : "Solstice could not be installed"
        alert.informativeText = text
        alert.beginSheetModal(for: window)
    }

    func windowWillClose(_ notification: Notification) { NSApp.terminate(nil) }
}
