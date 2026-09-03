import CoreGraphics
import Metal
import MetalKit
import Foundation

// Preview compositor: resolves each clip's source frame at the playhead and
// layers them back-to-front. Memory rule: decode exactly one frame per clip
// per pass, upload, draw, release. No frame cache, no held textures.
final class MetalCompositor: NSObject, MTKViewDelegate, @unchecked Sendable {
    // All Metal objects below are thread-safe for this use (independent
    // command buffers); timeline swaps wholesale from the main thread.
    let device: MTLDevice
    let queue: MTLCommandQueue
    let pipeline: MTLRenderPipelineState
    var timeline: Timeline
    let frames: FrameProvider
    private let gate = NSLock()
    private var rendering = false

    static let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;
    struct VertexOut {
      float4 position [[position]];
      float2 uv;
    };
    vertex VertexOut vertex_main(uint vid [[vertex_id]]) {
      float2 positions[4] = {
        float2(-1, -1), float2(1, -1),
        float2(-1,  1), float2(1,  1)
      };
      float2 uvs[4] = {
        float2(0, 1), float2(1, 1),
        float2(0, 0), float2(1, 0)
      };
      VertexOut out;
      out.position = float4(positions[vid], 0, 1);
      out.uv = uvs[vid];
      return out;
    }
    fragment float4 fragment_main(
      VertexOut in [[stage_in]],
      texture2d<float> tex [[texture(0)]]
    ) {
      constexpr sampler s(filter::linear);
      return tex.sample(s, in.uv);
    }
    """

    init(device: MTLDevice, timeline: Timeline, frames: FrameProvider) throws {
        self.device = device
        self.timeline = timeline
        self.frames = frames
        guard let q = device.makeCommandQueue() else {
            fatalError("MetalCompositor: makeCommandQueue returned nil")
        }
        self.queue = q
        let library: MTLLibrary
        do {
            library = try device.makeLibrary(source: Self.shaderSource, options: nil)
        } catch {
            throw error
        }
        guard let vFn = library.makeFunction(name: "vertex_main"),
              let fFn = library.makeFunction(name: "fragment_main") else {
            fatalError("MetalCompositor: vertex_main/fragment_main missing after compile")
        }
        let pd = MTLRenderPipelineDescriptor()
        pd.vertexFunction = vFn
        pd.fragmentFunction = fFn
        pd.colorAttachments[0].pixelFormat = .bgra8Unorm
        pd.colorAttachments[0].isBlendingEnabled = true
        pd.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pd.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pd.colorAttachments[0].sourceAlphaBlendFactor = .one
        pd.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        do {
            self.pipeline = try device.makeRenderPipelineState(descriptor: pd)
        } catch {
            throw error
        }
        super.init()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // No size-dependent state cached; resize handling is v2 scope.
    }

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor else { return }
        let clips = timeline.clipsAtPlayhead()
        let playhead = timeline.playhead
        guard !clips.isEmpty else {
            // No clips: honest black frame, not a fake image.
            guard let buffer = queue.makeCommandBuffer(),
                  let encoder = buffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }
            encoder.endEncoding()
            buffer.present(drawable)
            buffer.commit()
            return
        }
        gate.lock()
        if rendering {
            gate.unlock()
            return // Drop: next vsync retries. Never queue overlapping presents.
        }
        rendering = true
        gate.unlock()
        Task {
            await self.renderLayers(clips: clips, playhead: playhead,
                                    drawable: drawable, descriptor: descriptor)
            self.gate.withLock { self.rendering = false }
        }
    }

    private func renderLayers(clips: [(track: Int, clip: VideoClip)], playhead: Fraction,
                              drawable: CAMetalDrawable,
                              descriptor: MTLRenderPassDescriptor) async {
        guard let buffer = queue.makeCommandBuffer(),
              let encoder = buffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }
        encoder.setRenderPipelineState(pipeline)
        var drewAnything = false
        for (_, clip) in clips.sorted(by: { $0.track < $1.track }) {
            do {
                let image = try await frames.frame(for: clip, at: playhead)
                if let tex = upload(image) {
                    encoder.setFragmentTexture(tex, index: 0)
                    encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
                    drewAnything = true
                }
            } catch {
                continue // Clip unreadable this frame: skip layer, keep others.
            }
        }
        _ = drewAnything
        encoder.endEncoding()
        buffer.present(drawable)
        buffer.commit()
    }

    // CGImage -> RGBA8 Metal texture. Local only, released after the draw.
    private func upload(_ image: CGImage) -> MTLTexture? {
        let w = image.width, h = image.height
        guard w > 0 && h > 0 else { return nil }
        let rowBytes = w * 4
        var pixels = [UInt8](repeating: 0, count: h * rowBytes)
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        guard let ctx = CGContext(data: &pixels, width: w, height: h,
                                  bitsPerComponent: 8, bytesPerRow: rowBytes,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: bitmapInfo) else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm,
                                                            width: w, height: h, mipmapped: false)
        desc.usage = .shaderRead
        guard let tex = device.makeTexture(descriptor: desc) else { return nil }
        tex.replace(region: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0,
                    withBytes: pixels, bytesPerRow: rowBytes)
        return tex
    }
}
