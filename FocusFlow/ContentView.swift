import SwiftUI
import Combine
import UserNotifications

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
    @Published var activeTaskName = "Design Homepage"
    @Published var completedPomodoros = 0
    @Published var showCompletionAlert = false
    @Published var completionMessage = ""
    @Published var isDarkMode = false
    
    // MARK: - Private Properties
    private var timer: Timer?
    private var initialDuration: TimeInterval
    private let notificationCenter = UNUserNotificationCenter.current()
    private let pomodorosBeforeLongBreak = 4
    
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
    
    // MARK: - Initialization
    init() {
        self.initialDuration = TimerMode.focus.duration
        self.timeRemaining = initialDuration
        requestNotificationPermission()
        loadThemePreference()
    }
    
    // MARK: - Public Methods
    func startTimer() {
        guard !isRunning else { return }
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
    
    func toggleTheme() {
        isDarkMode.toggle()
        saveThemePreference()
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
        
        let nextMode: TimerMode = shouldStartLongBreak ? .longBreak : .shortBreak
        
        completionMessage = """
        ✅ Focus Session Complete!
        🍅 Pomodoros completed: \(completedPomodoros)
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

// MARK: - Основное представление
struct ContentView: View {
    @StateObject private var viewModel = TimerViewModel()
    @Environment(\.colorScheme) var systemColorScheme
    
    var body: some View {
        ZStack {
            // Фоновый градиент с учетом темы
            LinearGradient(
                gradient: Gradient(colors: [
                    viewModel.backgroundColor,
                    viewModel.secondaryBackgroundColor
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Верхняя панель с переключателем темы
                HStack {
                    // Название активной задачи
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
                    
                    // Переключатель темной темы
                    ThemeToggleButton(isDarkMode: $viewModel.isDarkMode)
                }
                .padding(.top, 20)
                .padding(.horizontal)
                
                Spacer()
                
                // Круговой индикатор прогресса
                ZStack {
                    // Фоновый круг
                    Circle()
                        .stroke(
                            viewModel.secondaryTextColor.opacity(0.2),
                            lineWidth: 12
                        )
                        .frame(width: 240, height: 240)
                    
                    // Прогресс
                    Circle()
                        .trim(from: 0, to: viewModel.progress)
                        .stroke(
                            viewModel.timerColor,
                            style: StrokeStyle(
                                lineWidth: 12,
                                lineCap: .round
                            )
                        )
                        .frame(width: 240, height: 240)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: viewModel.progress)
                    
                    // Оставшееся время
                    VStack(spacing: 4) {
                        Text(viewModel.formattedTime)
                            .font(.system(size: 52, weight: .thin, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(viewModel.textColor)
                        
                        Text("remaining")
                            .font(.caption)
                            .foregroundColor(viewModel.secondaryTextColor)
                    }
                }
                .padding()
                
                // Текущий режим работы
                Text(viewModel.timerMode.rawValue)
                    .font(.headline)
                    .foregroundColor(viewModel.secondaryTextColor)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
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
                                .frame(width: 12, height: 12)
                        }
                        Text("until long break")
                            .font(.caption2)
                            .foregroundColor(viewModel.secondaryTextColor)
                    }
                }
                
                Spacer()
                
                // Кнопки управления
                HStack(spacing: 30) {
                    // Кнопка сброса
                    Button(action: { viewModel.resetTimer() }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.title2)
                            .foregroundColor(.orange)
                            .frame(width: 60, height: 60)
                            .background(Circle().fill(Color.orange.opacity(0.15)))
                    }
                    .disabled(viewModel.progress == 0 && !viewModel.isRunning)
                    
                    // Кнопка паузы/запуска
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
                            .frame(width: 80, height: 80)
                            .background(
                                Circle()
                                    .fill(viewModel.isRunning ? Color.yellow : viewModel.timerColor)
                                    .shadow(radius: viewModel.isDarkMode ? 10 : 5)
                            )
                    }
                    
                    // Кнопка стоп
                    Button(action: {
                        viewModel.pauseTimer()
                    }) {
                        Image(systemName: "stop.fill")
                            .font(.title2)
                            .foregroundColor(.red)
                            .frame(width: 60, height: 60)
                            .background(Circle().fill(Color.red.opacity(0.15)))
                    }
                    .disabled(!viewModel.isRunning)
                }
                .padding(.vertical)
                
                // Режимы работы
                HStack(spacing: 12) {
                    ForEach(TimerMode.allCases, id: \.self) { mode in
                        Button(action: {
                            viewModel.switchMode(to: mode)
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: mode.icon)
                                    .font(.title3)
                                Text(mode.rawValue)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .frame(width: 80, height: 70)
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
                .padding(.bottom, 30)
            }
            .padding()
        }
        .preferredColorScheme(viewModel.isDarkMode ? .dark : .light)
        .alert("Timer Complete! 🎉", isPresented: $viewModel.showCompletionAlert) {
            Button("OK") { }
        } message: {
            Text(viewModel.completionMessage)
        }
    }
}

// MARK: - Компонент переключателя темы
struct ThemeToggleButton: View {
    @Binding var isDarkMode: Bool
    
    var body: some View {
        Button(action: { isDarkMode.toggle() }) {
            HStack(spacing: 8) {
                Image(systemName: isDarkMode ? "moon.fill" : "sun.max.fill")
                    .font(.title3)
                    .foregroundColor(isDarkMode ? .yellow : .orange)
                
                Text(isDarkMode ? "Dark" : "Light")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
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
