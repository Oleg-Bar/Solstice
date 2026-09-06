import AppKit
#if SWIFT_PACKAGE
import TerraCore
#endif

enum AnalogClock {
    static func draw(center: CGPoint, radius: CGFloat, city: City, state: CityClockState, opacity: Double, labelScale: Double) {
        guard opacity > 0.002, let cg = NSGraphicsContext.current?.cgContext else { return }
        cg.saveGState(); defer { cg.restoreGState() }
        cg.setAlpha(opacity)
        let rect = CGRect(x: center.x-radius,y: center.y-radius,width: radius*2,height: radius*2)
        cg.setShadow(offset: CGSize(width: 0,height: -2),blur: 8,color: NSColor.black.withAlphaComponent(0.42).cgColor)
        cg.setFillColor(NSColor(calibratedRed: 0.05,green: 0.075,blue: 0.105,alpha: 0.68).cgColor)
        cg.fillEllipse(in: rect)
        cg.setShadow(offset: .zero,blur: 0,color: nil)
        cg.setStrokeColor(NSColor.white.withAlphaComponent(0.32).cgColor); cg.setLineWidth(max(0.6,radius/60))
        cg.strokeEllipse(in: rect.insetBy(dx: 0.6,dy: 0.6))
        for index in 0..<12 {
            let angle = Double(index)*Double.pi/6
            let inner = radius*(index%3 == 0 ? 0.72 : 0.81)
            cg.setStrokeColor(NSColor.white.withAlphaComponent(index%3 == 0 ? 0.85 : 0.4).cgColor)
            cg.setLineWidth(index%3 == 0 ? max(1,radius*0.045) : max(0.7,radius*0.025))
            cg.move(to: CGPoint(x: center.x+sin(angle)*inner,y: center.y+cos(angle)*inner))
            cg.addLine(to: CGPoint(x: center.x+sin(angle)*radius*0.89,y: center.y+cos(angle)*radius*0.89)); cg.strokePath()
        }
        func hand(_ angle: Double,_ length: Double,_ width: Double) {
            cg.setLineCap(.round); cg.setLineWidth(max(1,width*radius)); cg.setStrokeColor(NSColor.white.cgColor)
            cg.move(to: center); cg.addLine(to: CGPoint(x: center.x+sin(angle)*radius*length,y: center.y+cos(angle)*radius*length)); cg.strokePath()
        }
        hand(state.hourAngle,0.48,0.075); hand(state.minuteAngle,0.69,0.045)
        cg.setFillColor(NSColor.white.cgColor); cg.fillEllipse(in: CGRect(x: center.x-1.6,y: center.y-1.6,width: 3.2,height: 3.2))
        let fontSize = max(5,radius*0.38*labelScale)
        let y = center.y-radius-fontSize*1.65
        text(city.name,center: CGPoint(x: center.x,y: y),size: fontSize,weight: .semibold)
        text(state.label,center: CGPoint(x: center.x,y: y-fontSize*1.35),size: fontSize*0.88,weight: .medium)
    }
    static func text(_ value: String, center: CGPoint, size: CGFloat, weight: NSFont.Weight, alpha: CGFloat = 0.93) {
        let shadow = NSShadow(); shadow.shadowColor = NSColor.black; shadow.shadowBlurRadius = 5; shadow.shadowOffset = CGSize(width: 0,height: -1)
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedDigitSystemFont(ofSize: size,weight: weight),
            .foregroundColor: NSColor.white.withAlphaComponent(alpha),.shadow: shadow,.kern: size*0.035]
        let string = NSAttributedString(string: value,attributes: attributes)
        string.draw(at: CGPoint(x: center.x-string.size().width/2,y: center.y))
    }
}
