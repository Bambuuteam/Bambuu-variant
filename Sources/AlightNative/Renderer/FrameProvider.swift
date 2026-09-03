import AVFoundation
import CoreGraphics
import Foundation

// Resolves one source frame per call. Holds generators per URL (cheap),
// never holds decoded frames: each CGImage is returned to the caller and
// released after the draw. No frame cache of any kind.
actor FrameProvider {
    private var generators: [URL: AVAssetImageGenerator] = [:]

    private func generator(for url: URL) -> AVAssetImageGenerator {
        if let g = generators[url] { return g }
        let asset = AVURLAsset(url: url)
        let g = AVAssetImageGenerator(asset: asset)
        g.requestedTimeToleranceBefore = .zero
        g.requestedTimeToleranceAfter = .zero
        g.appliesPreferredTrackTransform = true
        generators[url] = g
        return g
    }

    // Timeline time -> source seconds via the clip's own remap curve,
    // then exact-frame hardware decode. Throws on any failure:
    // missing file, out-of-range time, decode error. Never a placeholder.
    func frame(for clip: VideoClip, at timelineTime: Fraction) async throws -> CGImage {
        let sourceSeconds = max(clip.resolveSourceTime(at: timelineTime), 0)
        let g = generator(for: clip.sourceURL)
        var actual = CMTime.zero
        return try g.copyCGImage(
            at: CMTime(seconds: sourceSeconds, preferredTimescale: 600),
            actualTime: &actual
        )
    }
}
