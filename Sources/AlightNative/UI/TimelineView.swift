import SwiftUI

@MainActor
struct TimelineView: View {
    @Bindable var timeline: Timeline
    @Binding var selectedClip: VideoClip?

    private var totalSeconds: Double {
        max(timeline.outPoint.toDouble, 1.0)
    }

    private var tickSeconds: [Int] {
        let end = Int(timeline.outPoint.toDouble)
        return end >= 0 ? Array(0...end) : []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Ruler: 1-second ticks, drag to scrub (writes Fraction).
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    Rectangle().fill(Color.gray.opacity(0.15))
                    ForEach(tickSeconds, id: \.self) { s in
                        Rectangle()
                            .fill(Color.gray)
                            .frame(width: 1, height: 8)
                            .position(x: geo.size.width * Double(s) / totalSeconds, y: 4)
                        Text("\(s)s")
                            .font(.caption2)
                            .position(x: geo.size.width * Double(s) / totalSeconds + 12, y: 6)
                    }
                    // Playhead
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: 2, height: geo.size.height)
                        .position(x: geo.size.width * timeline.playhead.toDouble / totalSeconds,
                                  y: geo.size.height / 2)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let frac = min(max(value.location.x / max(geo.size.width, 1), 0), 1)
                            let seconds = frac * totalSeconds
                            timeline.playhead = Fraction(Int64(seconds * 1000), 1000)
                        }
                )
            }
            .frame(height: 28)

            // One lane per track, clips as rects, tap to select.
            ForEach(timeline.tracks) { track in
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Color.gray.opacity(0.08))
                        ForEach(track.clips) { clip in
                            let w = geo.size.width * clip.duration.toDouble / totalSeconds
                            let x = geo.size.width * clip.startTime.toDouble / totalSeconds
                            Rectangle()
                                .fill(selectedClip?.id == clip.id ? Color.blue : Color.blue.opacity(0.6))
                                .frame(width: max(w, 4), height: 36)
                                .position(x: x + max(w, 4) / 2, y: 20)
                                .onTapGesture { selectedClip = clip }
                        }
                        Rectangle()
                            .fill(Color.red)
                            .frame(width: 2, height: 40)
                            .position(x: geo.size.width * timeline.playhead.toDouble / totalSeconds, y: 20)
                    }
                }
                .frame(height: 40)
            }
        }
    }
}
