import SwiftUI

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
