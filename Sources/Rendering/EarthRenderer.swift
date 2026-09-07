import MetalKit
import ImageIO
#if SWIFT_PACKAGE
import TerraCore
#endif

struct SceneUniforms {
    var viewport: SIMD4<Float>
    var right: SIMD4<Float>
    var up: SIMD4<Float>
    var front: SIMD4<Float>
    var sun: SIMD4<Float>
    var style: SIMD4<Float>
    var moon: SIMD4<Float>
    var moonLight: SIMD4<Float>
    var moonSurface: SIMD4<Float>
}

final class EarthRenderer {
    let device: MTLDevice
    private let queue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState
    private let textures: [MTLTexture]
    private let framesInFlight = DispatchSemaphore(value: 3)
    var lastError: String?

    init(device: MTLDevice) throws {
        self.device = device
        guard let queue = device.makeCommandQueue() else { throw RenderError.unavailable }
        self.queue = queue
        let source = try String(contentsOf: SceneAssets.resourceURL("Scene.metal"), encoding: .utf8)
        let library = try device.makeLibrary(source: source, options: nil)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "sceneVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "sceneFragment")
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm_srgb
        pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        textures = try ["earth-day.jpg", "earth-night.jpg", "earth-clouds.jpg", "moon.jpg", "milky-way.jpg"].enumerated().map { index, name in
            let url = try SceneAssets.resourceURL(name)
            // A 4K equirectangular map provides about 2K samples across the visible
            // hemisphere, matching Terra's ~2K Earth disc on a 5K screen.
            let textureLimit = index == 3 ? 2048 : 4096
            guard let source = CGImageSourceCreateWithURL(url as CFURL,nil),
                  let image = CGImageSourceCreateThumbnailAtIndex(source,0,[
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceThumbnailMaxPixelSize: textureLimit,
                    kCGImageSourceShouldCacheImmediately: true
                  ] as CFDictionary) else { throw RenderError.unavailable }
            guard let context = CGContext(data: nil, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width*4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw RenderError.unavailable }
            context.draw(image,in: CGRect(x: 0,y: 0,width: image.width,height: image.height))
            guard let pixels = context.data else { throw RenderError.unavailable }
            let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: index == 2 ? .rgba8Unorm : .rgba8Unorm_srgb,
                width: image.width,height: image.height,mipmapped: true)
            textureDescriptor.storageMode = .shared
            textureDescriptor.usage = .shaderRead
            guard let texture = device.makeTexture(descriptor: textureDescriptor),
                  let command = queue.makeCommandBuffer(), let blit = command.makeBlitCommandEncoder()
            else { throw RenderError.unavailable }
            texture.replace(region: MTLRegionMake2D(0,0,image.width,image.height),mipmapLevel: 0,
                withBytes: pixels,bytesPerRow: image.width*4)
            blit.generateMipmaps(for: texture); blit.endEncoding()
            command.commit(); command.waitUntilCompleted()
            if let error = command.error { throw error }
            return texture
        }
    }

    private func encode(pass: MTLRenderPassDescriptor, buffer: MTLCommandBuffer, uniforms: SceneUniforms) {
        guard let encoder = buffer.makeRenderCommandEncoder(descriptor: pass) else { return }
        var values = uniforms
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentBytes(&values, length: MemoryLayout<SceneUniforms>.stride, index: 0)
        for (index, texture) in textures.enumerated() { encoder.setFragmentTexture(texture, index: index) }
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
    }

    func draw(view: MTKView, uniforms: SceneUniforms) {
        guard framesInFlight.wait(timeout: .now()) == .success else { return }
        guard let pass = view.currentRenderPassDescriptor, let drawable = view.currentDrawable,
              let buffer = queue.makeCommandBuffer() else { framesInFlight.signal(); return }
        // During Retina/fullscreen resize, the drawable can lag MTKView.drawableSize.
        // Always describe the texture actually acquired for this frame.
        var current = uniforms
        let width = Float(drawable.texture.width), height = Float(drawable.texture.height)
        let xScale = width/uniforms.viewport.x, yScale = height/uniforms.viewport.y
        let radialScale = min(width,height)/min(uniforms.viewport.x,uniforms.viewport.y)
        current.viewport = SIMD4(width,height,uniforms.viewport.z*radialScale,uniforms.viewport.w*yScale)
        current.moon = SIMD4(uniforms.moon.x*xScale,uniforms.moon.y*yScale,uniforms.moon.z*radialScale,uniforms.moon.w)
        encode(pass: pass, buffer: buffer, uniforms: current)
        let gate = framesInFlight
        buffer.addCompletedHandler { _ in gate.signal() }
        buffer.present(drawable)
        buffer.commit()
    }

    /// Runs the actual GPU pipeline into a local image for deterministic QA.
    func snapshot(uniforms: SceneUniforms) throws -> NSBitmapImageRep {
        let width = Int(uniforms.viewport.x), height = Int(uniforms.viewport.y)
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm_srgb, width: width, height: height, mipmapped: false)
        descriptor.storageMode = .shared; descriptor.usage = [.renderTarget]
        guard let texture = device.makeTexture(descriptor: descriptor), let buffer = queue.makeCommandBuffer() else { throw RenderError.unavailable }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        encode(pass: pass, buffer: buffer, uniforms: uniforms)
        buffer.commit(); buffer.waitUntilCompleted()
        if let error = buffer.error { throw error }
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: width*4, bitsPerPixel: 32), let bytes = rep.bitmapData else { throw RenderError.unavailable }
        texture.getBytes(bytes, bytesPerRow: width*4, from: MTLRegionMake2D(0,0,width,height), mipmapLevel: 0)
        for i in stride(from: 0, to: width*height*4, by: 4) { let b = bytes[i]; bytes[i] = bytes[i+2]; bytes[i+2] = b }
        return rep
    }
    enum RenderError: Error { case unavailable }
}
