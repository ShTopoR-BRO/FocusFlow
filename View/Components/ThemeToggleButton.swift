import SwiftUI

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
