import AppKit
#if SWIFT_PACKAGE
import TerraCore
#endif

final class CityOverlayView: NSView {
    var caption: String?
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
            let credit = "Milky Way: ESO/S. Brunier · CC BY 4.0"
            let style: [NSAttributedString.Key:Any] = [.font: NSFont.systemFont(ofSize: 8,weight: .regular),
                .foregroundColor: NSColor.white.withAlphaComponent(0.28)]
            let size = (credit as NSString).size(withAttributes: style)
            (credit as NSString).draw(at: CGPoint(x: bounds.width-size.width-14,y: 10),withAttributes: style)
        }
        let cities = self.cities, c = configuration
        let now = ProcessInfo.processInfo.systemUptime
        let easing = 1-exp(-min(0.1,max(0.001,now-lastLayoutTime))/0.14)
        lastLayoutTime = now
        if previousSize != bounds.size { previousCenters.removeAll(); previousSize = bounds.size }
        let smaller = min(bounds.width,bounds.height), earthRadius = smaller*c.earthDiameter/2
        let earthCenter = CGPoint(x: bounds.midX,y: bounds.height*c.earthVerticalPosition)
        let baseRadius = min(46,max(28,earthRadius*0.13))*c.clockScale
        // Every clock uses the same diameter as the foreground observer clock.
        let hiddenRadius = baseRadius
        var occupied: [CGRect] = []
        for (index,city) in cities.enumerated() {
            let p = basis.project(city.position)
            let opacity = GlobeGeometry.surfaceOpacity(depth: p.z)
            let state = states[index]
            let anchor = CGPoint(x: earthCenter.x+p.x*earthRadius,y: earthCenter.y+p.y*earthRadius)
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
            center.x = min(bounds.width-radius*2,max(radius*2,center.x))
            center.y = min(bounds.height-radius*1.2,max(radius*3,center.y))
            if let previous = previousCenters[city.id] {
                center = CGPoint(x: previous.x+(center.x-previous.x)*easing,y: previous.y+(center.y-previous.y)*easing)
            }
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
            var hiddenCenter = CGPoint(x: earthCenter.x+direction.x*distance,y: earthCenter.y+direction.y*distance)
            hiddenCenter.x = min(bounds.width-hiddenRadius*2.5,max(hiddenRadius*2.5,hiddenCenter.x))
            hiddenCenter.y = min(bounds.height-hiddenRadius*2,max(hiddenRadius*3.2,hiddenCenter.y))
            if opacity < 0.99 {
                drawGlassArrow(cg,from: hiddenCenter,to: limb,radius: hiddenRadius,opacity: 1-opacity,time: now)
                AnalogClock.draw(center: hiddenCenter,radius: hiddenRadius,city: city,state: state,opacity: 1-opacity,labelScale: c.cityLabelScale)
            }
        }
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
        cg.strokePath(); cg.restoreGState()
    }

}
