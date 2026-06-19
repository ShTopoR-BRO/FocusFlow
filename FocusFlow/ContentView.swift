import SwiftUI
import Combine
import UserNotifications
import Charts

// MARK: - Модель задачи
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

// MARK: - Модель статистики
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

// MARK: - Модель данных
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

// MARK: - ViewModel
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
    
    // MARK: - Private Properties
    private var timer: Timer?
    private var initialDuration: TimeInterval
    private let notificationCenter = UNUserNotificationCenter.current()
    private let pomodorosBeforeLongBreak = 4
    private let tasksKey = "savedTasks"
    private let activeTaskIdKey = "activeTaskId"
    private let statsKey = "dailyStats"
    
    // MARK: - Stats Properties
    @Published var dailyStats: [DailyStats] = []
    @Published var selectedPeriod: StatsPeriod = .week
    
    enum StatsPeriod: String, CaseIterable {
        case week = "Week"
        case month = "Month"
    }
    
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
        UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")
    }
    
    private func loadThemePreference() {
        isDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
    }
    
    deinit {
        timer?.invalidate()
    }
}

// MARK: - Статистика
struct StatsView: View {
    @ObservedObject var viewModel: TimerViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Период выбора
                    Picker("Period", selection: $viewModel.selectedPeriod) {
                        ForEach(TimerViewModel.StatsPeriod.allCases, id: \.self) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // Карточки статистики
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        StatsCard(
                            title: "Today",
                            value: "\(viewModel.todayStats.completedSessions)",
                            subtitle: "sessions",
                            icon: "calendar.circle.fill",
                            color: .blue
                        )
                        
                        StatsCard(
                            title: "Week",
                            value: "\(viewModel.weeklyStats.totalSessions)",
                            subtitle: "sessions",
                            icon: "calendar.circle.fill",
                            color: .green
                        )
                        
                        StatsCard(
                            title: "Month",
                            value: "\(viewModel.monthlyStats.totalSessions)",
                            subtitle: "sessions",
                            icon: "calendar.circle.fill",
                            color: .purple
                        )
                        
                        StatsCard(
                            title: "Avg/Day",
                            value: String(format: "%.1f", viewModel.averageDailySessions),
                            subtitle: "sessions",
                            icon: "chart.bar.fill",
                            color: .orange
                        )
                    }
                    .padding(.horizontal)
                    
                    // Всего времени
                    StatsCardFull(
                        title: "Total Focus Time",
                        value: viewModel.totalFocusTimeFormatted,
                        icon: "clock.fill",
                        color: .indigo
                    )
                    .padding(.horizontal)
                    
                    // График
                    StatsChartView(viewModel: viewModel)
                        .padding(.horizontal)
                    
                    // Детальная статистика по дням
                    StatsDailyBreakdownView(viewModel: viewModel)
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(viewModel.backgroundColor)
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(viewModel.isDarkMode ? .dark : .light)
    }
}

// MARK: - График статистики (исправленная версия)
struct StatsChartView: View {
    @ObservedObject var viewModel: TimerViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity Chart")
                .font(.headline)
                .foregroundColor(viewModel.textColor)
            
            Chart {
                ForEach(viewModel.chartData, id: \.date) { item in
                    BarMark(
                        x: .value("Date", item.date, unit: .day),
                        y: .value("Sessions", item.sessions)
                    )
                    .foregroundStyle(item.sessions > 0 ? Color.blue : Color.gray.opacity(0.3))
                    .cornerRadius(4)
                }
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: viewModel.selectedPeriod == .week ? 1 : 3)) { value in
                    AxisValueLabel(format: .dateTime.day().month())
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel()
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(viewModel.secondaryBackgroundColor)
        )
    }
}

// MARK: - Детальная статистика по дням
struct StatsDailyBreakdownView: View {
    @ObservedObject var viewModel: TimerViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Breakdown")
                .font(.headline)
                .foregroundColor(viewModel.textColor)
            
            let lastSevenDays = viewModel.chartData.suffix(7).reversed()
            
