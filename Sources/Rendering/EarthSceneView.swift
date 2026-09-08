import AppKit
import MetalKit
#if SWIFT_PACKAGE
import TerraCore
#endif

public final class EarthSceneView: NSView {
    public var configuration = SceneConfiguration()
    public var timeline: SceneTimeline
    public var rotationMultiplier = 1.0
    public var longitudeOverride: Double?
    public private(set) var observer = ObserverLocation.madrid
    public private(set) var observerStatus = "Madrid · ожидание определения по IP"
    public var onObserverStatusChange: ((String) -> Void)?
    public private(set) var renderingError: String?
    private let metalView: MTKView
    private let overlay = CityOverlayView()
    private var renderer: EarthRenderer?
    private var timer: Timer?
    private var lastUptime = ProcessInfo.processInfo.systemUptime
    private var rotation = 0.0
    private var solarDate = Date.distantPast
    private var solar = SolarPositionCalculator.position(at: Date())
    private var lunar = LunarAppearanceCalculator.appearance(at: Date(),observer: .madrid)
    private var currentLongitude = ObserverLocation.madrid.longitude
    private var currentLatitude = ObserverLocation.madrid.latitude
    private var locationRequest: Task<Void,Never>?
    private var selectedCities = CityStore.loadSelection()
    private var lastLocationLookup = -Double.infinity
    private var isRunning = false

    public init(frame: NSRect, preview: Bool) {
        timeline = SceneTimeline(isPreview: preview)
        metalView = MTKView(frame: frame, device: MTLCreateSystemDefaultDevice())
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        metalView.colorPixelFormat = .bgra8Unorm_srgb
        metalView.isPaused = true
        metalView.enableSetNeedsDisplay = false
        metalView.autoResizeDrawable = false
        addSubview(metalView)
        addSubview(overlay)
        overlay.setSelectedCities(selectedCities)
        do {
            guard let device = metalView.device else { throw EarthRenderer.RenderError.unavailable }
            renderer = try EarthRenderer(device: device)
        } catch {
            renderingError = error.localizedDescription
            let message = NSTextField(wrappingLabelWithString: "Terra — не удалось запустить Metal\n\(error.localizedDescription)")
            message.textColor = .white; message.frame = NSRect(x: 24, y: 24, width: 540, height: 90)
            addSubview(message)
        }
    }
    required init?(coder: NSCoder) { nil }
    deinit { timer?.invalidate(); locationRequest?.cancel() }

