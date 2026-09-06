import ScreenSaver

@objc(TerraScreenSaverView)
public final class TerraScreenSaverView: ScreenSaverView {
    private var scene: EarthSceneView?
    public override init?(frame: NSRect,isPreview: Bool) {
        super.init(frame: frame,isPreview: isPreview)
        animationTimeInterval = 1.0/30.0
        // Even the Settings thumbnail uses real time; debug controls exist only in the app.
        let scene = EarthSceneView(frame: bounds,preview: false)
        scene.autoresizingMask = [.width,.height]; addSubview(scene); self.scene = scene
    }
    public required init?(coder: NSCoder) { nil }
    public override func startAnimation() { super.startAnimation(); scene?.start(ownTimer: false) }
    public override func stopAnimation() { scene?.stop(); super.stopAnimation() }
    public override func animateOneFrame() { scene?.renderFrame() }
}
