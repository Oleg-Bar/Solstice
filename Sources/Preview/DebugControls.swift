import AppKit
#if SWIFT_PACKAGE
import TerraCore
import TerraScene
#endif

final class DebugControls: NSPanel {
    private weak var scene: EarthSceneView?
    private var paths: [Int: WritableKeyPath<SceneConfiguration, Double>] = [:]
    private var values: [Int: NSTextField] = [:]
    init(scene: EarthSceneView) {
        self.scene = scene
        super.init(contentRect: NSRect(x: 0,y: 0,width: 350,height: 680),styleMask: [.titled,.closable,.utilityWindow],backing: .buffered,defer: false)
        title = "Terra · Настройка сцены"
        isFloatingPanel = true; hidesOnDeactivate = true; isReleasedWhenClosed = false
        let scroll = NSScrollView(frame: contentView!.bounds)
        scroll.autoresizingMask = [.width,.height]; scroll.hasVerticalScroller = true; scroll.drawsBackground = false
        let document = FlippedControlsDocument(frame: NSRect(x: 0,y: 0,width: 330,height: 1010))
        scroll.documentView = document; contentView!.addSubview(scroll)
        let stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 9
        stack.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: document.leadingAnchor,constant: 18),
            stack.trailingAnchor.constraint(equalTo: document.trailingAnchor,constant: -18),
            stack.topAnchor.constraint(equalTo: document.topAnchor,constant: 18)])
        let locationLabel = NSTextField(wrappingLabelWithString: scene.observerStatus)
        locationLabel.font = .systemFont(ofSize: 12,weight: .medium); stack.addArrangedSubview(locationLabel)
        scene.onObserverStatusChange = { [weak locationLabel] value in locationLabel?.stringValue = value }
        let location = NSPopUpButton()
        location.addItems(withTitles: ["По IP через ipwho.is","Madrid — вручную","Singapore — вручную","New York — вручную"])
        location.selectItem(at: scene.configuration.automaticIPLocation ? 0 : 1)
        location.target = self; location.action = #selector(changeObserver(_:)); stack.addArrangedSubview(location)
        let refresh = NSButton(title: "Обновить местоположение",target: self,action: #selector(refreshObserver))
        stack.addArrangedSubview(refresh)
        func slider(_ title: String,_ path: WritableKeyPath<SceneConfiguration, Double>,_ min: Double,_ max: Double) {
            let id = paths.count; paths[id] = path
            let row = NSStackView(); row.orientation = .horizontal
            let label = NSTextField(labelWithString: title); label.font = .systemFont(ofSize: 11)
            let value = NSTextField(labelWithString: String(format: "%.2f",scene.configuration[keyPath: path])); value.font = .monospacedDigitSystemFont(ofSize: 10,weight: .regular)
            values[id] = value; row.addArrangedSubview(label); row.addArrangedSubview(value)
            stack.addArrangedSubview(row)
            let slider = NSSlider(value: scene.configuration[keyPath: path],minValue: min,maxValue: max,target: self,action: #selector(changeSlider(_:)))
            slider.tag = id; slider.isContinuous = true; stack.addArrangedSubview(slider)
            slider.widthAnchor.constraint(equalToConstant: 280).isActive = true
        }
        slider("Размер Земли",\.earthDiameter,0.50,0.70)
        slider("Высота Земли",\.earthVerticalPosition,0.32,0.56)
        slider("Вращение · градусов/сек",\.rotationDegreesPerSecond,0,2)
        slider("Звёзды",\.starBrightness,0,1)
        slider("Млечный Путь",\.milkyWayBrightness,0,0.6)
        slider("Атмосфера",\.atmosphereIntensity,0,1)
        slider("Ночные огни",\.nightLightsIntensity,0.5,4)
        slider("Размер часов",\.clockScale,0.65,1.35)
        slider("Размер подписей",\.cityLabelScale,0.8,1.3)
        let scale = NSButton(checkboxWithTitle: "Реальный масштаб расстояния Земля–Луна",target: self,action: #selector(togglePhysicalScale(_:)))
        scale.state = scene.configuration.physicalMoonScale ? .on : .off; stack.addArrangedSubview(scale)
        let moon = NSButton(checkboxWithTitle: "Показывать Луну",target: self,action: #selector(toggleMoon(_:)))
        moon.state = scene.configuration.moonEnabled ? .on : .off; stack.addArrangedSubview(moon)
        let rate = NSPopUpButton(); rate.addItems(withTitles: ["Время: 1×","Время: 10×","Время: 100×","Время: 1000×"])
        rate.target = self; rate.action = #selector(changeTime(_:)); stack.addArrangedSubview(rate)
        let rotation = NSPopUpButton(); rotation.addItems(withTitles: ["Облёт: 1×","Облёт: 10×","Облёт: 100×"])
        rotation.target = self; rotation.action = #selector(changeRotation(_:)); stack.addArrangedSubview(rotation)
        let note = NSTextField(wrappingLabelWithString: "Ракурс центрируется на вашем местоположении. IP даёт приблизительный город и может указывать на VPN. Без сети сохраняется текущий ракурс.\n\nПараметры preview временные. Для заставки сохраните их в SceneConfiguration.swift и пересоберите проект.")
        note.font = .systemFont(ofSize: 10); note.textColor = .secondaryLabelColor; stack.addArrangedSubview(note)
    }
    @objc private func changeSlider(_ sender: NSSlider) {
        guard let path = paths[sender.tag] else { return }
        scene?.configuration[keyPath: path] = sender.doubleValue
        values[sender.tag]?.stringValue = String(format: "%.2f",sender.doubleValue)
    }
    @objc private func changeObserver(_ sender: NSPopUpButton) {
        switch sender.indexOfSelectedItem {
        case 1: scene?.selectObserver(.madrid)
        case 2: scene?.selectObserver(.singapore)
        case 3: scene?.selectObserver(.newYork)
        default: scene?.configuration.automaticIPLocation = true; scene?.refreshLocation(force: true)
        }
    }
    @objc private func refreshObserver() { scene?.refreshLocation(force: true) }
    @objc private func togglePhysicalScale(_ sender: NSButton) { scene?.configuration.physicalMoonScale = sender.state == .on }
    @objc private func toggleMoon(_ sender: NSButton) { scene?.configuration.moonEnabled = sender.state == .on }
    @objc private func toggleSide(_ sender: NSButton) { scene?.configuration.moonOnRight = sender.state == .on }
    @objc private func changeTime(_ sender: NSPopUpButton) {
        if sender.indexOfSelectedItem == 0 { scene?.timeline.reset() }
        else { scene?.timeline.setRate([1,10,100,1000][sender.indexOfSelectedItem]) }
    }
    @objc private func changeRotation(_ sender: NSPopUpButton) { scene?.rotationMultiplier = [1,10,100][sender.indexOfSelectedItem] }
}

private final class FlippedControlsDocument: NSView {
    override var isFlipped: Bool { true }
}
