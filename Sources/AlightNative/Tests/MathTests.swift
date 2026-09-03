func runMathTests() {
    // Test 1: Fraction(1,2) + Fraction(1,3) == Fraction(5,6)
    do {
        let result = Fraction(1, 2) + Fraction(1, 3)
        let expected = Fraction(5, 6)
        if result == expected {
            print("PASS Test 1: Fraction addition \(result.numerator)/\(result.denominator) == 5/6")
        } else {
            print("FAIL Test 1: Fraction addition got \(result.numerator)/\(result.denominator), expected 5/6")
        }
    }
    // Test 2: Fraction(2,4) == Fraction(1,2) (reduction check)
    do {
        let result = Fraction(2, 4)
        if result.numerator == 1 && result.denominator == 2 {
            print("PASS Test 2: Fraction reduction 2/4 -> 1/2")
        } else {
            print("FAIL Test 2: Fraction reduction got \(result.numerator)/\(result.denominator), expected 1/2")
        }
    }
    // Test 3: CubicBezier linear solveForY(atX: 0.5) ~= 0.5
    do {
        let bezier = CubicBezier(p0: (0, 0), p1: (0, 0), p2: (1, 1), p3: (1, 1))
        let result = bezier.solveForY(atX: 0.5)
        if abs(result - 0.5) < 0.001 {
            print("PASS Test 3: CubicBezier solveForY got \(result), expected 0.5")
        } else {
            print("FAIL Test 3: CubicBezier solveForY got \(result), expected 0.5 within 0.001")
        }
    }
    // Test 4: KeyframeTrack linear 0->1 evaluate at 1/2 ~= 0.5
    do {
        var track = KeyframeTrack()
        track.insert(Keyframe(time: Fraction(0, 1), value: 0.0, easing: .linear))
        track.insert(Keyframe(time: Fraction(1, 1), value: 1.0, easing: .linear))
        let result = track.evaluate(at: Fraction(1, 2))
        if abs(result - 0.5) < 0.001 {
            print("PASS Test 4: KeyframeTrack evaluate got \(result), expected 0.5")
        } else {
            print("FAIL Test 4: KeyframeTrack evaluate got \(result), expected 0.5 within 0.001")
        }
    }
    // Test 5: Empty KeyframeTrack evaluate returns 0.0
    do {
        let track = KeyframeTrack()
        let result = track.evaluate(at: Fraction(1, 2))
        if result == 0.0 {
            print("PASS Test 5: Empty track got 0.0")
        } else {
            print("FAIL Test 5: Empty track got \(result), expected 0.0")
        }
    }
    // Test 6: evaluate before first keyframe returns first value
    do {
        var track = KeyframeTrack()
        track.insert(Keyframe(time: Fraction(2, 1), value: 10.0, easing: .linear))
        let result = track.evaluate(at: Fraction(1, 2))
        if result == 10.0 {
            print("PASS Test 6: before-first got 10.0")
        } else {
            print("FAIL Test 6: before-first got \(result), expected 10.0")
        }
    }
    print("All tests completed.")
}
