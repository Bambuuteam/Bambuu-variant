import Foundation

struct VideoClip: TimelineItem, Sendable {
    let id: UUID
    let startTime: Fraction
    let duration: Fraction
    var properties: [String: Property]
    let sourceURL: URL

    init(id: UUID = UUID(), startTime: Fraction, duration: Fraction,
         sourceURL: URL, properties: [String: Property] = [:]) {
        if duration <= .zero {
            fatalError("VideoClip requires positive duration (got \(duration.numerator)/\(duration.denominator))")
        }
        self.id = id
        self.startTime = startTime
        self.duration = duration
        self.sourceURL = sourceURL
        // Default 1x linear remap: local 0 -> source 0, local duration -> source duration.
        // Caller-supplied timeRemap wins if provided.
        var track = KeyframeTrack()
        track.insert(Keyframe(time: .zero, value: 0.0, easing: .linear))
        track.insert(Keyframe(time: duration, value: duration.toDouble, easing: .linear))
        let def = Property(name: "timeRemap", baseValue: 0.0, track: track)
        self.properties = properties.merging(["timeRemap": def], uniquingKeysWith: { supplied, _ in supplied })
    }

    // Timeline-local time -> source seconds via the timeRemap curve.
    // This is the graph-based remap: curve shape = speed curve.
    func resolveSourceTime(at timelineTime: Fraction) -> Double {
        guard let timeRemap = properties["timeRemap"] else {
            fatalError("VideoClip missing required timeRemap property")
        }
        let local = timelineTime - startTime
        let clamped: Fraction
        if local <= .zero {
            clamped = .zero
        } else if duration <= local {
            clamped = duration
        } else {
            clamped = local
        }
        return timeRemap.evaluate(at: clamped)
    }
}
