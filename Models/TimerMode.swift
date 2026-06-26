import SwiftUI

enum TimerMode: String, CaseIterable {
    case focus = "Focus Session"
    case shortBreak = "Short Break"
    case longBreak = "Long Break"
    
    var duration: TimeInterval {
        switch self {
        case .focus: return 25 * 60
        case .shortBreak: return 5 * 60
        case .longBreak: return 15 * 60
        }
    }
    
    var icon: String {
        switch self {
        case .focus: return "brain.head.profile"
        case .shortBreak: return "cup.and.saucer.fill"
        case .longBreak: return "bed.double.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .focus: return .blue
        case .shortBreak: return .green
        case .longBreak: return .purple
        }
    }
    
    var darkColor: Color {
        switch self {
        case .focus: return Color(red: 0.2, green: 0.4, blue: 0.8)
        case .shortBreak: return Color(red: 0.2, green: 0.7, blue: 0.3)
        case .longBreak: return Color(red: 0.6, green: 0.3, blue: 0.8)
        }
    }
    
    var notificationTitle: String {
        switch self {
        case .focus: return "Focus Session Complete! 🎯"
        case .shortBreak: return "Break Time is Over! ⏰"
        case .longBreak: return "Long Break is Over! 🌟"
        }
    }
    
    var notificationBody: String {
        switch self {
        case .focus: return "Great job! Time for a break."
        case .shortBreak: return "Ready to focus again?"
        case .longBreak: return "Ready for another productive session?"
        }
    }
}
