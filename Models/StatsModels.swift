import Foundation

struct DailyStats: Codable {
    let date: Date
    var completedSessions: Int
    var totalFocusTime: TimeInterval
    
    init(date: Date = Date(), completedSessions: Int = 0, totalFocusTime: TimeInterval = 0) {
        self.date = date
        self.completedSessions = completedSessions
        self.totalFocusTime = totalFocusTime
    }
}

struct WeeklyStats: Codable {
    var dailyStats: [DailyStats]
    
    var totalSessions: Int {
        dailyStats.reduce(0) { $0 + $1.completedSessions }
    }
    
    var totalFocusTime: TimeInterval {
        dailyStats.reduce(0) { $0 + $1.totalFocusTime }
    }
    
    var averageDailySessions: Double {
        guard !dailyStats.isEmpty else { return 0 }
        return Double(totalSessions) / Double(dailyStats.count)
    }
}

struct MonthlyStats: Codable {
    var weeklyStats: [WeeklyStats]
    
    var totalSessions: Int {
        weeklyStats.reduce(0) { $0 + $1.totalSessions }
    }
    
    var totalFocusTime: TimeInterval {
        weeklyStats.reduce(0) { $0 + $1.totalFocusTime }
    }
    
    var averageDailySessions: Double {
        let totalDays = weeklyStats.reduce(0) { $0 + $1.dailyStats.count }
        guard totalDays > 0 else { return 0 }
        return Double(totalSessions) / Double(totalDays)
    }
}

enum StatsPeriod: String, CaseIterable {
    case week = "Week"
    case month = "Month"
}
