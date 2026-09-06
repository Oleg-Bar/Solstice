import AppKit
import ScreenSaver

let app = NSApplication.shared
guard CommandLine.arguments.count == 2,
      let bundle = Bundle(path: CommandLine.arguments[1]),
      bundle.load(),
      let type = bundle.principalClass as? ScreenSaverView.Type else {
    fputs("Cannot load saver principal class\n",stderr); exit(1)
}
var views: [ScreenSaverView] = []
var windows: [NSWindow] = []
for preview in [true,false] {
    let size = preview ? NSSize(width: 320,height: 200) : NSSize(width: 1000,height: 625)
    guard let view = type.init(frame: NSRect(origin: .zero,size: size),isPreview: preview) else { exit(2) }
    let window = NSWindow(contentRect: view.frame,styleMask: [.titled],backing: .buffered,defer: false)
    window.contentView = view; window.orderFront(nil)
    func hasRenderError(_ node: NSView) -> Bool {
        if let text = node as? NSTextField, text.stringValue.contains("не удалось запустить Metal") { return true }
        return node.subviews.contains(where: hasRenderError)
    }
    guard !hasRenderError(view) else { fputs("Saver Metal initialization failed\n",stderr); exit(3) }
    view.startAnimation(); views.append(view); windows.append(window)
}
RunLoop.main.run(until: Date().addingTimeInterval(2))
for view in views { view.stopAnimation(); view.startAnimation() }
RunLoop.main.run(until: Date().addingTimeInterval(1))
for view in views { view.stopAnimation() }
print("Saver bundle loaded; thumbnail + full-size views started, stopped and restarted.")
