import SwiftUI
import MetalKit

struct MetalView: NSViewRepresentable {
    func makeCoordinator() -> Renderer {
        Renderer()
    }

    func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.delegate = context.coordinator
        // Use coordinator's device — ensures single device for view + renderer
        mtkView.device = context.coordinator.device
        // Cornflower blue: 100,149,237 / 255
        mtkView.clearColor = MTLClearColor(red: 0.392, green: 0.584, blue: 0.929, alpha: 1.0)
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.framebufferOnly = true
        mtkView.isPaused = false
        mtkView.enableSetNeedsDisplay = false
        // preferredFramesPerSecond defaults to 60 — fine for Task 0.5
        return mtkView
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        // No dynamic props yet
    }
}
