import SwiftUI
import Foundation

// Ruler + lanes. Two separate time indicators (FCP-style):
// - playhead (red): the edit point. Moves on drag/tap/playback only.
// - skimmer (yellow beam): follows the mouse on hover, preview only.
// Drop target: accept video files onto track lanes or empty placeholder.
@MainActor
struct TimelineView: View {
    @Bindable var timeline: Timeline
    @Binding var selectedClip: VideoClip?
    var onImportError: ((String) -> Void)?

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
            }
            .frame(height: 28)

            // One lane per track: clips, red playhead, yellow beam, drop target.
            ForEach(timeline.tracks) { track in
                TrackLaneView(
                    track: track,
                    totalSeconds: totalSeconds,
                    xPosition: xPosition,
                    fraction: fraction,
                    selectedClip: $selectedClip,
                    timeline: timeline,
                    onImportError: onImportError
                )
            }

            // Empty timeline placeholder (drop target when no tracks exist)
            if timeline.tracks.isEmpty {
                EmptyTimelineDropView(
                    onImportError: onImportError,
                    onDrop: { url in
                        handleDropOnEmpty(url: url)
                    }
                )
            }
        }
    }

    private func handleDropOnEmpty(url: URL) {
        Task {
            do {
                let clip = try await VideoClip.make(from: url)
                var newTrack = Track()
                newTrack.insert(clip)
                timeline.tracks.append(newTrack)
                if timeline.outPoint < clip.duration {
                    timeline.outPoint = clip.duration
                }
            } catch {
                onImportError?(error.localizedDescription)
            }
        }
    }
}

// Video file extensions we accept
private let allowedVideoExtensions = Set(["mov", "mp4", "m4v", "avi", "mkv"])

private func isVideoFile(_ url: URL) -> Bool {
    allowedVideoExtensions.contains(url.pathExtension.lowercased())
}

// Per-track lane with drop target
@MainActor
struct TrackLaneView: View {
    let track: Track
    let totalSeconds: Double
    let xPosition: (Fraction, CGFloat) -> CGFloat
    let fraction: (CGFloat, CGFloat) -> Fraction
    @Binding var selectedClip: VideoClip?
    @Bindable var timeline: Timeline
    let onImportError: ((String) -> Void)?

    var body: some View {
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
                        .position(x: xPosition(skim, geo.size.width), y: 20)
                }
                Rectangle()
                    .fill(Color.red)
                    .frame(width: 2, height: 40)
                    .position(x: xPosition(timeline.playhead, geo.size.width), y: 20)
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    timeline.skimmer = fraction(location.x, geo.size.width)
                case .ended:
                    timeline.skimmer = nil
                @unknown default:
                    timeline.skimmer = nil
                }
            }
            .dropDestination(for: URL.self) { urls, location in
                guard let url = urls.first, isVideoFile(url) else { return false }
                handleDrop(url: url, at: location, in: geo.size.width)
                return true
            }
            .frame(height: 40)
        }
    }

    private func handleDrop(url: URL, at location: CGPoint, in width: CGFloat) {
        let trackID = track.id
        Task {
            do {
                let clip = try await VideoClip.make(from: url)
                let startTime = fraction(location.x, width)
                var placedClip = VideoClip(
                    id: clip.id,
                    startTime: startTime,
                    duration: clip.duration,
                    sourceURL: clip.sourceURL,
                    properties: clip.properties
                )
                // Look up live track directly from timeline to avoid stale value copy races
                guard let idx = timeline.tracks.firstIndex(where: { $0.id == trackID }) else { return }
                var liveTrack = timeline.tracks[idx]
                if liveTrack.clips.contains(where: { $0.startTime < placedClip.endTime && placedClip.startTime < $0.endTime }) {
                    let lastEnd = liveTrack.clips.map { $0.endTime }.max() ?? .zero
                    placedClip = VideoClip(
                        id: clip.id,
                        startTime: lastEnd,
                        duration: clip.duration,
                        sourceURL: clip.sourceURL,
                        properties: clip.properties
                    )
                }
                liveTrack.insert(placedClip)
                timeline.tracks[idx] = liveTrack
                if timeline.outPoint < placedClip.endTime {
                    timeline.outPoint = placedClip.endTime
                }
            } catch {
                onImportError?(error.localizedDescription)
            }
        }
    }
}

// Empty timeline placeholder with drop target
@MainActor
struct EmptyTimelineDropView: View {
    let onImportError: ((String) -> Void)?
    let onDrop: (URL) -> Void

    @State private var isTargeted = false

    var body: some View {
        GeometryReader { _ in
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 8]))
                    .foregroundColor(isTargeted ? .blue : .gray)
                    .background(isTargeted ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
                VStack(spacing: 8) {
                    Image(systemName: "arrow.down.doc.fill")
                        .font(.system(size: 32))
                        .foregroundColor(isTargeted ? .blue : .gray)
                    Text("Drop video file here")
                        .font(.headline)
                        .foregroundColor(isTargeted ? .blue : .gray)
                    Text("Supported formats: MP4, MOV, M4V, AVI, MKV")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .dropDestination(for: URL.self) { urls, _ in
                guard let url = urls.first, isVideoFile(url) else { return false }
                onDrop(url)
                return true
            } isTargeted: { targeted in
                isTargeted = targeted
            }
            .frame(height: 100)
        }
        .frame(height: 100)
    }
}
