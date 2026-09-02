import MetalKit
import simd

struct Vertex {
    var position: SIMD2<Float>
    var color: SIMD4<Float>
}

final class Renderer: NSObject, MTKViewDelegate {
    let device: MTLDevice?
    let commandQueue: MTLCommandQueue?
    var pipelineState: MTLRenderPipelineState?
    var vertexBuffer: MTLBuffer?

    override init() {
        self.device = MTLCreateSystemDefaultDevice()
        self.commandQueue = device?.makeCommandQueue()
        super.init()

        guard let device = device else {
            print("Renderer: MTLCreateSystemDefaultDevice returned nil — Metal unavailable")
            return
        }

        // Shader compilation via runtime string — Task 1 constraint: no .metal files
        do {
            let library = try device.makeLibrary(source: shaderSource, options: nil)
            guard let vertexFunc = library.makeFunction(name: "vertex_main") else {
                print("Renderer: failed to find vertex_main in library")
                return
            }
            guard let fragmentFunc = library.makeFunction(name: "fragment_main") else {
                print("Renderer: failed to find fragment_main in library")
                return
            }

            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = vertexFunc
            descriptor.fragmentFunction = fragmentFunc
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

            pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
            print("Renderer: pipeline compiled successfully")
        } catch {
            // Surface errors clearly — do not silently swallow
            print("Renderer: shader compilation / pipeline creation failed: \(error)")
            if let localized = (error as NSError).localizedDescription as String? {
                print("  details: \(localized)")
            }
        }

        // Hardcoded quad — 2 triangles = 6 vertices, ~200x200 points centered in 400x300 view
        // NDC: full view is 2x2, so 200px/400px = 1.0 NDC width, 200px/300px ≈ 1.33 NDC height — use 0.5 for visibility
        let vertices: [Vertex] = [
            // Triangle 1
            Vertex(position: SIMD2<Float>(-0.5, -0.5), color: SIMD4<Float>(1, 0.2, 0.2, 1)), // bottom-left red
            Vertex(position: SIMD2<Float>( 0.5, -0.5), color: SIMD4<Float>(0.2, 1, 0.2, 1)), // bottom-right green
            Vertex(position: SIMD2<Float>(-0.5,  0.5), color: SIMD4<Float>(0.2, 0.2, 1, 1)), // top-left blue
            // Triangle 2
            Vertex(position: SIMD2<Float>( 0.5, -0.5), color: SIMD4<Float>(0.2, 1, 0.2, 1)), // bottom-right green
            Vertex(position: SIMD2<Float>( 0.5,  0.5), color: SIMD4<Float>(1, 1, 0.2, 1)), // top-right yellow
            Vertex(position: SIMD2<Float>(-0.5,  0.5), color: SIMD4<Float>(0.2, 0.2, 1, 1)), // top-left blue
        ]

        vertexBuffer = device.makeBuffer(bytes: vertices, length: MemoryLayout<Vertex>.stride * vertices.count, options: [])
        if vertexBuffer == nil {
            print("Renderer: failed to create vertex buffer")
        } else {
            print("Renderer: vertex buffer created (\(vertices.count) vertices, \(MemoryLayout<Vertex>.stride * vertices.count) bytes)")
        }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // No-op for Task 1 — quad is in NDC, not pixel-dependent. Resize handling explicit note in PR.
    }

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let commandQueue = commandQueue,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            return
        }

        // If pipeline/buffer ready, draw quad after clear; otherwise just clear (fallback)
        if let pipelineState = pipelineState, let vertexBuffer = vertexBuffer {
            encoder.setRenderPipelineState(pipelineState)
            encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        }
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
