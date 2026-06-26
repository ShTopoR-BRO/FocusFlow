import SwiftUI
import Charts

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

