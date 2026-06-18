import SwiftUI
import Combine

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
}

// MARK: - ViewModel
class TimerViewModel: ObservableObject {
    @Published var timeRemaining: TimeInterval
    @Published var timerMode: TimerMode = .focus
    @Published var isRunning = false
    @Published var activeTaskName = "Design Homepage"
    
    private var timer: Timer?
    private var initialDuration: TimeInterval
    
    init() {
        self.initialDuration = TimerMode.focus.duration
        self.timeRemaining = initialDuration
    }
    
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
        timerMode.color
    }
    
    func startTimer() {
        guard !isRunning else { return }
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.timeRemaining > 0 {
                self.timeRemaining -= 1
            } else {
                self.stopTimer()
                // Здесь можно добавить уведомление о завершении
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
        pauseTimer()
        timerMode = mode
        initialDuration = mode.duration
        timeRemaining = initialDuration
    }
    
    private func stopTimer() {
        pauseTimer()
        // Действие при завершении таймера
    }
    
    deinit {
        timer?.invalidate()
    }
}

// MARK: - Основное представление
struct ContentView: View {
    @StateObject private var viewModel = TimerViewModel()
    
    var body: some View {
        ZStack {
            // Фоновый градиент
            LinearGradient(
                gradient: Gradient(colors: [Color(.systemBackground), Color(.systemGray6)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Название активной задачи
                Text(viewModel.activeTaskName)
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .padding(.top, 20)
                
                Spacer()
                
                // Круговой индикатор прогресса
                ZStack {
                    // Фоновый круг
                    Circle()
                        .stroke(
                            Color.gray.opacity(0.2),
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
                            .foregroundColor(.primary)
                        
                        Text("remaining")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                
                // Текущий режим работы
                Text(viewModel.timerMode.rawValue)
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.gray.opacity(0.1))
                    )
                
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
                                    .shadow(radius: 5)
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
                            .foregroundColor(viewModel.timerMode == mode ? .white : .primary)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(viewModel.timerMode == mode ? mode.color : Color.gray.opacity(0.1))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(viewModel.timerMode == mode ? mode.color : Color.clear, lineWidth: 2)
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
