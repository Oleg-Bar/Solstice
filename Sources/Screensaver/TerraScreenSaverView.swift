import ScreenSaver

@objc(TerraScreenSaverView)
public final class TerraScreenSaverView: ScreenSaverView {
    private var scene: EarthSceneView?
    public override init?(frame: NSRect,isPreview: Bool) {
        super.init(frame: frame,isPreview: isPreview)
        // Even the Settings thumbnail uses real time; debug controls exist only in the app.
        let scene = EarthSceneView(frame: bounds,preview: false)
        // The system saver host can report its private compositor window as
        // occluded. Rendering must follow ScreenSaverView's animation lifecycle.
        scene.rendersWhenOccluded = true
        scene.configuration.automaticIPLocation = IPLocationConsentStore.decision == true
        scene.autoresizingMask = [.width,.height]; addSubview(scene); self.scene = scene
        animationTimeInterval = 1.0/Double(scene.configuration.preferredFramesPerSecond)
    }
    public required init?(coder: NSCoder) { nil }
    public override func startAnimation() { super.startAnimation(); scene?.start(ownTimer: false) }
    public override func stopAnimation() { scene?.stop(); super.stopAnimation() }
    public override func animateOneFrame() { scene?.renderFrame() }
}
