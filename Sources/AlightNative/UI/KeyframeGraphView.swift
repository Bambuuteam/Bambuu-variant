import SwiftUI

// Time-remap curve for the selected clip, sampled via resolveSourceTime.
// Dragging a handle edits that keyframe's value in the bound clip.
@MainActor
struct KeyframeGraphView: View {
    @Binding var clip: VideoClip?

    private let w: CGFloat = 300
    private let h: CGFloat = 200

    private func curvePoints(for clip: VideoClip) -> [CGPoint] {
        let dur = max(clip.duration.toDouble, 0.001)
        return (0...100).map { i in
            let localSeconds = dur * Double(i) / 100.0
            let t = Fraction(Int64(localSeconds * 1000), 1000)
            let src = clip.resolveSourceTime(at: clip.startTime + t)
            return CGPoint(x: w * CGFloat(i) / 100.0,
                           y: h - h * CGFloat(src / dur))
        }
    }

    private func handlePoint(keyframe: Keyframe, duration: Double) -> CGPoint {
        let dur = max(duration, 0.001)
        return CGPoint(x: w * CGFloat(keyframe.time.toDouble / dur),
                       y: h - h * CGFloat(keyframe.value / dur))
    }

    var body: some View {
        VStack {
            if let clip {
                let dur = max(clip.duration.toDouble, 0.001)
                ZStack {
                    Rectangle().fill(Color.gray.opacity(0.1)).frame(width: w, height: h)
                    Path { path in
                        let pts = curvePoints(for: clip)
                        path.move(to: pts[0])
                        for p in pts.dropFirst() { path.addLine(to: p) }
                    }
                    .stroke(Color.blue, lineWidth: 2)
                    ForEach(clip.properties["timeRemap"]?.track.keyframes ?? [], id: \.time) { kf in
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 12, height: 12)
                            .position(handlePoint(keyframe: kf, duration: dur))
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        var c = clip
                                        guard var prop = c.properties["timeRemap"] else { return }
                                        var track = prop.track
                                        let newSrc = dur * (1.0 - Double(min(max(value.location.y, 0), h) / h))
                                        track.setValue(max(newSrc, 0), at: kf.time)
                                        prop.track = track
                                        c.properties["timeRemap"] = prop
                                        self.clip = c
                                    }
                            )
                    }
                }
                .frame(width: w, height: h)
            } else {
                Text("Select a clip")
                    .foregroundColor(.gray)
                    .frame(width: w, height: h)
            }
        }
    }
}
