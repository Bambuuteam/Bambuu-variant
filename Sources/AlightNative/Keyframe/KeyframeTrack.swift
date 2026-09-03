public struct KeyframeTrack: Sendable {
    public private(set) var keyframes: [Keyframe]

    public init() {
        self.keyframes = []
    }

    public mutating func insert(_ keyframe: Keyframe) {
        var idx = 0
        while idx < keyframes.count && keyframes[idx].time < keyframe.time {
            idx += 1
        }
        keyframes.insert(keyframe, at: idx)
    }

    public func evaluate(at time: Fraction) -> Double {
        if keyframes.isEmpty { return 0.0 }
        if time <= keyframes[0].time { return keyframes[0].value }
        if time >= keyframes[keyframes.count - 1].time { return keyframes[keyframes.count - 1].value }

        var i = 0
        while i < keyframes.count - 1 && keyframes[i + 1].time <= time {
            i += 1
        }

        let prev = keyframes[i]
        let next = keyframes[i + 1]

        let tDouble = time.toDouble
        let tPrev = prev.time.toDouble
        let tNext = next.time.toDouble
        let denom = tNext - tPrev
        if denom == 0 {
            fatalError("KeyframeTrack: adjacent keyframes share identical time")
        }
        let t = (tDouble - tPrev) / denom
        let easedT = prev.easing.evaluate(at: t)
        return prev.value + (next.value - prev.value) * easedT
    }
}
