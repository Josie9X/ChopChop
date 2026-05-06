import Foundation

enum PlanningError: LocalizedError {
    case invalidInput
    case documentParsingFailed
    case networkUnavailable
    case invalidModelResponse
    case modelServiceFailed(String)
    case needsClarification(String)

    var errorDescription: String? {
        switch self {
        case .invalidInput:
            return "请至少输入任务描述、标题或上传文档中的一种信息。"
        case .documentParsingFailed:
            return "文档解析失败，请改用文字补充。"
        case .networkUnavailable:
            return "无法连接服务，请检查网络或稍后重试。"
        case .invalidModelResponse:
            return "服务返回内容无法解析，请稍后重试。"
        case .modelServiceFailed(let message):
            return "服务暂时不可用：\(message)"
        case .needsClarification(let question):
            return question
        }
    }
}

protocol TaskPlanningService {
    func parseTask(_ request: ParseTaskRequest) async throws -> ParseTaskResponse
    func generatePlan(_ request: GeneratePlanRequest) async throws -> GeneratePlanResponse
    func regeneratePlan(_ request: RegeneratePlanRequest) async throws -> RegeneratePlanResponse
}
