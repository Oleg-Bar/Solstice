import AppKit

@main
enum SolsticeApp {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = SolsticeAppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
        withExtendedLifetime(delegate) {}
    }
}

@MainActor
final class SolsticeAppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: NSWindow!
    private var statusLabel: NSTextField!
    private var installButton: NSButton!
    private var uninstallButton: NSButton!
    private var lockButton: NSButton!
    private let fm = FileManager.default

    private var russian: Bool {
        Locale.preferredLanguages.first?.lowercased().hasPrefix("ru") == true
    }

    private var saverDirectory: URL {
        fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Screen Savers", isDirectory: true)
    }

    private var installedSaver: URL {
        saverDirectory.appendingPathComponent("Solstice.saver", isDirectory: true)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let size = NSSize(width: 720, height: 520)
        window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Solstice"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()

        let effect = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        effect.material = .underWindowBackground
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.autoresizingMask = [.width, .height]
        window.contentView = effect

        let hero = NSImageView(frame: NSRect(x: 0, y: 260, width: 720, height: 260))
        hero.image = NSImage(named: "SolsticeThumbnail")
        hero.imageScaling = .scaleProportionallyUpOrDown
        hero.imageAlignment = .alignCenter
        hero.wantsLayer = true
        hero.layer?.masksToBounds = true
        effect.addSubview(hero)

        let title = label("Solstice", size: 30, weight: .semibold)
        title.frame = NSRect(x: 44, y: 211, width: 632, height: 40)
        effect.addSubview(title)

        let subtitleText = russian
            ? "Живая Земля, Луна и время ваших городов — прямо на экране Mac."
            : "The living Earth, Moon, and the time of your cities — on your Mac."
        let subtitle = label(subtitleText, size: 14, weight: .regular)
        subtitle.textColor = .secondaryLabelColor
        subtitle.frame = NSRect(x: 44, y: 177, width: 632, height: 26)
        effect.addSubview(subtitle)

        statusLabel = label("", size: 12, weight: .regular)
        statusLabel.textColor = .tertiaryLabelColor
        statusLabel.frame = NSRect(x: 44, y: 139, width: 632, height: 22)
        effect.addSubview(statusLabel)

        let preview = button(russian ? "Предпросмотр" : "Preview", action: #selector(showPreview))
        preview.frame = NSRect(x: 44, y: 86, width: 126, height: 36)
        effect.addSubview(preview)

        lockButton = button(russian ? "Запустить и заблокировать" : "Start and Lock", action: #selector(startAndLock))
        lockButton.frame = NSRect(x: 178, y: 86, width: 210, height: 36)
        effect.addSubview(lockButton)

        let settings = button(russian ? "Настройки…" : "Settings…", action: #selector(openSettings))
        settings.frame = NSRect(x: 396, y: 86, width: 120, height: 36)
        effect.addSubview(settings)

        uninstallButton = button(russian ? "Удалить полностью…" : "Uninstall Completely…", action: #selector(confirmUninstall))
        uninstallButton.frame = NSRect(x: 44, y: 38, width: 174, height: 36)
        effect.addSubview(uninstallButton)

        installButton = button(russian ? "Установить" : "Install", action: #selector(install))
        installButton.keyEquivalent = "\r"
        installButton.frame = NSRect(x: 488, y: 38, width: 188, height: 36)
        effect.addSubview(installButton)

        refreshState()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        refreshState()
    }

    private func label(_ text: String, size: CGFloat, weight: NSFont.Weight) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .systemFont(ofSize: size, weight: weight)
        field.lineBreakMode = .byTruncatingTail
        return field
    }

    private func button(_ title: String, action: Selector) -> NSButton {
        let result = NSButton(title: title, target: self, action: action)
        result.bezelStyle = .rounded
        return result
    }

    private func refreshState() {
        guard statusLabel != nil else { return }
        let installed = fm.fileExists(atPath: installedSaver.path)
        statusLabel.stringValue = installed
            ? (russian ? "Заставка Solstice установлена" : "The Solstice screen saver is installed")
            : (russian ? "Заставка Solstice ещё не установлена" : "The Solstice screen saver is not installed yet")
        installButton.title = installed
            ? (russian ? "Переустановить" : "Reinstall")
            : (russian ? "Установить" : "Install")
        lockButton.isEnabled = installed
        uninstallButton.isEnabled = installed || hasProductData || isInstalledApplication
    }

    @objc private func showPreview() {
        guard let app = Bundle.main.url(forResource: "Solstice Preview", withExtension: "app") else {
            showError(russian ? "Файл предпросмотра не найден." : "The preview application could not be found.")
            return
        }
        NSWorkspace.shared.openApplication(at: app, configuration: .init())
    }

    /// Starts the selected system screen saver. With macOS configured to require
    /// a password immediately after the saver begins, this is the supported way
    /// to show Solstice first and still return to a protected session.
    @objc private func startAndLock() {
        guard fm.fileExists(atPath: installedSaver.path) else {
            showError(russian ? "Сначала установите заставку Solstice." : "Install the Solstice screen saver first.")
            return
        }
        let systemEngine = URL(fileURLWithPath: "/System/Library/CoreServices/ScreenSaverEngine.app", isDirectory: true)
        guard fm.fileExists(atPath: systemEngine.path) else {
            showError(russian ? "Системный механизм заставки не найден." : "The system screen saver engine could not be found.")
            return
        }
        // Let the initiating mouse-up event finish before the engine appears;
        // otherwise ScreenSaverEngine interprets that same click as a request to exit.
        NSApp.hide(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            NSWorkspace.shared.openApplication(at: systemEngine, configuration: configuration) { _, error in
                if let error {
                    Task { @MainActor in self?.showError(error.localizedDescription) }
                }
            }
        }
    }

    @objc private func openSettings() {
        let urls = [
            URL(string: "x-apple.systempreferences:com.apple.ScreenSaver-Settings.extension"),
            URL(string: "x-apple.systempreferences:com.apple.preference.desktopscreeneffect")
        ].compactMap { $0 }
        if let url = urls.first { NSWorkspace.shared.open(url) }
    }

    @objc private func install() {
        guard let source = Bundle.main.url(forResource: "Solstice", withExtension: "saver") else {
            showError(russian ? "Файл заставки не найден." : "The screen saver could not be found.")
            return
        }
        let staging = saverDirectory.appendingPathComponent(".Solstice-\(UUID().uuidString).saver", isDirectory: true)
        do {
            try fm.createDirectory(at: saverDirectory, withIntermediateDirectories: true)
            try fm.copyItem(at: source, to: staging)
            if fm.fileExists(atPath: installedSaver.path) {
                _ = try fm.replaceItemAt(installedSaver, withItemAt: staging)
            } else {
                try fm.moveItem(at: staging, to: installedSaver)
            }
            stopLoadedScreenSaverCopies()
            refreshState()
            let alert = NSAlert()
            alert.alertStyle = .informational
            alert.messageText = russian ? "Solstice установлена" : "Solstice is installed"
            alert.informativeText = russian
                ? "Откроются настройки заставки macOS. Выберите Solstice в разделе «Другие»."
                : "macOS Screen Saver settings will open. Select Solstice in the Other section."
            alert.addButton(withTitle: russian ? "Открыть настройки" : "Open Settings")
            alert.addButton(withTitle: russian ? "Готово" : "Done")
            alert.beginSheetModal(for: window) { [weak self] response in
                if response == .alertFirstButtonReturn { self?.openSettings() }
            }
        } catch {
            try? fm.removeItem(at: staging)
            showError(error.localizedDescription)
        }
    }

    @objc private func confirmUninstall() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = russian ? "Удалить Solstice полностью?" : "Uninstall Solstice completely?"
        alert.informativeText = russian
            ? "Заставка, её настройки и служебные данные будут удалены. Приложение Solstice будет перемещено в Корзину, если оно запущено из папки «Программы»."
            : "The screen saver, its settings, and support data will be removed. The Solstice app will be moved to Trash if it is running from Applications."
        alert.addButton(withTitle: russian ? "Удалить" : "Uninstall")
        alert.addButton(withTitle: russian ? "Отмена" : "Cancel")
        alert.buttons.first?.hasDestructiveAction = true
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            self?.uninstall()
        }
    }

    private var productDataURLs: [URL] {
        let library = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library", isDirectory: true)
        let identifiers = ["studio.terra.shared", "studio.terra.preview", "studio.terra.screensaver", "studio.solstice.app"]
        var urls = [
            installedSaver,
            saverDirectory.appendingPathComponent("Terra.saver", isDirectory: true)
        ]
        urls += identifiers.map { library.appendingPathComponent("Preferences/\($0).plist") }
        urls += identifiers.map { library.appendingPathComponent("Caches/\($0)", isDirectory: true) }
        urls += identifiers.map { library.appendingPathComponent("Saved Application State/\($0).savedState", isDirectory: true) }
        urls += [
            library.appendingPathComponent("Application Support/Solstice", isDirectory: true),
            library.appendingPathComponent("Application Support/studio.solstice.app", isDirectory: true),
            fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications/Terra Preview.app", isDirectory: true),
            fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications/Solstice Preview.app", isDirectory: true),
            fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications/Install Solstice.app", isDirectory: true)
        ]
        return urls
    }

    private var hasProductData: Bool {
        productDataURLs.contains { fm.fileExists(atPath: $0.path) }
    }

    private var isInstalledApplication: Bool {
        let app = Bundle.main.bundleURL.standardizedFileURL
        let systemApplications = URL(fileURLWithPath: "/Applications", isDirectory: true).standardizedFileURL
        let userApplications = fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true).standardizedFileURL
        return app.path.hasPrefix(systemApplications.path + "/") || app.path.hasPrefix(userApplications.path + "/")
    }

    private func uninstall() {
        do {
            stopProductProcessesForRemoval()
            for domain in ["studio.terra.shared", "studio.terra.preview", "studio.terra.screensaver", "studio.solstice.app"] {
                UserDefaults.standard.removePersistentDomain(forName: domain)
            }
            for url in productDataURLs where fm.fileExists(atPath: url.path) {
                try fm.removeItem(at: url)
            }
        } catch {
            showError(error.localizedDescription)
            return
        }

        if isInstalledApplication {
            let application = Bundle.main.bundleURL
            NSWorkspace.shared.recycle([application]) { [weak self] _, error in
                Task { @MainActor in
                    if let error {
                        self?.showError(error.localizedDescription)
                    } else {
                        NSApp.terminate(nil)
                    }
                }
            }
        } else {
            refreshState()
            let alert = NSAlert()
            alert.alertStyle = .informational
            alert.messageText = russian ? "Solstice удалена" : "Solstice was removed"
            alert.informativeText = russian
                ? "Заставка и её данные удалены. Эта копия приложения запущена не из папки «Программы», поэтому её нужно закрыть и удалить вручную."
                : "The screen saver and its data were removed. This app copy is not running from Applications, so close and delete it manually."
            alert.addButton(withTitle: russian ? "Готово" : "Done")
            alert.beginSheetModal(for: window)
        }
    }

    /// Tahoe can retain legacy saver extension processes after an update. Ask
    /// only those system hosts to quit so the next preview loads this bundle.
    private func stopLoadedScreenSaverCopies() {
        let identifier = "com.apple.ScreenSaver.Engine.legacyScreenSaver"
        for application in NSRunningApplication.runningApplications(withBundleIdentifier: identifier) {
            _ = application.terminate()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if !application.isTerminated { _ = application.forceTerminate() }
            }
        }
    }

    private func stopProductProcessesForRemoval() {
        let identifiers = ["com.apple.ScreenSaver.Engine.legacyScreenSaver", "studio.terra.preview"]
        for identifier in identifiers {
            for application in NSRunningApplication.runningApplications(withBundleIdentifier: identifier) {
                _ = application.forceTerminate()
            }
        }
    }

    private func showError(_ text: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = russian ? "Не удалось выполнить операцию" : "The operation could not be completed"
        alert.informativeText = text
        alert.beginSheetModal(for: window)
    }

    func windowWillClose(_ notification: Notification) { NSApp.terminate(nil) }
}
