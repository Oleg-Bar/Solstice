import AppKit

public enum SceneAssets {
    public static func resourceURL(_ name: String) throws -> URL {
        #if SWIFT_PACKAGE
        let root = Bundle.module.resourceURL!.appendingPathComponent("Resources")
        #else
        let root = Bundle(for: EarthSceneView.self).resourceURL!
        #endif
        let url = root.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw NSError(domain: "Terra", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing local resource: \(name)"])
        }
        return url
    }
}
