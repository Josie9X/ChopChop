import SwiftData
import SwiftUI

struct TaskDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var composer: GeneratePlanViewModel
    @Bindable var task: PlannerTask
    @State private var isRenamePresented = false
    @State private var isDeletePresented = false
    @State private var renameText = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SurfaceCard {
                    Text(task.displayTitle)
                        .font(.title3.weight(.bold))

                    HStack(spacing: 8) {
                        StatusPill(title: task.status.displayName, color: task.status.tint)
                        if let mode = task.selectedMode {
                            StatusPill(title: mode.displayName, color: mode.tint)
                        }
                        StatusPill(title: task.type.displayName, color: .indigo)
                    }

                    ProgressView(value: task.progress)
                        .tint(task.status.tint)

                    Text("DDL：\(task.deadline.formatted(date: .abbreviated, time: .shortened))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let lastRiskNote = task.lastRiskNote, task.status != .completed, task.status != .overdue {
                        Label(lastRiskNote, systemImage: "info.circle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("步骤详情")
                        .font(.headline)

                    ForEach(task.sortedSteps) { step in
                        SurfaceCard {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("\(step.orderIndex). \(step.title)")
                                        .font(.headline)
                                    Text(step.stepDetail)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    HStack(spacing: 8) {
                                        Text(step.phaseTitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        HStack(spacing: 6) {
                                            Text(step.estimateText)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            EstimateInfoButton(reason: step.estimateReason)
                                        }
                                    }

                                    if let toolWarning = step.toolWarning {
                                        Text(toolWarning)
                                            .font(.caption2)
                                            .foregroundStyle(.orange)
                                    }
                                }
                                Spacer()
                                StatusPill(title: step.status.displayName, color: step.status.tint)
                            }

                            Picker(
                                "状态",
                                selection: Binding(
                                    get: { step.status },
                                    set: { newValue in
                                        update(step: step, to: newValue)
                                    }
                                )
                            ) {
                                Text("待做").tag(StepStatus.todo)
                                Text("进行中").tag(StepStatus.doing)
                                Text("已完成").tag(StepStatus.done)
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("任务详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if task.status != .completed && task.status != .overdue {
                        Button("修改计划") {
                            appState.isRootTabBarHidden = false
                            composer.loadTaskForEditing(task)
                            appState.selectedTab = .generate
                        }
                    }

                    Button("重命名计划") {
                        renameText = task.displayTitle
                        isRenamePresented = true
                    }

                    Button("删除计划", role: .destructive) {
                        isDeletePresented = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
            }
        }
        .alert("重命名计划", isPresented: $isRenamePresented) {
            TextField("计划名称", text: $renameText)
            Button("取消", role: .cancel) {}
            Button("保存") {
                let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                task.title = trimmed.isEmpty ? task.defaultDisplayTitle : trimmed
                try? modelContext.save()
            }
        } message: {
            Text("重命名只会影响计划标题，不会改变 DDL 和任务类型。")
        }
        .confirmationDialog("删除计划", isPresented: $isDeletePresented, titleVisibility: .visible) {
            Button("删除计划", role: .destructive) {
                appState.isRootTabBarHidden = false
                modelContext.delete(task)
                try? modelContext.save()
                dismiss()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后无法在本地恢复。")
        }
        .onAppear {
            appState.isRootTabBarHidden = true
            task.refreshDerivedState()
            try? modelContext.save()
        }
        .onDisappear {
            appState.isRootTabBarHidden = false
        }
    }

    private func update(step: PlannerStep, to status: StepStatus) {
        if status == .doing {
            for sibling in task.sortedSteps where sibling.id != step.id && sibling.status == .doing {
                sibling.status = .todo
            }
        }

        step.status = status

        if status == .done, let nextTodo = task.sortedSteps.first(where: { $0.status == .todo }) {
            nextTodo.status = .doing
        }

        task.refreshDerivedState()
        try? modelContext.save()
    }
}
