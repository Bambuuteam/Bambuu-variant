public struct Property: Sendable {
    public var name: String
    public var baseValue: Double
    public var track: KeyframeTrack

    public init(name: String, baseValue: Double, track: KeyframeTrack) {
        self.name = name
        self.baseValue = baseValue
        self.track = track
    }

    public func evaluate(at time: Fraction) -> Double {
        if track.keyframes.isEmpty {
            return baseValue
        }
        return track.evaluate(at: time)
    }
}
