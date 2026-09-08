import AppKit
#if SWIFT_PACKAGE
import TerraCore
#endif

final class CityOverlayView: NSView {
    var caption: String?
    var showsUpdateGlyph = false
    /// Lunar disc in this view's coordinate space. No city clock may cover it.
    var moonObstacle: MoonObstacle?
    private var configuration = SceneConfiguration()
    private var basis = CameraBasis(longitude: 15,latitude: 15)
    private var cities = CitiesConfiguration.cities
    private var selectedCities = CitiesConfiguration.cities
    private var observer: ObserverLocation?
    private var states: [CityClockState] = []
    private var citiesDirty = true
    private var lastSecond = Int.min
    private var previousCenters: [String: CGPoint] = [:]
    private var lastLayoutTime = ProcessInfo.processInfo.systemUptime
    private var previousSize = CGSize.zero
    override var isOpaque: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    func setSelectedCities(_ cities: [City]) {
        selectedCities = cities
        // Keep the current city/state pair intact until update() can replace both.
        citiesDirty = true; lastSecond = Int.min
        previousCenters.removeAll()
    }
    func update(date: Date, basis: CameraBasis, configuration: SceneConfiguration, observer: ObserverLocation) {
        self.basis = basis; self.configuration = configuration
        let second = Int(date.timeIntervalSince1970)
        if self.observer != observer || citiesDirty {
            self.observer = observer; cities = CitiesConfiguration.including(observer: observer,selection: selectedCities)
            states = cities.map { CityClockState(city: $0,date: date) }
            lastSecond = second; citiesDirty = false; previousCenters.removeAll()
        }
        if lastSecond != second {
            states = cities.map { CityClockState(city: $0,date: date) }; lastSecond = second
        }
        needsDisplay = true
    }
    override func draw(_ dirtyRect: NSRect) {
        guard let cg = NSGraphicsContext.current?.cgContext, !states.isEmpty else { return }
        if let caption {
            let style: [NSAttributedString.Key:Any] = [.font: NSFont.monospacedDigitSystemFont(ofSize: 11,weight: .regular),.foregroundColor: NSColor.white.withAlphaComponent(0.58)]
            (caption as NSString).draw(in: CGRect(x: 20,y: 18,width: bounds.width-40,height: 32),withAttributes: style)
        }
        if configuration.milkyWayBrightness > 0 {
            if showsUpdateGlyph { drawUpdateGlyph() }
            drawRightAligned("created by Oleg Bardakov",y: 10,size: 8,weight: .regular,alpha: 0.30)
        }
        let cities = self.cities, c = configuration
        let now = ProcessInfo.processInfo.systemUptime
        let easing = 1-exp(-min(0.1,max(0.001,now-lastLayoutTime))/0.14)
        lastLayoutTime = now
        if previousSize != bounds.size { previousCenters.removeAll(); previousSize = bounds.size }
        let smaller = min(bounds.width,bounds.height), earthRadius = smaller*c.earthDiameter/2
        let earthCenter = CGPoint(x: bounds.midX,y: bounds.height*c.earthVerticalPosition)
        let baseRadius = CGFloat(SceneLayoutMetrics.clockRadius(
            width: Double(bounds.width),height: Double(bounds.height),configuration: c))
        // Every clock uses the same diameter as the foreground observer clock.
        let hiddenRadius = baseRadius
        var occupied: [CGRect] = []
        // The Moon is a fixed obstacle, so reserve its disc up front and let the
        // separation loop below steer clocks around it before the final pass.
        if let moon = moonObstacle, moon.radius > 0 {
            occupied.append(CGRect(x: moon.center.x-moon.radius,y: moon.center.y-moon.radius,
                width: moon.radius*2,height: moon.radius*2))
        }
        for (index,city) in cities.enumerated() {
            let p = basis.project(city.position)
            let opacity = GlobeGeometry.surfaceOpacity(depth: p.z)
            let state = states[index]
            let exactProjection = basis.screenProjection(
                city.position,
                earthCenter: SIMD2(Double(earthCenter.x),Double(earthCenter.y)),
                earthRadius: Double(earthRadius)
            )
            // This is the city's exact orthographic latitude/longitude projection.
            // Both foreground and rear-hemisphere indicators terminate at this point.
            let anchor = CGPoint(x: exactProjection.x,y: exactProjection.y)
            let radius = baseRadius
            var center = anchor
            if earthRadius < 100 {
                let length = hypot(p.x,p.y)
                let dx = length > 0.01 ? p.x/length : 0
                let dy = length > 0.01 ? p.y/length : -1
                center = CGPoint(x: earthCenter.x+dx*(earthRadius+90),y: earthCenter.y+dy*(earthRadius+90))
            }
            // Reserve an envelope for the two label lines and gently separate nearby clocks.
            let envelope = CGSize(width: radius*3.7,height: radius*3.6*c.cityLabelScale)
            for _ in 0..<cities.count {
                let rect = CGRect(x: center.x-envelope.width/2,y: center.y-radius*2.5,width: envelope.width,height: envelope.height)
                if occupied.contains(where: { $0.intersects(rect) }) { center.x += (p.x < 0 ? -1 : 1)*radius*3.8 } else { break }
            }
            if let previous = previousCenters[city.id] {
                center = CGPoint(x: previous.x+(center.x-previous.x)*easing,y: previous.y+(center.y-previous.y)*easing)
            }
            // Resolved after the on-screen limits and the easing, so every drawn frame —
            // including mid-transition ones — keeps the dial clear of the lunar disc.
            center = resolved(center,envelope: envelope,radius: radius,
                limits: (SIMD2(Double(radius*2),Double(radius*3)),
                    SIMD2(Double(bounds.width-radius*2),Double(bounds.height-radius*1.2))))
            previousCenters[city.id] = center
            if opacity > 0.01 {
                occupied.append(CGRect(x: center.x-envelope.width/2,y: center.y-radius*2.5,width: envelope.width,height: envelope.height))
                cg.saveGState()
                if hypot(center.x-anchor.x,center.y-anchor.y) > radius {
                    drawGlassArrow(cg,from: center,to: anchor,radius: radius,opacity: opacity,time: now)
                }
                cg.restoreGState()
                AnalogClock.draw(center: center,radius: radius,city: city,state: state,opacity: opacity,labelScale: c.cityLabelScale)
            }
            let directionLength = hypot(p.x,p.y)
            let direction = directionLength > 0.001 ? CGPoint(x: p.x/directionLength,y: p.y/directionLength) : CGPoint(x: -1,y: 0)
            let limb = CGPoint(x: earthCenter.x+direction.x*(earthRadius+3),y: earthCenter.y+direction.y*(earthRadius+3))
            let distance = earthRadius+hiddenRadius*3.5+20
            let hiddenCenter = resolved(CGPoint(x: earthCenter.x+direction.x*distance,y: earthCenter.y+direction.y*distance),
                envelope: CGSize(width: hiddenRadius*3.7,height: hiddenRadius*3.6*c.cityLabelScale),radius: hiddenRadius,
                limits: (SIMD2(Double(hiddenRadius*2.5),Double(hiddenRadius*3.2)),
                    SIMD2(Double(bounds.width-hiddenRadius*2.5),Double(bounds.height-hiddenRadius*2))))
            if opacity < 0.99 {
                // A front-side city points to its exact map coordinate. A rear-side city has no
                // visible point on the current map, so its indicator truthfully ends at the limb
                // in the exact bearing of that coordinate instead of pointing at a wrong country.
                let target = p.z >= 0 ? anchor : limb
                drawGlassArrow(cg,from: hiddenCenter,to: target,radius: hiddenRadius,opacity: 1-opacity,time: now)
                AnalogClock.draw(center: hiddenCenter,radius: hiddenRadius,city: city,state: state,opacity: 1-opacity,labelScale: c.cityLabelScale)
            }
        }
    }
    /// Places a clock through the shared Core resolver, bridging AppKit and SIMD types.
    private func resolved(_ center: CGPoint,envelope: CGSize,radius: CGFloat,
        limits: (min: SIMD2<Double>,max: SIMD2<Double>)) -> CGPoint {
        let placed = ClockPlacement.resolve(SIMD2(Double(center.x),Double(center.y)),
            envelope: SIMD2(Double(envelope.width),Double(envelope.height)),radius: Double(radius),
            moon: moonObstacle,limits: limits)
        return CGPoint(x: placed.x,y: placed.y)
    }
    private func drawGlassArrow(_ cg: CGContext,from center: CGPoint,to tip: CGPoint,radius: Double,opacity: Double,time: Double) {
        let dx = tip.x-center.x, dy = tip.y-center.y, length = hypot(dx,dy)
        guard length > radius+8 else { return }
        let ux = dx/length, uy = dy/length
        let start = CGPoint(x: center.x+ux*(radius+7),y: center.y+uy*(radius+7))
        let control = CGPoint(x: (start.x+tip.x)/2-uy*12,y: (start.y+tip.y)/2+ux*12)
        let path = CGMutablePath(); path.move(to: start); path.addQuadCurve(to: tip,control: control)
        cg.saveGState(); cg.setAlpha(opacity); cg.setLineCap(.round)
        cg.setStrokeColor(NSColor(calibratedRed: 0.55,green: 0.8,blue: 1,alpha: 0.09).cgColor)
        cg.setLineWidth(5); cg.addPath(path); cg.strokePath()
        cg.setStrokeColor(NSColor.white.withAlphaComponent(0.38).cgColor)
        cg.setLineWidth(0.8); cg.addPath(path); cg.strokePath()
        // A slow travelling highlight, with no flashing or large pulsing shape.
        let t = (time/3).truncatingRemainder(dividingBy: 1)
        let q = 1-t
        let point = CGPoint(x: q*q*start.x+2*q*t*control.x+t*t*tip.x,y: q*q*start.y+2*q*t*control.y+t*t*tip.y)
        cg.setFillColor(NSColor.white.withAlphaComponent(0.55*sin(.pi*t)).cgColor)
        cg.fillEllipse(in: CGRect(x: point.x-1.5,y: point.y-1.5,width: 3,height: 3))
        let tx = tip.x-control.x, ty = tip.y-control.y, norm = hypot(tx,ty)
        let vx = tx/norm, vy = ty/norm
        cg.move(to: CGPoint(x: tip.x-vx*7-vy*3,y: tip.y-vy*7+vx*3))
        cg.addLine(to: tip)
        cg.addLine(to: CGPoint(x: tip.x-vx*7+vy*3,y: tip.y-vy*7-vx*3))
        cg.strokePath()
        // A small endpoint makes the exact geographic target unambiguous.
        cg.setFillColor(NSColor.white.withAlphaComponent(0.72).cgColor)
        cg.fillEllipse(in: CGRect(x: tip.x-2,y: tip.y-2,width: 4,height: 4))
        cg.restoreGState()
    }

