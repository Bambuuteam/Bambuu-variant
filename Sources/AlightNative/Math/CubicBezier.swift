public struct CubicBezier: Sendable, Hashable {
    public var p0: (x: Double, y: Double)
    public var p1: (x: Double, y: Double)
    public var p2: (x: Double, y: Double)
    public var p3: (x: Double, y: Double)

    public init(p0: (x: Double, y: Double), p1: (x: Double, y: Double),
                p2: (x: Double, y: Double), p3: (x: Double, y: Double)) {
        self.p0 = p0
        self.p1 = p1
        self.p2 = p2
        self.p3 = p3
    }

    // De Casteljau algorithm. t in [0,1].
    public func evaluate(at t: Double) -> (x: Double, y: Double) {
        let u = min(max(t, 0), 1)
        // Level 1
        let q0x = (1 - u) * p0.x + u * p1.x
        let q0y = (1 - u) * p0.y + u * p1.y
        let q1x = (1 - u) * p1.x + u * p2.x
        let q1y = (1 - u) * p1.y + u * p2.y
        let q2x = (1 - u) * p2.x + u * p3.x
        let q2y = (1 - u) * p2.y + u * p3.y
        // Level 2
        let r0x = (1 - u) * q0x + u * q1x
        let r0y = (1 - u) * q0y + u * q1y
        let r1x = (1 - u) * q1x + u * q2x
        let r1y = (1 - u) * q1y + u * q2y
        // Level 3
        return ((1 - u) * r0x + u * r1x, (1 - u) * r0y + u * r1y)
    }

    // Core curve evaluator: binary search + 3 Newton-Raphson iterations.
    // x must be in [0,1]. Clamp input, do not crash.
    public func solveForY(atX x: Double, epsilon: Double = 1e-6) -> Double {
        let clampedX = min(max(x, 0), 1)

        // Binary search for t where x(t) ~= clampedX
        var lo: Double = 0
        var hi: Double = 1
        var t: Double = 0.5
        for _ in 0..<40 {
            let (xVal, _) = evaluate(at: t)
            let diff = xVal - clampedX
            if abs(diff) < epsilon {
                break
            }
            if xVal < clampedX {
                lo = t
            } else {
                hi = t
            }
            let next = (lo + hi) / 2
            if abs(next - t) < 1e-9 {
                t = next
                break
            }
            t = next
        }

        // Newton-Raphson refinement: exactly 3 iterations
        for _ in 0..<3 {
            let (xVal, _) = evaluate(at: t)
            let dx = xVal - clampedX
            if abs(dx) < epsilon {
                break
            }
            // Numerical derivative dx/dt
            let h: Double = 0.001
            let dxdt = (evaluate(at: t + h).x - evaluate(at: t - h).x) / (2 * h)
            if abs(dxdt) < 1e-6 {
                break
            }
            t = t - dx / dxdt
            if t < 0 { t = 0 }
            if t > 1 { t = 1 }
        }

        return evaluate(at: t).y
    }

    public static func ==(lhs: CubicBezier, rhs: CubicBezier) -> Bool {
        lhs.p0.x == rhs.p0.x && lhs.p0.y == rhs.p0.y &&
        lhs.p1.x == rhs.p1.x && lhs.p1.y == rhs.p1.y &&
        lhs.p2.x == rhs.p2.x && lhs.p2.y == rhs.p2.y &&
        lhs.p3.x == rhs.p3.x && lhs.p3.y == rhs.p3.y
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(p0.x)
        hasher.combine(p0.y)
        hasher.combine(p1.x)
        hasher.combine(p1.y)
        hasher.combine(p2.x)
        hasher.combine(p2.y)
        hasher.combine(p3.x)
        hasher.combine(p3.y)
    }
}
