import SwiftUI
import Combine
import UserNotifications

class TimerViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var timeRemaining: TimeInterval
    @Published var timerMode: TimerMode = .focus
    @Published var isRunning = false
    @Published var completedPomodoros = 0
    @Published var showCompletionAlert = false
    @Published var completionMessage = ""
    @Published var isDarkMode = false
    @Published var tasks: [Task] = []
    @Published var activeTaskId: UUID?
    @Published var showingTaskEditor = false
    @Published var editingTask: Task?
    @Published var taskTitle = ""
    @Published var taskDescription = ""
    @Published var showingStats = false
    @Published var dailyStats: [DailyStats] = []
    @Published var selectedPeriod: StatsPeriod = .week
    
    // MARK: - Private Properties
    private var timer: Timer?
    private var initialDuration: TimeInterval
    private let notificationCenter = UNUserNotificationCenter.current()
    private let pomodorosBeforeLongBreak = 4
    private let tasksKey = "savedTasks"
    private let activeTaskIdKey = "activeTaskId"
    private let statsKey = "dailyStats"
    private let themeKey = "isDarkMode"
    
    // MARK: - Computed Properties
    var progress: Double {
        guard initialDuration > 0 else { return 0 }
        return 1 - (timeRemaining / initialDuration)
    }
    
    var formattedTime: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var timerColor: Color {
        isDarkMode ? timerMode.darkColor : timerMode.color
    }
    
    var shouldStartLongBreak: Bool {
        completedPomodoros % pomodorosBeforeLongBreak == 0 && completedPomodoros > 0
    }
    
    var backgroundColor: Color {
        isDarkMode ? Color(red: 0.1, green: 0.1, blue: 0.15) : Color(.systemBackground)
    }
    
    var secondaryBackgroundColor: Color {
        isDarkMode ? Color(red: 0.15, green: 0.15, blue: 0.2) : Color(.systemGray6)
    }
    
    var textColor: Color {
        isDarkMode ? .white : .primary
    }
    
    var secondaryTextColor: Color {
        isDarkMode ? .gray : .secondary
    }
    
    var activeTask: Task? {
        tasks.first { $0.id == activeTaskId }
    }
    
    var activeTaskName: String {
        activeTask?.title ?? "No Active Task"
    }
    
    // MARK: - Stats Computed Properties
    var todayStats: DailyStats {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return dailyStats.first { calendar.isDate($0.date, inSameDayAs: today) } ?? DailyStats(date: today)
    }
    
    var weeklyStats: WeeklyStats {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: today) else {
            return WeeklyStats(dailyStats: [])
        }
        
        let weekStats = dailyStats.filter { $0.date >= weekAgo && $0.date <= today }
        return WeeklyStats(dailyStats: weekStats)
    }
    
    var monthlyStats: MonthlyStats {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let monthAgo = calendar.date(byAdding: .day, value: -30, to: today) else {
            return MonthlyStats(weeklyStats: [])
        }
        
        let monthStats = dailyStats.filter { $0.date >= monthAgo && $0.date <= today }
        var weeklyGroups: [WeeklyStats] = []
        
        for weekOffset in 0..<4 {
            let weekStart = calendar.date(byAdding: .day, value: -7 * (3 - weekOffset), to: monthAgo) ?? monthAgo
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? today
            
            let weekStats = monthStats.filter { $0.date >= weekStart && $0.date <= weekEnd }
            if !weekStats.isEmpty {
                weeklyGroups.append(WeeklyStats(dailyStats: weekStats))
            }
        }
        
        return MonthlyStats(weeklyStats: weeklyGroups)
    }
    
    var totalFocusTimeFormatted: String {
        let totalSeconds = dailyStats.reduce(0) { $0 + $1.totalFocusTime }
        let hours = Int(totalSeconds) / 3600
        let minutes = (Int(totalSeconds) % 3600) / 60
        return String(format: "%dh %dm", hours, minutes)
    }
    
    var averageDailySessions: Double {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -30, to: today) else { return 0 }
        
        let filtered = dailyStats.filter { $0.date >= startDate && $0.date <= today }
        let totalDays = max(1, filtered.count)
        let totalSessions = filtered.reduce(0) { $0 + $1.completedSessions }
        return Double(totalSessions) / Double(totalDays)
    }
    
    var chartData: [(date: Date, sessions: Int)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let days: Int
        
        switch selectedPeriod {
        case .week:
            days = 7
        case .month:
            days = 30
        }
        
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: today) else { return [] }
        
        var result: [(date: Date, sessions: Int)] = []
        var currentDate = startDate
        
        while currentDate <= today {
            let dayStats = dailyStats.first { calendar.isDate($0.date, inSameDayAs: currentDate) }
            result.append((date: currentDate, sessions: dayStats?.completedSessions ?? 0))
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return result
    }
    
    // MARK: - Initialization
    init() {
        self.initialDuration = TimerMode.focus.duration
        self.timeRemaining = initialDuration
        loadTasks()
        loadThemePreference()
        loadStats()
        requestNotificationPermission()
    }
    
    // MARK: - Timer Methods
    func startTimer() {
        guard !isRunning else { return }
        guard activeTask != nil else {
            completionMessage = "Please select a task first!"
            showCompletionAlert = true
            return
        }
        
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.timeRemaining > 0 {
                self.timeRemaining -= 1
            } else {
                self.handleTimerCompletion()
            }
        }
    }
    
    func pauseTimer() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }
    
    func resetTimer() {
        pauseTimer()
        timeRemaining = initialDuration
    }
    
    func switchMode(to mode: TimerMode) {
        guard !isRunning else { return }
        pauseTimer()
        timerMode = mode
        initialDuration = mode.duration
        timeRemaining = initialDuration
    }
    
    func resetPomodoroCount() {
        completedPomodoros = 0
    }
    
    // MARK: - Task Management
    func createTask(title: String, description: String?) {
        let newTask = Task(title: title, description: description)
        tasks.append(newTask)
        saveTasks()
        clearTaskEditor()
    }
    
    func updateTask(_ task: Task) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index] = task
        saveTasks()
        clearTaskEditor()
    }
    
    func deleteTask(_ task: Task) {
        tasks.removeAll { $0.id == task.id }
        if activeTaskId == task.id {
            activeTaskId = nil
            saveActiveTaskId()
        }
        saveTasks()
    }
    
    func selectTask(_ task: Task) {
        for index in tasks.indices {
            tasks[index].isActive = false
        }
        
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].isActive = true
            activeTaskId = task.id
        }
        
        saveTasks()
        saveActiveTaskId()
    }
    
    func addSessionToActiveTask() {
        guard let taskId = activeTaskId,
              let index = tasks.firstIndex(where: { $0.id == taskId }) else { return }
        tasks[index].completedSessions += 1
        saveTasks()
    }
    
    func startEditingTask(_ task: Task) {
        editingTask = task
        taskTitle = task.title
        taskDescription = task.description ?? ""
        showingTaskEditor = true
    }
    
    func startCreatingTask() {
        editingTask = nil
        taskTitle = ""
        taskDescription = ""
        showingTaskEditor = true
    }
    
    func saveTaskEditor() {
        guard !taskTitle.isEmpty else { return }
        
        if let editingTask = editingTask {
            var updatedTask = editingTask
            updatedTask.title = taskTitle
            updatedTask.description = taskDescription.isEmpty ? nil : taskDescription
            updateTask(updatedTask)
        } else {
            createTask(title: taskTitle, description: taskDescription.isEmpty ? nil : taskDescription)
        }
    }
    
    func clearTaskEditor() {
        editingTask = nil
        taskTitle = ""
        taskDescription = ""
        showingTaskEditor = false
    }
    
    // MARK: - Private Methods
    private func handleTimerCompletion() {
        pauseTimer()
        sendCompletionNotification()
        
        switch timerMode {
        case .focus:
            handleFocusCompletion()
        case .shortBreak, .longBreak:
            handleBreakCompletion()
        }
    }
    
    private func handleFocusCompletion() {
        completedPomodoros += 1
        addSessionToActiveTask()
        saveSessionStats()
        
        let nextMode: TimerMode = shouldStartLongBreak ? .longBreak : .shortBreak
        
        let taskName = activeTask?.title ?? "Unknown Task"
        completionMessage = """
        ✅ Focus Session Complete!
        🍅 Pomodoros completed: \(completedPomodoros)
        📝 Task: \(taskName)
        \(shouldStartLongBreak ? "☕️ Time for a Long Break!" : "🌿 Time for a Short Break!")
        """
        
        showCompletionAlert = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self = self else { return }
            self.switchMode(to: nextMode)
            self.startTimer()
        }
    }
    
    private func handleBreakCompletion() {
        let nextMode: TimerMode = .focus
        let breakType = timerMode == .longBreak ? "Long Break" : "Short Break"
        
        completionMessage = """
        ✅ \(breakType) Complete!
        🍅 Ready for next Focus Session
        """
        
        showCompletionAlert = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self = self else { return }
            self.switchMode(to: nextMode)
            self.startTimer()
        }
    }
    
    private func requestNotificationPermission() {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }
    
    private func sendCompletionNotification() {
        let content = UNMutableNotificationContent()
        content.title = timerMode.notificationTitle
        content.body = timerMode.notificationBody
        content.sound = .default
        content.badge = NSNumber(value: completedPomodoros)
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("Notification error: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Stats Methods
    private func saveSessionStats() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        if let index = dailyStats.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: today) }) {
            dailyStats[index].completedSessions += 1
            dailyStats[index].totalFocusTime += TimerMode.focus.duration
        } else {
            let newStats = DailyStats(date: today, completedSessions: 1, totalFocusTime: TimerMode.focus.duration)
            dailyStats.append(newStats)
        }
        
        saveStats()
    }
    
    private func saveStats() {
        if let encoded = try? JSONEncoder().encode(dailyStats) {
            UserDefaults.standard.set(encoded, forKey: statsKey)
        }
    }
    
    private func loadStats() {
        guard let data = UserDefaults.standard.data(forKey: statsKey),
              let decoded = try? JSONDecoder().decode([DailyStats].self, from: data) else {
            dailyStats = []
            return
        }
        dailyStats = decoded
    }
    
    // MARK: - Persistence
    private func saveTasks() {
        if let encoded = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(encoded, forKey: tasksKey)
        }
    }
    
    private func loadTasks() {
        guard let data = UserDefaults.standard.data(forKey: tasksKey),
              let decoded = try? JSONDecoder().decode([Task].self, from: data) else {
            let sampleTask = Task(title: "Sample Task", description: "This is a sample task")
            tasks = [sampleTask]
            activeTaskId = sampleTask.id
            saveTasks()
            saveActiveTaskId()
            return
        }
        tasks = decoded
        loadActiveTaskId()
    }
    
    private func saveActiveTaskId() {
        if let id = activeTaskId {
            UserDefaults.standard.set(id.uuidString, forKey: activeTaskIdKey)
        } else {
            UserDefaults.standard.removeObject(forKey: activeTaskIdKey)
        }
    }
    
    private func loadActiveTaskId() {
        guard let idString = UserDefaults.standard.string(forKey: activeTaskIdKey),
              let id = UUID(uuidString: idString) else { return }
        activeTaskId = id
    }
    
    private func saveThemePreference() {
        UserDefaults.standard.set(isDarkMode, forKey: themeKey)
    }
    
    private func loadThemePreference() {
        isDarkMode = UserDefaults.standard.bool(forKey: themeKey)
    }
    
    deinit {
        timer?.invalidate()
    }
}
