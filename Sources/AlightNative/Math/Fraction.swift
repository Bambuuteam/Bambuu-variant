public struct Fraction: Comparable, Sendable, Hashable {
    public let numerator: Int64
    public let denominator: Int64

    public init(_ numerator: Int64, _ denominator: Int64) {
        if denominator == 0 {
            fatalError("Fraction denominator cannot be zero")
        }
        // Normalize sign: denominator always positive
        let n: Int64
        let d: Int64
        if denominator < 0 {
            n = -numerator
            d = -denominator
        } else {
            n = numerator
            d = denominator
        }
        // Reduce by GCD
        let g = Fraction.gcd(n.magnitude, d.magnitude)
        let divisor = g == 0 ? 1 : Int64(g)
        self.numerator = n / divisor
        self.denominator = d / divisor
    }

    public static let zero = Fraction(0, 1)
    public static let one = Fraction(1, 1)

    private static func gcd(_ a: UInt64, _ b: UInt64) -> UInt64 {
        var a = a
        var b = b
        while b != 0 {
            let t = b
            b = a % b
            a = t
        }
        return a
    }

    public static func +(lhs: Fraction, rhs: Fraction) -> Fraction {
        Fraction(lhs.numerator * rhs.denominator + rhs.numerator * lhs.denominator,
                 lhs.denominator * rhs.denominator)
    }

    public static func -(lhs: Fraction, rhs: Fraction) -> Fraction {
        Fraction(lhs.numerator * rhs.denominator - rhs.numerator * lhs.denominator,
                 lhs.denominator * rhs.denominator)
    }

    public static func *(lhs: Fraction, rhs: Fraction) -> Fraction {
        Fraction(lhs.numerator * rhs.numerator,
                 lhs.denominator * rhs.denominator)
    }

    public static func /(lhs: Fraction, rhs: Fraction) -> Fraction {
        if rhs.numerator == 0 {
            fatalError("Fraction division by zero")
        }
        return Fraction(lhs.numerator * rhs.denominator,
                        lhs.denominator * rhs.numerator)
    }

    public static func <(lhs: Fraction, rhs: Fraction) -> Bool {
        lhs.numerator * rhs.denominator < rhs.numerator * lhs.denominator
    }

    public var toDouble: Double {
        Double(numerator) / Double(denominator)
    }
}