    private func drawRightAligned(_ value: String,y: CGFloat,size: CGFloat,weight: NSFont.Weight,alpha: CGFloat) {
        let style: [NSAttributedString.Key:Any] = [
            .font: NSFont.systemFont(ofSize: size,weight: weight),
            .foregroundColor: NSColor.white.withAlphaComponent(alpha),
            .kern: size*0.035
        ]
        let width = (value as NSString).size(withAttributes: style).width
        (value as NSString).draw(at: CGPoint(x: bounds.width-width-14,y: y),withAttributes: style)
    }

    private func drawUpdateGlyph() {
        guard let cg = NSGraphicsContext.current?.cgContext else { return }
        let textStyle: [NSAttributedString.Key:Any] = [
            .font: NSFont.systemFont(ofSize: 8,weight: .regular),
            .kern: 8*0.035
        ]
        let creditWidth = ("created by Oleg Bardakov" as NSString).size(withAttributes: textStyle).width
        let rect = CGRect(x: bounds.width-14-creditWidth-7-24,y: 2,width: 24,height: 24)
        let path = CGPath(roundedRect: rect,cornerWidth: 7.5,cornerHeight: 7.5,transform: nil)
        cg.saveGState()
        cg.setShadow(offset: CGSize(width: 0,height: -1),blur: 5,
            color: NSColor.black.withAlphaComponent(0.35).cgColor)
        cg.setFillColor(NSColor.black.withAlphaComponent(0.22).cgColor)
        cg.addPath(path); cg.fillPath()
        cg.setShadow(offset: .zero,blur: 0,color: nil)
        cg.saveGState(); cg.addPath(path); cg.clip()
        let colors = [NSColor.white.withAlphaComponent(0.10).cgColor,
            NSColor.white.withAlphaComponent(0.01).cgColor] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),colors: colors,locations: [0,1]) {
            cg.drawLinearGradient(gradient,start: CGPoint(x: rect.midX,y: rect.maxY),
                end: CGPoint(x: rect.midX,y: rect.midY),options: [])
        }
        cg.restoreGState()
        cg.setStrokeColor(NSColor.white.withAlphaComponent(0.13).cgColor)
        cg.setLineWidth(0.55); cg.addPath(path); cg.strokePath()
        cg.setStrokeColor(NSColor.white.withAlphaComponent(0.48).cgColor)
        cg.setLineWidth(0.9); cg.setLineCap(.round); cg.setLineJoin(.round)
        let center = CGPoint(x: rect.midX,y: rect.midY)
        cg.addArc(center: center,radius: 4.15,startAngle: -.pi*0.18,endAngle: .pi*0.94,clockwise: false)
        cg.strokePath()
        cg.addArc(center: center,radius: 4.15,startAngle: .pi*0.82,endAngle: .pi*1.94,clockwise: false)
        cg.strokePath()
        let upperTip = CGPoint(x: center.x+4.05,y: center.y+1.1)
        cg.move(to: CGPoint(x: upperTip.x-2.5,y: upperTip.y+0.4)); cg.addLine(to: upperTip)
        cg.addLine(to: CGPoint(x: upperTip.x-0.4,y: upperTip.y+2.5)); cg.strokePath()
        let lowerTip = CGPoint(x: center.x-4.05,y: center.y-1.1)
        cg.move(to: CGPoint(x: lowerTip.x+2.5,y: lowerTip.y-0.4)); cg.addLine(to: lowerTip)
        cg.addLine(to: CGPoint(x: lowerTip.x+0.4,y: lowerTip.y-2.5)); cg.strokePath()
        cg.restoreGState()
    }

}
