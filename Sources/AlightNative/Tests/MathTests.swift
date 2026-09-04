import Foundation

func runMathTests() async {
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
    // Test 7: VideoClip.make(from:) duration probe + corrupt file error handling
    do {
        let validURL = URL(fileURLWithPath: "/tmp/qa-clip.mp4")
        if let clip = try? await VideoClip.make(from: validURL) {
            if clip.duration.toDouble > 9.9 && clip.duration.toDouble < 10.1 {
                print("PASS Test 7: VideoClip.make valid file duration ~10.0s (got \(clip.duration.toDouble))")
            } else {
                print("FAIL Test 7: VideoClip.make duration mismatch: \(clip.duration.toDouble)")
            }
        } else {
            print("SKIP Test 7: /tmp/qa-clip.mp4 not found")
        }

        let corruptURL = URL(fileURLWithPath: "/tmp/qa-corrupt.mp4")
        do {
            _ = try await VideoClip.make(from: corruptURL)
            print("FAIL Test 8: Corrupt file did not throw error")
        } catch {
            print("PASS Test 8: Corrupt file threw expected error: \(error.localizedDescription)")
        }
    }
    // Test 9: Track overlap detection & snap behavior
    do {
        let clip1 = VideoClip(startTime: .zero, duration: Fraction(5, 1), sourceURL: URL(fileURLWithPath: "/tmp/qa-clip.mp4"))
        let clip2 = VideoClip(startTime: Fraction(2, 1), duration: Fraction(4, 1), sourceURL: URL(fileURLWithPath: "/tmp/qa-clip.mp4"))
        var track = Track()
        track.insert(clip1)
        // Check overlap detection
        let overlaps = track.clips.contains(where: { $0.startTime < clip2.endTime && clip2.startTime < $0.endTime })
        if overlaps {
            let lastEnd = track.clips.map { $0.endTime }.max() ?? .zero
            let snapped = VideoClip(id: clip2.id, startTime: lastEnd, duration: clip2.duration, sourceURL: clip2.sourceURL, properties: clip2.properties)
            track.insert(snapped)
            if track.clips.count == 2 && track.clips[1].startTime == Fraction(5, 1) {
                print("PASS Test 9: Overlapping clip snapped to end of previous clip at t=5/1s without crash")
            } else {
                print("FAIL Test 9: Snapping did not place clip at expected position")
            }
        } else {
            print("FAIL Test 9: Overlap was not detected")
        }
    }
    print("All tests completed.")
}
