import SwiftUI

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
                        Button(action: { viewModel.showingStats = true }) {
                            Image(systemName: "chart.bar.fill")
                                .font(.title3)
                                .foregroundColor(.orange)
                        }
                        
                        Button(action: { viewModel.startCreatingTask() }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundColor(viewModel.timerColor)
                        }
                        
                        ThemeToggleButton(isDarkMode: $viewModel.isDarkMode)
                    }
                }
                .padding(.top, 20)
                .padding(.horizontal)
                
                // Список задач
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

#Preview {
    ContentView()
}
