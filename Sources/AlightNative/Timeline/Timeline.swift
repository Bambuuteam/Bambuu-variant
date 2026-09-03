import Foundation
import Observation

@Observable
final class Timeline: @unchecked Sendable {
    var tracks: [Track]
    var playhead: Fraction
    var inPoint: Fraction
    var outPoint: Fraction

    init(tracks: [Track] = [], playhead: Fraction = .zero,
         inPoint: Fraction = .zero, outPoint: Fraction = .zero) {
        self.tracks = tracks
        self.playhead = playhead
        self.inPoint = inPoint
        self.outPoint = outPoint
    }

    func clipsAtPlayhead() -> [(track: Int, clip: VideoClip)] {
        var hits: [(track: Int, clip: VideoClip)] = []
        for (index, track) in tracks.enumerated() {
            for clip in track.clips {
                if clip.startTime <= playhead && playhead <= clip.endTime {
                    hits.append((track: index, clip: clip))
                }
            }
        }
        return hits
    }
}
