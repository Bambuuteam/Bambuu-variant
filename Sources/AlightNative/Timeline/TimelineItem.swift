import Foundation

protocol TimelineItem: Identifiable, Sendable {
    var id: UUID { get }
    var startTime: Fraction { get }
    var duration: Fraction { get }
    var properties: [String: Property] { get }
}

extension TimelineItem {
    var endTime: Fraction {
        startTime + duration
    }
}