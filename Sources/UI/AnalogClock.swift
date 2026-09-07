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
        let face = state.isDaylight ? NSColor(white: 0.94,alpha: 0.92) : NSColor(white: 0.015,alpha: 0.88)
        let detail = state.isDaylight ? NSColor.black : NSColor.white
        cg.setShadow(offset: CGSize(width: 0,height: -2),blur: 8,color: NSColor.black.withAlphaComponent(0.42).cgColor)
        cg.setFillColor(face.cgColor)
        cg.fillEllipse(in: rect)
        cg.setShadow(offset: .zero,blur: 0,color: nil)
        cg.setStrokeColor(detail.withAlphaComponent(0.48).cgColor); cg.setLineWidth(max(0.8,radius/55))
        cg.strokeEllipse(in: rect.insetBy(dx: 0.6,dy: 0.6))
        for index in 0..<12 {
            let angle = Double(index)*Double.pi/6
            let inner = radius*(index%3 == 0 ? 0.72 : 0.81)
            cg.setStrokeColor(detail.withAlphaComponent(index%3 == 0 ? 0.92 : 0.58).cgColor)
            cg.setLineWidth(index%3 == 0 ? max(1,radius*0.045) : max(0.7,radius*0.025))
            cg.move(to: CGPoint(x: center.x+sin(angle)*inner,y: center.y+cos(angle)*inner))
            cg.addLine(to: CGPoint(x: center.x+sin(angle)*radius*0.89,y: center.y+cos(angle)*radius*0.89)); cg.strokePath()
        }
        func hand(_ angle: Double,_ length: Double,_ width: Double) {
            cg.setLineCap(.round); cg.setLineWidth(max(1,width*radius)); cg.setStrokeColor(detail.cgColor)
            cg.move(to: center); cg.addLine(to: CGPoint(x: center.x+sin(angle)*radius*length,y: center.y+cos(angle)*radius*length)); cg.strokePath()
        }
        hand(state.hourAngle,0.48,0.075); hand(state.minuteAngle,0.69,0.045)
        let pinRadius = max(1.6,radius*0.055)
        cg.setFillColor(detail.cgColor)
        cg.fillEllipse(in: CGRect(x: center.x-pinRadius,y: center.y-pinRadius,width: pinRadius*2,height: pinRadius*2))
        let fontSize = max(5,radius*0.38*labelScale)
        let y = center.y-radius-fontSize*1.65
        text(city.name,center: CGPoint(x: center.x,y: y),size: fontSize,weight: .semibold,monospacedDigits: false)
        text(state.label,center: CGPoint(x: center.x,y: y-fontSize*1.35),size: fontSize*0.88,weight: .medium,monospacedDigits: true)
    }
    static func text(_ value: String, center: CGPoint, size: CGFloat, weight: NSFont.Weight,
                     alpha: CGFloat = 0.93,monospacedDigits: Bool) {
        let shadow = NSShadow(); shadow.shadowColor = NSColor.black; shadow.shadowBlurRadius = 5; shadow.shadowOffset = CGSize(width: 0,height: -1)
        let font = monospacedDigits ? NSFont.monospacedDigitSystemFont(ofSize: size,weight: weight) : NSFont.systemFont(ofSize: size,weight: weight)
        let attributes: [NSAttributedString.Key: Any] = [.font: font,
            .foregroundColor: NSColor.white.withAlphaComponent(alpha),.shadow: shadow,.kern: size*0.035]
        let string = NSAttributedString(string: value,attributes: attributes)
        string.draw(at: CGPoint(x: center.x-string.size().width/2,y: center.y))
    }
}
