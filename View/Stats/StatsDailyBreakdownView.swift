import SwiftUI

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
