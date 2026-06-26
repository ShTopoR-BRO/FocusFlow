import Foundation

struct Task: Identifiable, Codable {
    let id: UUID
    var title: String
    var description: String?
    var completedSessions: Int
    var createdAt: Date
    var isActive: Bool
    
    init(id: UUID = UUID(), title: String, description: String? = nil, completedSessions: Int = 0, isActive: Bool = false) {
        self.id = id
        self.title = title
        self.description = description
        self.completedSessions = completedSessions
        self.createdAt = Date()
        self.isActive = isActive
    }
}
