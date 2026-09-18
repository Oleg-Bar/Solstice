import AppKit
#if SWIFT_PACKAGE
import TerraCore
import TerraScene
#endif

@main
enum PreviewApp {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = PreviewDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
        withExtendedLifetime(delegate) {}
    }
}

final class PreviewDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: NSWindow!
    private var scene: EarthSceneView!
    private var toolbar: PreviewToolbar?
    private var toolbarWindow: NSPanel?
    private var updateButton: NSButton?
    private var updateWindow: NSPanel?
    private let cityCatalog = SystemCityCatalog.load()
    func applicationDidFinishLaunching(_ notification: Notification) {
        let args = CommandLine.arguments
        scene = EarthSceneView(frame: NSRect(x: 0,y: 0,width: 1200,height: 750),preview: true)
        scene.configuration.automaticIPLocation = args.contains("--ip") || (!args.contains("--no-ip") && IPLocationConsentStore.decision == true)
        if let i = args.firstIndex(of: "--snapshot"), args.count > i+1 {
            do {
                let date: Date
                if let d = args.firstIndex(of: "--date"), args.count > d+1 {
                    guard let parsed = ISO8601DateFormatter().date(from: args[d+1]) else { throw CLIError.invalidDate }; date = parsed
                } else { date = Date() }
                var size = CGSize(width: 1440,height: 900)
                if let w = args.firstIndex(of: "--size"), args.count > w+2,
                   let width = Double(args[w+1]), let height = Double(args[w+2]), (200...5120).contains(width), (200...5120).contains(height) {
                    size = CGSize(width: width,height: height)
                }
                if let l = args.firstIndex(of: "--longitude"), args.count > l+1 { scene.longitudeOverride = Double(args[l+1]) }
                if let o = args.firstIndex(of: "--observer"), args.count > o+1 {
                    let places: [String:ObserverLocation] = ["madrid":.madrid,"singapore":.singapore,"new-york":.newYork]
                    guard let place = places[args[o+1].lowercased()] else { throw CLIError.invalidObserver }
                    scene.selectObserver(place,animated: false)
                }
                try scene.saveSnapshot(to: URL(fileURLWithPath: args[i+1]),size: size,date: date,
                    includeCaption: !args.contains("--clean"),includeUpdateGlyph: args.contains("--show-update"))
                print("Snapshot saved: \(args[i+1])")
                NSApp.terminate(nil)
            } catch { fputs("Terra render failed: \(error.localizedDescription)\n",stderr); exit(1) }
            return
        }
        window = NSWindow(contentRect: scene.frame,styleMask: [.titled,.closable,.miniaturizable,.resizable],backing: .buffered,defer: false)
        window.title = "Solstice Preview"; window.minSize = CGSize(width: 640,height: 420)
        window.contentView = scene; window.delegate = self
        let toolbar = PreviewToolbar()
        toolbar.onAddCity = { [weak self] in self?.showAddCity() }
        toolbar.onRemoveCity = { [weak self] in self?.showRemoveCity() }
        toolbar.canRemoveCity = !scene.removableCities.isEmpty
        scene.onCitySelectionChange = { [weak toolbar, weak scene] in
            toolbar?.canRemoveCity = !(scene?.removableCities.isEmpty ?? true)
        }
        self.toolbar = toolbar
        let toolbarWindow = NSPanel(contentRect: NSRect(origin: .zero,size: PreviewToolbar.preferredSize),
            styleMask: [.borderless,.nonactivatingPanel],backing: .buffered,defer: false)
        toolbar.translatesAutoresizingMaskIntoConstraints = true
        toolbar.frame = toolbarWindow.contentView?.bounds ?? NSRect(origin: .zero,size: PreviewToolbar.preferredSize)
        toolbar.autoresizingMask = [.width,.height]
        toolbarWindow.contentView = toolbar
        toolbarWindow.isOpaque = false; toolbarWindow.backgroundColor = .clear; toolbarWindow.hasShadow = false
        toolbarWindow.collectionBehavior = [.fullScreenAuxiliary]
        self.toolbarWindow = toolbarWindow
        let updateButton = NSButton(frame: NSRect(x: 0,y: 0,width: 24,height: 24))
        updateButton.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath",accessibilityDescription: "Проверить обновление")
        updateButton.imagePosition = .imageOnly
        updateButton.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 9,weight: .regular)
        updateButton.controlSize = .small
        updateButton.isBordered = true
        if #available(macOS 26.0, *) {
            updateButton.bezelStyle = .glass
        } else {
            updateButton.bezelStyle = .accessoryBarAction
        }
        updateButton.contentTintColor = .tertiaryLabelColor
        updateButton.toolTip = "Проверить обновление"
        updateButton.target = self; updateButton.action = #selector(checkForUpdates)
        let updateWindow = NSPanel(contentRect: updateButton.bounds,styleMask: [.borderless,.nonactivatingPanel],
            backing: .buffered,defer: false)
        updateWindow.contentView = updateButton
        updateWindow.isOpaque = false; updateWindow.backgroundColor = .clear; updateWindow.hasShadow = false
        updateWindow.collectionBehavior = [.fullScreenAuxiliary]
        self.updateButton = updateButton; self.updateWindow = updateWindow
        window.collectionBehavior = [.fullScreenPrimary]; window.center()
        let menu = NSMenu()
        let appItem = NSMenuItem(); let appMenu = NSMenu()
        let addCity = appMenu.addItem(withTitle: "Добавить город…",action: #selector(showAddCity),keyEquivalent: "n")
        addCity.target = self
        let removeCity = appMenu.addItem(withTitle: "Удалить город…",action: #selector(showRemoveCity),keyEquivalent: "")
        removeCity.target = self
        let locate = appMenu.addItem(withTitle: "Определить город по IP…",action: #selector(showLocationConsent),keyEquivalent: "")
        locate.target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Завершить Solstice Preview",action: #selector(NSApplication.terminate(_:)),keyEquivalent: "q")
        appItem.submenu = appMenu; menu.addItem(appItem)
        let viewItem = NSMenuItem(); viewItem.title = "Вид"; let viewMenu = NSMenu(title: "Вид")
        let fullscreen = viewMenu.addItem(withTitle: "Полный экран",action: #selector(fullScreen),keyEquivalent: "f"); fullscreen.target = self
        fullscreen.keyEquivalentModifierMask = [.command,.control]
        viewItem.submenu = viewMenu; menu.addItem(viewItem); NSApp.mainMenu = menu
        window.makeKeyAndOrderFront(nil)
        window.addChildWindow(toolbarWindow,ordered: .above)
        window.addChildWindow(updateWindow,ordered: .above)
        positionToolbar()
        NSApp.activate(ignoringOtherApps: true); scene.start()
        if !args.contains("--no-ip"), !args.contains("--ip"), IPLocationConsentStore.decision == nil {
            DispatchQueue.main.async { [weak self] in self?.showLocationConsent() }
        }
    }
    @objc private func showAddCity() {
        let alert = NSAlert()
        alert.messageText = "Добавить город"
        alert.informativeText = "Выберите город из системного списка macOS."
        alert.addButton(withTitle: "Добавить")
        alert.addButton(withTitle: "Отмена")
        let search = CitySearchView(frame: NSRect(x: 0,y: 0,width: 380,height: 206),catalog: cityCatalog)
        alert.accessoryView = search
        alert.window.initialFirstResponder = search.searchField
        alert.beginSheetModal(for: window) { [weak self, weak search] response in
            guard response == .alertFirstButtonReturn, let self, let search else { return }
            let selected = search.selectedEntry
            guard let selected else {
                self.showCityError("Выберите город из выпадающего системного списка.")
                return
            }
            if self.scene.addCity(selected.city) {
                self.toolbar?.canRemoveCity = !self.scene.removableCities.isEmpty
            } else {
                self.showCityError("Этот город уже добавлен.")
            }
        }
    }
    @objc private func showRemoveCity() {
        let cities = scene.removableCities
        guard !cities.isEmpty else {
            showCityError("Нет добавленных городов.",title: "Нечего удалять")
            return
        }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Удалить город"
        alert.informativeText = "Можно удалить любой город, кроме текущего города, определённого по IP."
        alert.addButton(withTitle: "Удалить")
        alert.addButton(withTitle: "Отмена")
        let picker = NSPopUpButton(frame: NSRect(x: 0,y: 0,width: 360,height: 28),pullsDown: false)
        picker.font = .systemFont(ofSize: 14)
        picker.addItems(withTitles: cities.map { city in
            cityCatalog.first(where: { $0.timeZoneIdentifier == city.timeZoneIdentifier })?.displayName ?? city.name
        })
        alert.accessoryView = picker
        alert.beginSheetModal(for: window) { [weak self, weak picker] response in
            guard response == .alertFirstButtonReturn, let self, let picker,
                  cities.indices.contains(picker.indexOfSelectedItem) else { return }
            if self.scene.removeCity(id: cities[picker.indexOfSelectedItem].id) {
                self.toolbar?.canRemoveCity = !self.scene.removableCities.isEmpty
            } else {
                self.showCityError("Город уже отсутствует в списке.",title: "Не удалось удалить город")
            }
        }
    }
    private func showCityError(_ text: String,title: String = "Не удалось добавить город") {
        let alert = NSAlert(); alert.alertStyle = .informational
        alert.messageText = title; alert.informativeText = text
        alert.beginSheetModal(for: window)
    }
    @objc private func checkForUpdates() {
        guard updateButton?.isEnabled == true else { return }
        updateButton?.isEnabled = false
        let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.10"
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.updateButton?.isEnabled = true }
            do {
                let release = try await UpdateChecker.latestRelease()
                let alert = NSAlert(); alert.alertStyle = .informational
                if AppVersion.isNewer(release.tagName,than: currentVersion) {
                    alert.messageText = "Доступна новая версия \(release.tagName)"
                    alert.informativeText = "Установлена Solstice \(currentVersion). Откройте страницу обновления для загрузки новой версии."
                    alert.addButton(withTitle: "Открыть обновление")
                    alert.addButton(withTitle: "Позже")
                    alert.beginSheetModal(for: self.window) { response in
                        if response == .alertFirstButtonReturn { NSWorkspace.shared.open(release.pageURL) }
                    }
                } else {
                    alert.messageText = "Установлена актуальная версия"
                    alert.informativeText = "Solstice \(currentVersion) — обновлений пока нет."
                    alert.addButton(withTitle: "Готово")
                    alert.beginSheetModal(for: self.window) { _ in }
                }
            } catch {
                let alert = NSAlert(); alert.alertStyle = .informational
                alert.messageText = "Не удалось проверить обновление"
                alert.informativeText = (error as? LocalizedError)?.errorDescription ?? "Проверьте подключение к интернету и попробуйте позже."
                alert.addButton(withTitle: "Готово")
                alert.beginSheetModal(for: self.window) { _ in }
            }
        }
    }
    @objc private func showLocationConsent() {
        let alert = NSAlert()
        alert.messageText = "Определять текущий город по IP?"
        alert.informativeText = "Для приблизительного города Solstice отправит ваш внешний IP сервису ipwho.is. Точные координаты Mac не передаются. Без разрешения останется резервный город Madrid."
        alert.addButton(withTitle: "Разрешить")
        alert.addButton(withTitle: "Не сейчас")
        alert.beginSheetModal(for: window) { [weak self] response in
            let allowed = response == .alertFirstButtonReturn
            IPLocationConsentStore.setAllowed(allowed)
            guard let self else { return }
            self.scene.configuration.automaticIPLocation = allowed
            if allowed { self.scene.refreshLocation(force: true) }
        }
    }
    @objc private func fullScreen() { window.toggleFullScreen(nil) }
    private func positionToolbar() {
        guard let toolbarWindow, let contentView = window.contentView else { return }
        let inWindow = contentView.convert(NSPoint(x: 58,y: 54),to: nil)
        toolbarWindow.setFrameOrigin(window.convertPoint(toScreen: inWindow))
        if let updateWindow {
            let textStyle: [NSAttributedString.Key:Any] = [
                .font: NSFont.systemFont(ofSize: 8,weight: .regular),
                .kern: 8*0.035
            ]
            let creditWidth = ("created by Oleg Bardakov" as NSString).size(withAttributes: textStyle).width
            let x = contentView.bounds.width-14-creditWidth-7-updateWindow.frame.width
            let updateInWindow = contentView.convert(NSPoint(x: x,y: 2),to: nil)
            updateWindow.setFrameOrigin(window.convertPoint(toScreen: updateInWindow))
        }
    }
    func windowDidMove(_ notification: Notification) { positionToolbar() }
    func windowDidResize(_ notification: Notification) { positionToolbar() }
    func windowWillClose(_ notification: Notification) {
        scene.stop()
        if let toolbarWindow { window.removeChildWindow(toolbarWindow); toolbarWindow.close() }
        if let updateWindow { window.removeChildWindow(updateWindow); updateWindow.close() }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    enum CLIError: Error { case invalidDate, invalidObserver }
}

final class CitySearchView: NSView, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    private let catalog: [SystemCityEntry]
    private(set) var matches: [SystemCityEntry]
    let searchField = NSSearchField()
    private let table = NSTableView()

    init(frame: NSRect,catalog: [SystemCityEntry]) {
        self.catalog = catalog; matches = catalog
        super.init(frame: frame)
        searchField.placeholderString = "Начните вводить название города"
        searchField.font = .systemFont(ofSize: 14)
        searchField.sendsSearchStringImmediately = true
        searchField.delegate = self
        searchField.translatesAutoresizingMaskIntoConstraints = false

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("city"))
        column.width = frame.width
        table.addTableColumn(column); table.headerView = nil
        table.rowHeight = 24; table.intercellSpacing = .zero
        table.backgroundColor = .clear
        table.usesAlternatingRowBackgroundColors = false
        table.dataSource = self; table.delegate = self
        let scroll = NSScrollView()
        scroll.documentView = table; scroll.hasVerticalScroller = true
        scroll.drawsBackground = false; scroll.borderType = .bezelBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false
        addSubview(searchField); addSubview(scroll)
        NSLayoutConstraint.activate([
            searchField.leadingAnchor.constraint(equalTo: leadingAnchor),
            searchField.trailingAnchor.constraint(equalTo: trailingAnchor),
            searchField.topAnchor.constraint(equalTo: topAnchor),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.topAnchor.constraint(equalTo: searchField.bottomAnchor,constant: 8),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        if !matches.isEmpty { table.selectRowIndexes(IndexSet(integer: 0),byExtendingSelection: false) }
    }
    required init?(coder: NSCoder) { nil }

    var selectedEntry: SystemCityEntry? {
        if matches.indices.contains(table.selectedRow) {
            return matches[table.selectedRow]
        }
        let value = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return catalog.first {
            $0.displayName.caseInsensitiveCompare(value) == .orderedSame ||
            $0.cityName.caseInsensitiveCompare(value) == .orderedSame
        }
    }

    func controlTextDidChange(_ notification: Notification) {
        matches = SystemCityCatalog.matching(catalog,query: searchField.stringValue)
        table.reloadData()
        if matches.isEmpty {
            table.deselectAll(nil)
        } else {
            table.selectRowIndexes(IndexSet(integer: 0),byExtendingSelection: false)
            table.scrollRowToVisible(0)
        }
    }

    func numberOfRows(in tableView: NSTableView) -> Int { matches.count }
    func tableView(_ tableView: NSTableView,viewFor tableColumn: NSTableColumn?,row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("cityCell")
        let field = (tableView.makeView(withIdentifier: identifier,owner: self) as? NSTextField) ?? {
            let value = NSTextField(labelWithString: "")
            value.identifier = identifier; value.font = .systemFont(ofSize: 13)
            value.lineBreakMode = .byTruncatingTail
            return value
        }()
        field.stringValue = matches[row].displayName
        return field
    }
}
