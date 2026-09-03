public struct Keyframe: Sendable {
    public var time: Fraction
    public var value: Double
    public var easing: Easing

    public init(time: Fraction, value: Double, easing: Easing) {
        self.time = time
        self.value = value
        self.easing = easing
    }
}
