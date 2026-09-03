import SwiftUI
import Foundation

if ProcessInfo.processInfo.environment["RUN_MATH_TESTS"] != nil {
    runMathTests()
    exit(0)
}

struct ContentView: View {
    @State private var timeline = Timeline(playhead: .zero, inPoint: .zero,
                                            outPoint: Fraction(10, 1))
    @State private var selectedClip: VideoClip?

    var body: some View {
        VStack {
            // AGENT C INTEGRATION POINT: replace this placeholder with
            // PreviewView(timeline:) from feature/metal-renderer.
            MetalView()
                .frame(maxWidth: .infinity)
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
            HSplitView {
                TimelineView(timeline: timeline, selectedClip: $selectedClip)
                    .frame(minWidth: 400)
                InspectorView(selectedClip: $selectedClip)
            }
        }
        .padding()
    }
}

struct AlightNativeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

AlightNativeApp.main()
