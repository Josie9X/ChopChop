import SwiftData
import SwiftUI

struct MyTasksView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var composer: GeneratePlanViewModel
    enum TaskPage: String, CaseIterable, Identifiable {
        case ongoing = "正在进行的任务"
        case ended = "已结束的任务"

        var id: String { rawValue }
    }

    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\PlannerTask.deadline, order: .forward)])
    private var tasks: [PlannerTask]
    @State private var selectedPage: TaskPage = .ongoing
    @State private var selectedTask: PlannerTask?
    @State private var taskPendingRename: PlannerTask?
    @State private var taskPendingDelete: PlannerTask?
    @State private var renameText = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                topTabSwitcher

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if visibleTasks.isEmpty {
                            emptyState
                        } else {
                            Text(selectedPage.rawValue)
                                .font(.headline.weight(.semibold))

                            ForEach(visibleTasks) { task in
                                taskCard(task)
                            }
                        }
                    }
                    .frame(
                        maxWidth: .infinity,
                        minHeight: visibleTasks.isEmpty ? emptyStateMinHeight : 0,
                        alignment: visibleTasks.isEmpty ? .center : .topLeading
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("我的任务")
            .toolbarTitleDisplayMode(.inline)
            .onAppear(perform: refreshStatuses)
            .navigationDestination(item: $selectedTask) { task in
                TaskDetailView(task: task)
            }
            .alert("重命名计划", isPresented: renameBinding) {
                TextField("计划名称", text: $renameText)
                Button("取消", role: .cancel) {
                    taskPendingRename = nil
                    renameText = ""
                }
                Button("保存") {
                    renamePendingTask()
                }
            } message: {
                Text("重命名只会影响计划标题，不会改变 DDL 和任务类型。")
            }
            .confirmationDialog("删除计划", isPresented: deleteBinding, titleVisibility: .visible) {
                Button("删除计划", role: .destructive) {
                    deletePendingTask()
                }
                Button("取消", role: .cancel) {
                    taskPendingDelete = nil
                }
            } message: {
                Text("删除后无法在本地恢复。")
            }
        }
    }

    private var emptyStateMinHeight: CGFloat {
        max(360, UIScreen.main.bounds.height - 300)
    }

    private var activeTasks: [PlannerTask] {
        tasks
            .filter { $0.status == .inProgress || $0.status == .selected || $0.status == .generated }
            .sorted { $0.deadline < $1.deadline }
    }

    private var endedTasks: [PlannerTask] {
        tasks
            .filter { $0.status == .completed || $0.status == .overdue }
            .sorted { $0.deadline > $1.deadline }
    }

    private var visibleTasks: [PlannerTask] {
        switch selectedPage {
        case .ongoing:
            return activeTasks
        case .ended:
            return endedTasks
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 42))
                .foregroundStyle(.secondary)
            Text(selectedPage == .ongoing ? "还没有正在进行的任务" : "还没有已结束的任务")
                .font(.headline)
            Text(selectedPage == .ongoing ? "去“生成计划”里输入一个作业描述，生成两套方案后确认执行。" : "完成或逾期的任务会在这里展示。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(24)
    }

    private var topTabSwitcher: some View {
        HStack(spacing: 10) {
            ForEach(TaskPage.allCases) { page in
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.92)) {
                        selectedPage = page
                    }
                } label: {
                    Text(page.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(selectedPage == page ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(selectedPage == page ? Color.black : Color(.systemGray6), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
    }

    private func taskCard(_ task: PlannerTask) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        StatusPill(title: task.status.displayName, color: task.status.tint)
                        if let mode = task.selectedMode {
                            StatusPill(title: mode.displayName, color: mode.tint)
                        }
                    }

                    Text(task.displayTitle)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    if !task.courseName.isEmpty {
                        Text(task.courseName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 10) {
                    Menu {
                        if selectedPage == .ongoing {
                            Button("修改计划") {
                                composer.loadTaskForEditing(task)
                                appState.selectedTab = .generate
                            }
                        }

                        Button("重命名计划") {
                            taskPendingRename = task
                            renameText = task.displayTitle
                        }

                        Button("删除计划", role: .destructive) {
                            taskPendingDelete = task
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 34, height: 34)
                            .background(Color(.systemBackground).opacity(0.82), in: Circle())
                    }
                    .buttonStyle(.plain)

                    deadlineBadge(for: task)
                }
            }

            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text("进度")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int((task.progress * 100).rounded()))%")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(task.status == .completed ? .teal : .green)
                }

                ProgressView(value: task.progress)
                    .tint(task.status == .completed ? .teal : .green)

                stepSummary(for: task)
            }
            .padding(12)
            .background(Color(.systemBackground).opacity(0.72), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            HStack(spacing: 12) {
                Text(countdownText(for: task))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(task.status == .overdue ? .red : .secondary)

                Spacer()

                if task.status == .inProgress {
                    Button("完成当前步骤") {
                        completeCurrentStep(for: task)
                    }
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .buttonBorderShape(.capsule)
                } else {
                    Label(task.status == .completed ? "已完成" : "已结束", systemImage: task.status == .completed ? "checkmark.circle.fill" : "clock.badge.exclamationmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(task.status == .completed ? .teal : .orange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemBackground).opacity(0.8), in: Capsule())
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: .black.opacity(0.05), radius: 16, x: 0, y: 8)
        )
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onTapGesture {
            selectedTask = task
        }
    }

    private func deadlineBadge(for task: PlannerTask) -> some View {
        VStack(spacing: 2) {
            Text(task.deadline.formatted(.dateTime.day()))
                .font(.title3.weight(.bold))
            Text(task.deadline.formatted(.dateTime.month(.abbreviated)))
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Text(task.deadline.formatted(.dateTime.year()))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 58, height: 66)
        .background(Color(.systemBackground).opacity(0.82), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func stepSummary(for task: PlannerTask) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if task.status == .completed {
                labeledStepLine(label: "状态", value: "全部步骤已完成")
            } else if task.status == .overdue {
                labeledStepLine(label: "状态", value: task.currentStep?.title ?? "任务已超过 DDL")
            } else if let current = task.currentStep {
                labeledStepLine(label: "当前", value: current.title)
                if let next = task.nextStep {
                    labeledStepLine(label: "下一步", value: next.title)
                }
            } else {
                labeledStepLine(label: "状态", value: "等待开始执行")
            }
        }
    }

    private func labeledStepLine(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("\(label)：")
                .foregroundStyle(.secondary)
            Text(value)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.caption)
    }

    private func completeCurrentStep(for task: PlannerTask) {
        guard let current = task.currentStep else { return }
        current.status = .done

        if let nextTodo = task.sortedSteps.first(where: { $0.status == .todo }) {
            nextTodo.status = .doing
        }

        task.refreshDerivedState()
        try? modelContext.save()
    }

    private var renameBinding: Binding<Bool> {
        Binding(
            get: { taskPendingRename != nil },
            set: { isPresented in
                if !isPresented {
                    taskPendingRename = nil
                    renameText = ""
                }
            }
        )
    }

    private var deleteBinding: Binding<Bool> {
        Binding(
            get: { taskPendingDelete != nil },
            set: { isPresented in
                if !isPresented {
                    taskPendingDelete = nil
                }
            }
        )
    }

    private func renamePendingTask() {
        guard let task = taskPendingRename else { return }
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        task.title = trimmed.isEmpty ? task.defaultDisplayTitle : trimmed
        try? modelContext.save()
        taskPendingRename = nil
        renameText = ""
    }

    private func deletePendingTask() {
        guard let task = taskPendingDelete else { return }
        if selectedTask?.id == task.id {
            selectedTask = nil
        }
        modelContext.delete(task)
        try? modelContext.save()
        taskPendingDelete = nil
    }

    private func refreshStatuses() {
        for task in tasks {
            task.refreshDerivedState()
        }

        try? modelContext.save()
    }

    private func countdownText(for task: PlannerTask) -> String {
        let interval = task.deadline.timeIntervalSince(BeijingClock.now)
        if task.status == .completed {
            return "已完成"
        }
        if interval <= 0 {
            return "已超过 DDL"
        }

        let hours = Int(interval / 3600)
        if hours >= 24 {
            return "剩余 \(hours / 24) 天"
        }
        return "剩余 \(max(hours, 1)) 小时"
    }
}
