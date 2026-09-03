import SwiftUI

// Ruler + lanes. Two separate time indicators (FCP-style):
// - playhead (red): the edit point. Moves on drag/tap/playback only.
// - skimmer (yellow beam): follows the mouse on hover, preview only.
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

    private func fraction(atX x: CGFloat, width: CGFloat) -> Fraction {
        let frac = min(max(x / max(width, 1), 0), 1)
        return Fraction(Int64(frac * totalSeconds * 1000), 1000)
    }

    private func xPosition(of time: Fraction, width: CGFloat) -> CGFloat {
        width * time.toDouble / totalSeconds
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Ruler: ticks + red playhead + yellow hover beam.
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
                    if let skim = timeline.skimmer {
                        Rectangle()
                            .fill(Color.yellow)
                            .frame(width: 1, height: geo.size.height)
                            .position(x: xPosition(of: skim, width: geo.size.width),
                                      y: geo.size.height / 2)
                    }
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: 2, height: geo.size.height)
                        .position(x: xPosition(of: timeline.playhead, width: geo.size.width),
                                  y: geo.size.height / 2)
                }
                .contentShape(Rectangle())
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let location):
                        timeline.skimmer = fraction(atX: location.x, width: geo.size.width)
                    case .ended:
                        timeline.skimmer = nil
                    @unknown default:
                        timeline.skimmer = nil
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            timeline.playhead = fraction(atX: value.location.x, width: geo.size.width)
                        }
                )
                // Note: tap-to-place is covered by DragGesture(minimumDistance: 0),
                // which fires on press; hover stays separate via onContinuousHover.
            }
            .frame(height: 28)

            // One lane per track: clips, red playhead, yellow beam.
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
                        if let skim = timeline.skimmer {
                            Rectangle()
                                .fill(Color.yellow)
                                .frame(width: 1, height: 40)
                                .position(x: xPosition(of: skim, width: geo.size.width), y: 20)
                        }
                        Rectangle()
                            .fill(Color.red)
                            .frame(width: 2, height: 40)
                            .position(x: xPosition(of: timeline.playhead, width: geo.size.width), y: 20)
                    }
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            timeline.skimmer = fraction(atX: location.x, width: geo.size.width)
                        case .ended:
                            timeline.skimmer = nil
                        @unknown default:
                            timeline.skimmer = nil
                        }
                    }
                }
                .frame(height: 40)
            }
        }
    }
}
