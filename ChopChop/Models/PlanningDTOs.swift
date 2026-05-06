import Foundation

struct StageDescriptor: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let detail: String
}

struct ParseTaskRequest: Codable {
    var conversationID: UUID = UUID()
    var taskID: UUID? = nil
    let title: String
    let description: String
    let courseName: String
    let deadline: Date?
    var attachment: UploadedAttachment? = nil
    var conversationHistory: [String] = []
    var taskSummary: String? = nil
    var fileSummary: String? = nil
    var recentConversation: [String] = []
}

struct ParseTaskResponse: Codable {
    let suggestedType: TaskType
    let stages: [StageDescriptor]
    let clarifyingQuestions: [String]
    let confidence: Double
    let summary: String
    let taskSummary: String?
    let fileSummary: String?

    init(
        suggestedType: TaskType,
        stages: [StageDescriptor],
        clarifyingQuestions: [String],
        confidence: Double,
        summary: String,
        taskSummary: String? = nil,
        fileSummary: String? = nil
    ) {
        self.suggestedType = suggestedType
        self.stages = stages
        self.clarifyingQuestions = clarifyingQuestions
        self.confidence = confidence
        self.summary = summary
        self.taskSummary = taskSummary
        self.fileSummary = fileSummary
    }
}

struct PlannedStep: Codable, Hashable, Identifiable {
    let id: UUID
    let title: String
    let detail: String
    let order: Int
    let estimatedMin: Int
    let estimatedMax: Int
    let estimateReason: String
    let toolWarning: String?
    let phaseID: String
    let phaseTitle: String
    let isCore: Bool

    init(
        id: UUID = UUID(),
        title: String,
        detail: String,
        order: Int,
        estimatedMin: Int,
        estimatedMax: Int,
        estimateReason: String,
        toolWarning: String?,
        phaseID: String,
        phaseTitle: String,
        isCore: Bool
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.order = order
        self.estimatedMin = estimatedMin
        self.estimatedMax = estimatedMax
        self.estimateReason = estimateReason
        self.toolWarning = toolWarning
        self.phaseID = phaseID
        self.phaseTitle = phaseTitle
        self.isCore = isCore
    }
}

struct PlannedMode: Codable, Hashable, Identifiable {
    var id: String { mode.rawValue }

    let mode: PlanMode
    let totalMin: Int
    let totalMax: Int
    let isHighRisk: Bool
    let riskNote: String?
    let steps: [PlannedStep]
}

struct GeneratePlanRequest: Codable {
    var conversationID: UUID = UUID()
    var taskID: UUID? = nil
    let title: String
    let description: String
    let courseName: String
    let deadline: Date
    let selectedType: TaskType
    let completedStageIDs: [String]
    var attachment: UploadedAttachment? = nil
    var conversationHistory: [String] = []
    var taskSummary: String? = nil
    var fileSummary: String? = nil
    var recentConversation: [String] = []
}

struct GeneratePlanResponse: Codable {
    let taskSummary: String
    let steadyPlan: PlannedMode
    let rescuePlan: PlannedMode
    var generationSource: String = "local"
    var isFallback: Bool = true
    var updatedTaskSummary: String? = nil
    var updatedFileSummary: String? = nil

    var generationSourceTitle: String {
        if generationSource == "ark" && !isFallback {
            return "Doubao-Seed-2.0-mini 已调用"
        }
        if isFallback {
            return "后端生成"
        }
        return "后端生成"
    }

    var generationSourceDetail: String {
        if generationSource == "ark" && !isFallback {
            return "本次计划由火山方舟大模型辅助拆解"
        }
        if isFallback {
            return "已根据当前输入生成可执行计划"
        }
        return "本次计划由后端服务生成"
    }
}

struct ConfirmPlanRequest: Codable {
    let taskID: UUID?
    let selectedMode: PlanMode
}

struct UpdateStepStatusRequest: Codable {
    let stepID: UUID
    let status: StepStatus
}

struct RegeneratePlanRequest: Codable {
    var conversationID: UUID = UUID()
    var taskID: UUID? = nil
    let title: String
    let description: String
    let courseName: String
    let deadline: Date
    let selectedType: TaskType
    let completedStageIDs: [String]
    var attachment: UploadedAttachment? = nil
    var conversationHistory: [String] = []
    var taskSummary: String? = nil
    var fileSummary: String? = nil
    var recentConversation: [String] = []
}

typealias RegeneratePlanResponse = GeneratePlanResponse

struct UploadedAttachment: Codable, Hashable {
    let fileName: String
    let mimeType: String
    let fileSize: Int
    let extractedText: String
    let fileBase64: String?
}
