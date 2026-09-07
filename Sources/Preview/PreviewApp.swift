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
                try scene.saveSnapshot(to: URL(fileURLWithPath: args[i+1]),size: size,date: date)
                print("Snapshot saved: \(args[i+1])")
                NSApp.terminate(nil)
            } catch { fputs("Terra render failed: \(error.localizedDescription)\n",stderr); exit(1) }
            return
        }
        window = NSWindow(contentRect: scene.frame,styleMask: [.titled,.closable,.miniaturizable,.resizable],backing: .buffered,defer: false)
        window.title = "Terra Preview"; window.minSize = CGSize(width: 640,height: 420)
        window.contentView = scene; window.delegate = self
        let toolbar = PreviewToolbar()
        toolbar.onAddCity = { [weak self] in self?.showAddCity() }
        toolbar.onRemoveCity = { [weak self] in self?.showRemoveCity() }
        toolbar.canRemoveCity = !scene.removableCities.isEmpty
        scene.onCitySelectionChange = { [weak toolbar, weak scene] in
            toolbar?.canRemoveCity = !(scene?.removableCities.isEmpty ?? true)
        }
        self.toolbar = toolbar
        let toolbarWindow = NSPanel(contentRect: NSRect(x: 0,y: 0,width: 190,height: 36),
            styleMask: [.borderless,.nonactivatingPanel],backing: .buffered,defer: false)
        toolbar.translatesAutoresizingMaskIntoConstraints = true
        toolbar.frame = toolbarWindow.contentView?.bounds ?? NSRect(x: 0,y: 0,width: 190,height: 36)
        toolbar.autoresizingMask = [.width,.height]
        toolbarWindow.contentView = toolbar
        toolbarWindow.isOpaque = false; toolbarWindow.backgroundColor = .clear; toolbarWindow.hasShadow = false
        toolbarWindow.collectionBehavior = [.fullScreenAuxiliary]
        self.toolbarWindow = toolbarWindow
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
        appMenu.addItem(withTitle: "Завершить Terra Preview",action: #selector(NSApplication.terminate(_:)),keyEquivalent: "q")
        appItem.submenu = appMenu; menu.addItem(appItem)
        let viewItem = NSMenuItem(); viewItem.title = "Вид"; let viewMenu = NSMenu(title: "Вид")
        let fullscreen = viewMenu.addItem(withTitle: "Полный экран",action: #selector(fullScreen),keyEquivalent: "f"); fullscreen.target = self
        fullscreen.keyEquivalentModifierMask = [.command,.control]
        viewItem.submenu = viewMenu; menu.addItem(viewItem); NSApp.mainMenu = menu
        window.makeKeyAndOrderFront(nil)
        window.addChildWindow(toolbarWindow,ordered: .above)
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
    @objc private func showLocationConsent() {
        let alert = NSAlert()
        alert.messageText = "Определять текущий город по IP?"
        alert.informativeText = "Для приблизительного города Terra отправит ваш внешний IP сервису ipwho.is. Точные координаты Mac не передаются. Без разрешения останется резервный город Madrid."
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
    }
    func windowDidMove(_ notification: Notification) { positionToolbar() }
    func windowDidResize(_ notification: Notification) { positionToolbar() }
    func windowWillClose(_ notification: Notification) {
        scene.stop()
        if let toolbarWindow { window.removeChildWindow(toolbarWindow); toolbarWindow.close() }
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
