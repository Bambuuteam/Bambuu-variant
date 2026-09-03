import Foundation

struct Track: Sendable, Identifiable {
    let id: UUID
    private(set) var clips: [VideoClip]

    init(id: UUID = UUID(), clips: [VideoClip] = []) {
        self.id = id
        self.clips = clips.sorted { $0.startTime < $1.startTime }
    }

    mutating func insert(_ clip: VideoClip) {
        for existing in clips {
            if clip.startTime < existing.endTime && existing.startTime < clip.endTime {
                fatalError("Cannot insert clip: overlap detected")
            }
        }
        clips.append(clip)
        clips.sort { $0.startTime < $1.startTime }
    }
}