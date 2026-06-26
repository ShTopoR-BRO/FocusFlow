import SwiftUI

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

