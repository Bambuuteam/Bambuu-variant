import SwiftUI
import Foundation
import AVFoundation

if ProcessInfo.processInfo.environment["RUN_MATH_TESTS"] != nil {
    runMathTests()
    exit(0)
}

// Dev-only footage hook (no import UI yet): CLIP_PATH=/path/to/file.mp4
// loads one clip spanning its full duration so the preview path can be
// exercised end to end. Unset (normal launch) = empty 10s timeline.
private func devTimeline() -> Timeline {
    let tl = Timeline(playhead: .zero, inPoint: .zero, outPoint: Fraction(10, 1))
    guard let path = ProcessInfo.processInfo.environment["CLIP_PATH"], !path.isEmpty else {
        return tl
    }
    let url = URL(fileURLWithPath: path)
    let seconds = CMTimeGetSeconds(AVURLAsset(url: url).duration)
    if !seconds.isFinite || seconds <= 0 {
        fatalError("CLIP_PATH set but duration unreadable: \(path)")
    }
    let dur = Fraction(Int64(seconds * 1000), 1000)
    var track = Track()
    track.insert(VideoClip(startTime: .zero, duration: dur, sourceURL: url))
    tl.tracks = [track]
    tl.outPoint = dur
    return tl
}

struct ContentView: View {
    @State private var timeline = devTimeline()
    @State private var selectedClip: VideoClip?

    var body: some View {
        VStack {
            // Live preview: resolves timeline clips at the playhead via
            // MetalCompositor (feature/metal-renderer).
            PreviewView(timeline: timeline)
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
