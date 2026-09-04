import SwiftUI
import Foundation

if ProcessInfo.processInfo.environment["RUN_MATH_TESTS"] != nil {
    runMathTests()
    exit(0)
}

// Default empty timeline (10s range) — import via drag-and-drop
private func defaultTimeline() -> Timeline {
    Timeline(playhead: .zero, inPoint: .zero, outPoint: Fraction(10, 1))
}

struct ContentView: View {
    @State private var timeline = defaultTimeline()
    @State private var selectedClip: VideoClip?
    @State private var importError: String?

    var body: some View {
        VStack {
            // Live preview: resolves timeline clips at the playhead via
            // MetalCompositor (feature/metal-renderer).
            PreviewView(timeline: timeline)
                .frame(maxWidth: .infinity)
                .aspectRatio(16.0 / 9.0, contentMode: .fit)

            if let err = importError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.primary)
                    Spacer()
                    Button("Dismiss") { importError = nil }
                        .buttonStyle(.borderless)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }

            HSplitView {
                TimelineView(
                    timeline: timeline,
                    selectedClip: $selectedClip,
                    onImportError: { importError = $0 }
                )
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