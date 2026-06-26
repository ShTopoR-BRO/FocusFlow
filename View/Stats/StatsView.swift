import SwiftUI

struct StatsView: View {
    @ObservedObject var viewModel: TimerViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Период выбора
                    Picker("Period", selection: $viewModel.selectedPeriod) {
                        ForEach(StatsPeriod.allCases, id: \.self) { period in
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

#Preview {
    StatsView(viewModel: TimerViewModel())
}
