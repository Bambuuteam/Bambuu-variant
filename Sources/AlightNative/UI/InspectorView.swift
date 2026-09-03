import SwiftUI

@MainActor
struct InspectorView: View {
    @Binding var selectedClip: VideoClip?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let clip = selectedClip {
                Text("Clip Inspector").font(.headline)
                Text(URL(fileURLWithPath: clip.sourceURL.path).lastPathComponent)
                    .font(.subheadline)
                Text("start: \(clip.startTime.numerator)/\(clip.startTime.denominator)s")
                    .font(.caption)
                Text("duration: \(clip.duration.numerator)/\(clip.duration.denominator)s")
                    .font(.caption)
                KeyframeGraphView(clip: $selectedClip)
            } else {
                Text("No clip selected").foregroundColor(.gray)
            }
        }
        .padding()
        .frame(width: 330)
    }
}