    public override func layout() {
        super.layout()
        synchronizeViewport()
    }
    private func synchronizeViewport() {
        metalView.frame = bounds; overlay.frame = bounds
        let backing = window?.backingScaleFactor ?? 2
        let desired = CGSize(width: max(1,bounds.width*backing), height: max(1,bounds.height*backing))
        let cap = min(1,configuration.maximumDrawableDimension/max(desired.width,desired.height))
        let size = CGSize(width: max(1,desired.width*cap),height: max(1,desired.height*cap))
        if metalView.drawableSize != size { metalView.drawableSize = size }
    }
    public func start(ownTimer: Bool = true) {
        guard !isRunning else { return }
        isRunning = true; lastUptime = ProcessInfo.processInfo.systemUptime
        if configuration.automaticIPLocation { refreshLocation() }
        if ownTimer {
            let interval = 1/Double(configuration.preferredFramesPerSecond)
            let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
                // AppKit's run-loop timer and the saver host both render on the main thread.
                self?.renderFrame()
            }
            timer.tolerance = interval*0.12
            RunLoop.main.add(timer,forMode: .common); self.timer = timer
        }
        needsLayout = true
    }
    public func stop() { isRunning = false; timer?.invalidate(); timer = nil; locationRequest?.cancel(); locationRequest = nil }

    public func selectObserver(_ location: ObserverLocation, animated: Bool = true) {
        guard location.isValid else { return }
        configuration.automaticIPLocation = false
        locationRequest?.cancel(); locationRequest = nil
        applyObserver(location,status: "\(location.name) · выбрано вручную",animated: animated)
    }
    @discardableResult public func addCity(_ city: City) -> Bool {
        guard !CitiesConfiguration.including(observer: observer,selection: selectedCities).contains(where: {
            simd_length($0.position-city.position) < 0.015
        }) else { return false }
        selectedCities.append(city); CityStore.saveSelection(selectedCities); overlay.setSelectedCities(selectedCities)
        if isRunning { renderFrame() }
        onCitySelectionChange?()
        return true
    }
    public var removableCities: [City] {
        selectedCities.filter { !CitiesConfiguration.matchesObserver($0,observer: observer) }
    }
    public var onCitySelectionChange: (() -> Void)?
    @discardableResult public func removeCity(id: String) -> Bool {
        guard let city = selectedCities.first(where: { $0.id == id }),
              !CitiesConfiguration.matchesObserver(city,observer: observer),
              let updated = CityStore.removing(id: id,from: selectedCities) else { return false }
        selectedCities = updated
        CityStore.saveSelection(selectedCities)
        overlay.setSelectedCities(selectedCities)
        if isRunning { renderFrame() }
        onCitySelectionChange?()
        return true
    }
    private func applyObserver(_ location: ObserverLocation,status: String,animated: Bool) {
        observer = location; observerStatus = status
        configuration.initialLongitude = location.longitude; configuration.cameraLatitude = location.latitude
        rotation = 0; solarDate = .distantPast
        if !animated { currentLongitude = location.longitude; currentLatitude = location.latitude }
        onObserverStatusChange?(observerStatus)
        onCitySelectionChange?()
    }
    public func refreshLocation(force: Bool = false) {
        guard configuration.automaticIPLocation, locationRequest == nil else { return }
        lastLocationLookup = ProcessInfo.processInfo.systemUptime
        observerStatus = "Определение местоположения по IP…"; onObserverStatusChange?(observerStatus)
        locationRequest = Task { [weak self] in
            do {
                let location = try await IPLocationResolver.shared.resolve(force: force)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self, self.configuration.automaticIPLocation else { return }
                    self.applyObserver(location,status: "\(location.name) · определено по IP",animated: true)
                    self.locationRequest = nil
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self else { return }
                    self.observerStatus = "\(self.observer.name) · IP недоступен, сохранён текущий ракурс"
                    self.onObserverStatusChange?(self.observerStatus); self.locationRequest = nil
                }
            }
        }
    }

    private func basis() -> CameraBasis {
        CameraBasis(longitude: longitudeOverride ?? (currentLongitude + rotation), latitude: currentLatitude)
    }
    private func uniforms(size: CGSize, date: Date) -> SceneUniforms {
        let basis = basis(), c = configuration
        func vector(_ v: SIMD3<Double>) -> SIMD4<Float> { SIMD4(Float(v.x),Float(v.y),Float(v.z),0) }
        if abs(date.timeIntervalSince(solarDate)) >= 1 {
            solar = SolarPositionCalculator.position(at: date)
            lunar = LunarAppearanceCalculator.appearance(at: date,observer: observer)
            solarDate = date
        }
        let layout = EarthMoonLayout.calculate(width: size.width,height: size.height,basis: basis,lunar: lunar,configuration: c)
        return SceneUniforms(
            viewport: SIMD4(Float(size.width),Float(size.height),Float(layout.earthRadius),Float(size.height*c.earthVerticalPosition)),
            right: vector(basis.right), up: vector(basis.up), front: vector(basis.front), sun: vector(solar.direction),
            style: SIMD4(Float(c.starBrightness),Float(c.milkyWayBrightness),Float(c.atmosphereIntensity),Float(c.nightLightsIntensity)),
            moon: SIMD4(Float(layout.moonCenter.x),Float(layout.moonCenter.y),
                        layout.moonOpacity > 0 ? Float(layout.moonRadius) : 0,Float(lunar.northPositionAngle)),
            moonLight: SIMD4(Float(lunar.lightDirection.x),Float(lunar.lightDirection.y),Float(lunar.lightDirection.z),Float(layout.moonDepth)),
            moonSurface: SIMD4(Float(lunar.librationLongitude),Float(lunar.librationLatitude),Float(lunar.illuminatedFraction),Float(layout.moonOpacity)))
    }
    public func renderFrame() {
        guard isRunning, bounds.width > 0, bounds.height > 0 else { return }
        synchronizeViewport()
        let uptime = ProcessInfo.processInfo.systemUptime
        let delta = min(0.25,max(0,uptime-lastUptime)); lastUptime = uptime
        let easing = 1-exp(-delta/0.9)
        currentLongitude += SolarPositionCalculator.normalizedLongitude(configuration.initialLongitude-currentLongitude)*easing
        currentLatitude += (configuration.cameraLatitude-currentLatitude)*easing
        if configuration.automaticIPLocation,
           uptime-lastLocationLookup >= IPLocationResolver.refreshInterval { refreshLocation() }
        rotation = (rotation + delta*configuration.rotationDegreesPerSecond*rotationMultiplier).truncatingRemainder(dividingBy: 360)
        guard window?.isVisible != false, window?.occlusionState.contains(.visible) != false else { return }
        let date = timeline.date(uptime: uptime)
        renderer?.draw(view: metalView,uniforms: uniforms(size: metalView.drawableSize,date: date))
        overlay.caption = nil
        overlay.update(date: date,basis: basis(),configuration: overlayConfiguration(size: bounds.size),observer: observer)
    }

    private func overlayConfiguration(size: CGSize) -> SceneConfiguration {
        var c = configuration
        let layout = EarthMoonLayout.calculate(width: size.width,height: size.height,basis: basis(),lunar: lunar,configuration: c)
        c.earthDiameter = layout.earthRadius*2/min(size.width,size.height)
        // Same layout the shader received, already expressed in the overlay's coordinate
        // space, so city clocks can keep clear of the lunar disc.
        overlay.moonObstacle = layout.obstacle
        return c
    }

    private func sceneCaption(date: Date,snapshot: Bool) -> String {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = TimeZone(identifier: observer.timeZoneIdentifier); formatter.dateFormat = "d MMM yyyy, HH:mm:ss"
        let mode = snapshot ? "ТЕСТОВЫЙ КАДР" : (timeline.rate == 1 ? "ТЕКУЩЕЕ ВРЕМЯ" : "УСКОРЕННОЕ ВРЕМЯ")
        let scale = "Размеры тел пропорциональны · расстояние показано обзорно"
        let moon = lunar.altitudeDegrees > 0 ? String(format: "Луна %.0f км · над горизонтом %.1f°",lunar.distanceKilometers,lunar.altitudeDegrees) : "Луна под горизонтом"
        return "\(mode) · \(observer.name) · \(formatter.string(from: date))\n\(scale) · \(moon)"
    }

    public func saveSnapshot(to url: URL, size: CGSize, date: Date) throws {
        guard let renderer else {
            throw NSError(domain: "Terra",code: 2,userInfo: [NSLocalizedDescriptionKey: renderingError ?? "Metal недоступен"])
        }
        let rep = try renderer.snapshot(uniforms: uniforms(size: size,date: date))
        guard let context = NSGraphicsContext(bitmapImageRep: rep) else { throw EarthRenderer.RenderError.unavailable }
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
        overlay.caption = sceneCaption(date: date,snapshot: true)
        overlay.frame = NSRect(origin: .zero,size: size)
        overlay.update(date: date,basis: basis(),configuration: overlayConfiguration(size: size),observer: observer)
        overlay.draw(overlay.bounds)
        NSGraphicsContext.restoreGraphicsState()
        guard let data = rep.representation(using: .png,properties: [:]) else { throw EarthRenderer.RenderError.unavailable }
        try data.write(to: url)
    }
}
