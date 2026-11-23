import Foundation

struct VexelSavedEasing: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var x1: Double
    var y1: Double
    var x2: Double
    var y2: Double
}
