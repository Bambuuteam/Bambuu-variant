import MetalKit
import SwiftUI

// Preview canvas. Coordinator owns the compositor strongly:
// MTKView.delegate is weak, so without this the delegate would deinit.
struct PreviewView: NSViewRepresentable {
    var timeline: Timeline

    final class Coordinator {
        let frames = FrameProvider()
        var compositor: MetalCompositor?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> MTKView {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("PreviewView: Metal unavailable (MTLCreateSystemDefaultDevice nil)")
        }
        let view = MTKView(frame: .zero, device: device)
        view.preferredFramesPerSecond = 30
        view.colorPixelFormat = .bgra8Unorm
        view.framebufferOnly = true
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        do {
            let comp = try MetalCompositor(device: device, timeline: timeline,
                                           frames: context.coordinator.frames)
            context.coordinator.compositor = comp
            view.delegate = comp
        } catch {
            fatalError("PreviewView: shader compile failed: \(error)")
        }
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        context.coordinator.compositor?.timeline = timeline
    }
}
