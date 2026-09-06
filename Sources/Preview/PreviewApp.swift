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
    private var controls: DebugControls?
    func applicationDidFinishLaunching(_ notification: Notification) {
        let args = CommandLine.arguments
        scene = EarthSceneView(frame: NSRect(x: 0,y: 0,width: 1200,height: 750),preview: true)
        if let i = args.firstIndex(of: "--snapshot"), args.count > i+1 {
            do {
                let date: Date
                if let d = args.firstIndex(of: "--date"), args.count > d+1 {
                    guard let parsed = ISO8601DateFormatter().date(from: args[d+1]) else { throw CLIError.invalidDate }; date = parsed
                } else { date = Date() }
                var size = CGSize(width: 1440,height: 900)
                if let w = args.firstIndex(of: "--size"), args.count > w+2,
                   let width = Double(args[w+1]), let height = Double(args[w+2]), (200...4096).contains(width), (200...4096).contains(height) {
                    size = CGSize(width: width,height: height)
                }
                if let l = args.firstIndex(of: "--longitude"), args.count > l+1 { scene.longitudeOverride = Double(args[l+1]) }
                if let o = args.firstIndex(of: "--observer"), args.count > o+1 {
                    let places: [String:ObserverLocation] = ["madrid":.madrid,"singapore":.singapore,"new-york":.newYork]
                    guard let place = places[args[o+1].lowercased()] else { throw CLIError.invalidObserver }
                    scene.selectObserver(place,animated: false)
                }
                if args.contains("--compressed-distance") { scene.configuration.physicalMoonScale = false }
                if args.contains("--moon-left") { scene.configuration.moonOnRight = false }
                try scene.saveSnapshot(to: URL(fileURLWithPath: args[i+1]),size: size,date: date)
                print("Snapshot saved: \(args[i+1])")
                NSApp.terminate(nil)
            } catch { fputs("Terra render failed: \(error.localizedDescription)\n",stderr); exit(1) }
            return
        }
        window = NSWindow(contentRect: scene.frame,styleMask: [.titled,.closable,.miniaturizable,.resizable],backing: .buffered,defer: false)
        window.title = "Terra Preview"; window.minSize = CGSize(width: 640,height: 420)
        window.contentView = scene; window.delegate = self
        window.collectionBehavior = [.fullScreenPrimary]; window.center()
        let menu = NSMenu()
        let appItem = NSMenuItem(); let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Завершить Terra Preview",action: #selector(NSApplication.terminate(_:)),keyEquivalent: "q")
        appItem.submenu = appMenu; menu.addItem(appItem)
        let viewItem = NSMenuItem(); viewItem.title = "Вид"; let viewMenu = NSMenu(title: "Вид")
        let settings = viewMenu.addItem(withTitle: "Настроить сцену…",action: #selector(showControls),keyEquivalent: ","); settings.target = self
        let fullscreen = viewMenu.addItem(withTitle: "Полный экран",action: #selector(fullScreen),keyEquivalent: "f"); fullscreen.target = self
        fullscreen.keyEquivalentModifierMask = [.command,.control]
        viewItem.submenu = viewMenu; menu.addItem(viewItem); NSApp.mainMenu = menu
        window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); scene.start()
    }
    @objc private func showControls() {
        if controls == nil { controls = DebugControls(scene: scene); controls?.center() }
        controls?.makeKeyAndOrderFront(nil)
    }
    @objc private func fullScreen() { window.toggleFullScreen(nil) }
    func windowWillClose(_ notification: Notification) { scene.stop() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    enum CLIError: Error { case invalidDate, invalidObserver }
}