            ForEach(Array(lastSevenDays), id: \.date) { item in
                HStack {
                    Text(item.date, format: .dateTime.day().month().year())
                        .font(.subheadline)
                        .foregroundColor(viewModel.textColor)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        let sessionCount = min(item.sessions, 5)
                        ForEach(0..<sessionCount, id: \.self) { _ in
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 8, height: 8)
                        }
                        if item.sessions > 5 {
                            Text("+\(item.sessions - 5)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        if item.sessions == 0 {
                            Text("No sessions")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Text("\(item.sessions)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(viewModel.textColor)
                        .frame(minWidth: 30)
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(viewModel.secondaryBackgroundColor)
        )
    }
}

// MARK: - Карточка статистики
struct StatsCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Полная карточка статистики
struct StatsCardFull: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(color)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Основное представление
struct ContentView: View {
    @StateObject private var viewModel = TimerViewModel()
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    viewModel.backgroundColor,
                    viewModel.secondaryBackgroundColor
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Верхняя панель
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.activeTaskName)
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(viewModel.textColor)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("\(viewModel.completedPomodoros) pomodoros completed")
                                .font(.subheadline)
                                .foregroundColor(viewModel.secondaryTextColor)
                        }
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        // Кнопка статистики
                        Button(action: { viewModel.showingStats = true }) {
                            Image(systemName: "chart.bar.fill")
                                .font(.title3)
                                .foregroundColor(.orange)
                        }
                        
                        // Кнопка создания задачи
                        Button(action: { viewModel.startCreatingTask() }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundColor(viewModel.timerColor)
                        }
                        
                        // Переключатель темной темы
                        ThemeToggleButton(isDarkMode: $viewModel.isDarkMode)
                    }
                }
                .padding(.top, 20)
                .padding(.horizontal)
                
                // Список задач (если есть)
                if !viewModel.tasks.isEmpty {
                    TaskListView(viewModel: viewModel)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // Круговой индикатор прогресса
                ZStack {
                    Circle()
                        .stroke(
                            viewModel.secondaryTextColor.opacity(0.2),
                            lineWidth: 12
                        )
                        .frame(width: 220, height: 220)
                    
                    Circle()
                        .trim(from: 0, to: viewModel.progress)
                        .stroke(
                            viewModel.timerColor,
                            style: StrokeStyle(
                                lineWidth: 12,
                                lineCap: .round
                            )
                        )
                        .frame(width: 220, height: 220)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: viewModel.progress)
                    
                    VStack(spacing: 4) {
                        Text(viewModel.formattedTime)
                            .font(.system(size: 48, weight: .thin, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(viewModel.textColor)
                        
                        Text("remaining")
                            .font(.caption)
                            .foregroundColor(viewModel.secondaryTextColor)
                    }
                }
                .padding(.vertical, 10)
                
                // Текущий режим работы
                Text(viewModel.timerMode.rawValue)
                    .font(.headline)
                    .foregroundColor(viewModel.secondaryTextColor)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(viewModel.secondaryTextColor.opacity(0.1))
                    )
                
                // Индикатор прогресса помидоров
                if viewModel.timerMode == .focus {
                    HStack(spacing: 8) {
                        ForEach(0..<4, id: \.self) { index in
                            Circle()
                                .fill(index < viewModel.completedPomodoros % 4 ? Color.green : viewModel.secondaryTextColor.opacity(0.3))
                                .frame(width: 10, height: 10)
                        }
                        Text("until long break")
                            .font(.caption2)
                            .foregroundColor(viewModel.secondaryTextColor)
                    }
                }
                
                Spacer()
                
                // Кнопки управления
                HStack(spacing: 25) {
                    Button(action: { viewModel.resetTimer() }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.title2)
                            .foregroundColor(.orange)
                            .frame(width: 55, height: 55)
                            .background(Circle().fill(Color.orange.opacity(0.15)))
                    }
                    .disabled(viewModel.progress == 0 && !viewModel.isRunning)
                    
                    Button(action: {
                        if viewModel.isRunning {
                            viewModel.pauseTimer()
                        } else {
                            viewModel.startTimer()
                        }
                    }) {
                        Image(systemName: viewModel.isRunning ? "pause.fill" : "play.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .frame(width: 70, height: 70)
                            .background(
                                Circle()
                                    .fill(viewModel.isRunning ? Color.yellow : viewModel.timerColor)
                                    .shadow(radius: viewModel.isDarkMode ? 10 : 5)
                            )
                    }
                    
                    Button(action: {
                        viewModel.pauseTimer()
                    }) {
                        Image(systemName: "stop.fill")
                            .font(.title2)
                            .foregroundColor(.red)
                            .frame(width: 55, height: 55)
                            .background(Circle().fill(Color.red.opacity(0.15)))
                    }
                    .disabled(!viewModel.isRunning)
                }
                .padding(.vertical, 10)
                
                // Режимы работы
                HStack(spacing: 10) {
                    ForEach(TimerMode.allCases, id: \.self) { mode in
                        Button(action: {
                            viewModel.switchMode(to: mode)
                        }) {
                            VStack(spacing: 3) {
                                Image(systemName: mode.icon)
                                    .font(.title3)
                                Text(mode.rawValue)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .frame(width: 75, height: 65)
                            .foregroundColor(viewModel.timerMode == mode ? .white : viewModel.textColor)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(viewModel.timerMode == mode ? viewModel.timerColor : viewModel.secondaryTextColor.opacity(0.1))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(viewModel.timerMode == mode ? viewModel.timerColor : Color.clear, lineWidth: 2)
                            )
                        }
                        .disabled(viewModel.isRunning)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .padding()
        }
        .preferredColorScheme(viewModel.isDarkMode ? .dark : .light)
        .sheet(isPresented: $viewModel.showingTaskEditor) {
            TaskEditorView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showingStats) {
            StatsView(viewModel: viewModel)
        }
        .alert("Timer Complete! 🎉", isPresented: $viewModel.showCompletionAlert) {
            Button("OK") { }
        } message: {
            Text(viewModel.completionMessage)
        }
    }
}

