import MetalKit

final class Renderer: NSObject, MTKViewDelegate {
    let device: MTLDevice?
    let commandQueue: MTLCommandQueue?

    override init() {
        self.device = MTLCreateSystemDefaultDevice()
        self.commandQueue = device?.makeCommandQueue()
        super.init()
        if device == nil {
            print("Renderer: MTLCreateSystemDefaultDevice returned nil — Metal unavailable")
        }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // No-op for Task 0.5 — no geometry to resize
    }

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let commandQueue = commandQueue,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            return
        }
        // Clear only — pass descriptor already encodes view.clearColor (cornflower blue)
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
