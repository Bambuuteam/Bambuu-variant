public enum Easing: Sendable, Hashable {
    case linear
    case easeIn
    case easeOut
    case easeInOut
    case custom(CubicBezier)

    public func evaluate(at t: Double) -> Double {
        switch self {
        case .linear:
            return t
        case .easeIn:
            return CubicBezier(p0: (0, 0), p1: (0.42, 0.0),
                               p2: (1.0, 1.0), p3: (1, 1)).solveForY(atX: t)
        case .easeOut:
            return CubicBezier(p0: (0, 0), p1: (0.0, 0.0),
                               p2: (0.58, 1.0), p3: (1, 1)).solveForY(atX: t)
        case .easeInOut:
            return CubicBezier(p0: (0, 0), p1: (0.42, 0.0),
                               p2: (0.58, 1.0), p3: (1, 1)).solveForY(atX: t)
        case .custom(let bezier):
            return bezier.solveForY(atX: t)
        }
    }
}
