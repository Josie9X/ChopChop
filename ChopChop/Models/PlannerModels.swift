import Foundation
import SwiftData

@Model
final class PlannerTask {
    @Attribute(.unique) var id: UUID
    var title: String
    var taskDescription: String
    var courseName: String
    var deadline: Date
    var typeRawValue: String
    var selectedModeRawValue: String?
    var statusRawValue: String
    var createdAt: Date
    var sourceDocumentName: String?
    var completedStageIDs: [String]
    var lastRiskNote: String?
    var planningSummary: String?
    var fileSummary: String?
    var conversationHistory: [String]

    @Relationship(deleteRule: .cascade, inverse: \PlannerStep.task)
    var steps: [PlannerStep]

    init(
        id: UUID = UUID(),
        title: String,
        taskDescription: String,
        courseName: String,
        deadline: Date,
        type: TaskType,
        selectedMode: PlanMode?,
        status: TaskStatus,
        createdAt: Date = BeijingClock.now,
        sourceDocumentName: String? = nil,
        completedStageIDs: [String] = [],
        lastRiskNote: String? = nil,
        planningSummary: String? = nil,
        fileSummary: String? = nil,
        conversationHistory: [String] = [],
        steps: [PlannerStep] = []
    ) {
        self.id = id
        self.title = title
        self.taskDescription = taskDescription
        self.courseName = courseName
        self.deadline = deadline
        self.typeRawValue = type.rawValue
        self.selectedModeRawValue = selectedMode?.rawValue
        self.statusRawValue = status.rawValue
        self.createdAt = createdAt
        self.sourceDocumentName = sourceDocumentName
        self.completedStageIDs = completedStageIDs
        self.lastRiskNote = lastRiskNote
        self.planningSummary = planningSummary
        self.fileSummary = fileSummary
        self.conversationHistory = conversationHistory
        self.steps = steps

        for step in steps {
            step.task = self
        }

        refreshDerivedState()
    }

    var type: TaskType {
        get { TaskType(rawValue: typeRawValue) ?? .unknown }
        set { typeRawValue = newValue.rawValue }
    }

    var selectedMode: PlanMode? {
        get {
            guard let selectedModeRawValue else { return nil }
            return PlanMode(rawValue: selectedModeRawValue)
        }
        set { selectedModeRawValue = newValue?.rawValue }
    }

    var status: TaskStatus {
        get { TaskStatus(rawValue: statusRawValue) ?? .draft }
        set { statusRawValue = newValue.rawValue }
    }

    var sortedSteps: [PlannerStep] {
        steps.sorted { $0.orderIndex < $1.orderIndex }
    }

    var completedStepsCount: Int {
        sortedSteps.filter { $0.status == .done }.count
    }

    var progress: Double {
        guard !steps.isEmpty else { return 0 }
        return Double(completedStepsCount) / Double(steps.count)
    }

    var totalEstimateRange: ClosedRange<Int> {
        let min = sortedSteps.reduce(0) { $0 + $1.estimatedMin }
        let max = sortedSteps.reduce(0) { $0 + $1.estimatedMax }
        return min...max
    }

    var currentStep: PlannerStep? {
        sortedSteps.first(where: { $0.status == .doing }) ?? sortedSteps.first(where: { $0.status == .todo })
    }

    var nextStep: PlannerStep? {
        guard let current = currentStep else { return nil }
        return sortedSteps.first(where: { $0.orderIndex > current.orderIndex && $0.status != .done })
    }

    func refreshDerivedState(now: Date = BeijingClock.now) {
        let ordered = sortedSteps

        if ordered.allSatisfy({ $0.status == .done || $0.status == .skipped }), !ordered.isEmpty {
            status = .completed
            return
        }

        if deadline < now {
            status = .overdue
        } else if !ordered.isEmpty {
            status = .inProgress
        }

        if ordered.contains(where: { $0.status == .doing }) {
            return
        }

        if let firstTodo = ordered.first(where: { $0.status == .todo }) {
            firstTodo.status = .doing
        }
    }
}

extension PlannerTask: Identifiable {}

extension PlannerTask {
    var defaultDisplayTitle: String {
        "\(deadline.deadlineTitlePrefix)\(type.titleDisplayName)"
    }

    var displayTitle: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.isEmpty ? defaultDisplayTitle : trimmedTitle
    }
}

@Model
final class PlannerStep {
    @Attribute(.unique) var id: UUID
    var title: String
    var stepDetail: String
    var orderIndex: Int
    var estimatedMin: Int
    var estimatedMax: Int
    var estimateReason: String
    var toolWarning: String?
    var statusRawValue: String
    var phaseID: String
    var phaseTitle: String
    var isCore: Bool
    var task: PlannerTask?

    init(
        id: UUID = UUID(),
        title: String,
        stepDetail: String,
        orderIndex: Int,
        estimatedMin: Int,
        estimatedMax: Int,
        estimateReason: String,
        toolWarning: String? = nil,
        status: StepStatus,
        phaseID: String,
        phaseTitle: String,
        isCore: Bool,
        task: PlannerTask? = nil
    ) {
        self.id = id
        self.title = title
        self.stepDetail = stepDetail
        self.orderIndex = orderIndex
        self.estimatedMin = estimatedMin
        self.estimatedMax = estimatedMax
        self.estimateReason = estimateReason
        self.toolWarning = toolWarning
        self.statusRawValue = status.rawValue
        self.phaseID = phaseID
        self.phaseTitle = phaseTitle
        self.isCore = isCore
        self.task = task
    }

    var status: StepStatus {
        get { StepStatus(rawValue: statusRawValue) ?? .todo }
        set { statusRawValue = newValue.rawValue }
    }

    var estimateText: String {
        "\(estimatedMin)-\(estimatedMax) 分钟"
    }
}

extension PlannerStep: Identifiable {}

extension Date {
    var deadlineTitlePrefix: String {
        let formatter = BeijingClock.formatter(template: "M月d日")
        return formatter.string(from: self)
    }
}