// MARK: - Список задач
struct TaskListView: View {
    @ObservedObject var viewModel: TimerViewModel
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(viewModel.tasks) { task in
                    TaskCard(
                        task: task,
                        isActive: task.id == viewModel.activeTaskId,
                        onSelect: { viewModel.selectTask(task) },
                        onEdit: { viewModel.startEditingTask(task) },
                        onDelete: { viewModel.deleteTask(task) }
                    )
                }
            }
            .padding(.vertical, 5)
        }
    }
}

// MARK: - Карточка задачи
struct TaskCard: View {
    let task: Task
    let isActive: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    if let description = task.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 2) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                    Text("\(task.completedSessions)")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(.green)
            }
            
            HStack(spacing: 8) {
                Button(action: onSelect) {
                    Text(isActive ? "Active" : "Select")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(isActive ? .white : .blue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(isActive ? Color.green : Color.blue.opacity(0.1))
                        )
                }
                
                Spacer()
                
                HStack(spacing: 6) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    
                    Button(action: { showingDeleteConfirmation = true }) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .padding(10)
        .frame(width: 200, height: 80)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isActive ? Color.green.opacity(0.1) : Color.gray.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isActive ? Color.green : Color.gray.opacity(0.2), lineWidth: 1)
                )
        )
        .alert("Delete Task", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { onDelete() }
        } message: {
            Text("Are you sure you want to delete '\(task.title)'?")
        }
    }
}

// MARK: - Редактор задач с автоматической клавиатурой
struct TaskEditorView: View {
    @ObservedObject var viewModel: TimerViewModel
    @Environment(\.dismiss) var dismiss
    @FocusState private var isTitleFocused: Bool
    @FocusState private var isDescriptionFocused: Bool
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Task Details")) {
                    TextField("Task Name", text: $viewModel.taskTitle)
                        .textInputAutocapitalization(.sentences)
                        .focused($isTitleFocused)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                isTitleFocused = true
                            }
                        }
                    
                    TextField("Description (optional)", text: $viewModel.taskDescription)
                        .textInputAutocapitalization(.sentences)
                        .focused($isDescriptionFocused)
                        .onSubmit {
                            if viewModel.taskTitle.isEmpty {
                                isTitleFocused = true
                            } else {
                                isDescriptionFocused = false
                                viewModel.saveTaskEditor()
                                dismiss()
                            }
                        }
                }
                
                if viewModel.editingTask != nil {
                    Section {
                        Button("Delete Task", role: .destructive) {
                            if let task = viewModel.editingTask {
                                viewModel.deleteTask(task)
                                dismiss()
                            }
                        }
                    }
                }
            }
            .navigationTitle(viewModel.editingTask != nil ? "Edit Task" : "New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.clearTaskEditor()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.saveTaskEditor()
                        dismiss()
                    }
                    .disabled(viewModel.taskTitle.isEmpty)
                }
                
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("Done") {
                            isTitleFocused = false
                            isDescriptionFocused = false
                        }
                        .fontWeight(.medium)
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .onDisappear {
            isTitleFocused = false
            isDescriptionFocused = false
        }
        .interactiveDismissDisabled()
    }
}

// MARK: - Компонент переключателя темы
struct ThemeToggleButton: View {
    @Binding var isDarkMode: Bool
    
    var body: some View {
        Button(action: { isDarkMode.toggle() }) {
            HStack(spacing: 6) {
                Image(systemName: isDarkMode ? "moon.fill" : "sun.max.fill")
                    .font(.subheadline)
                    .foregroundColor(isDarkMode ? .yellow : .orange)
                
                Text(isDarkMode ? "Dark" : "Light")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.gray.opacity(0.15))
            )
            .overlay(
                Capsule()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// MARK: - Превью
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .preferredColorScheme(.light)
        ContentView()
            .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}
