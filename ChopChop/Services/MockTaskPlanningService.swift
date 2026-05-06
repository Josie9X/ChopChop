import Foundation

struct MockTaskPlanningService: TaskPlanningService {
    private let generator: PlanGenerator

    init(generator: PlanGenerator = PlanGenerator()) {
        self.generator = generator
    }

    func parseTask(_ request: ParseTaskRequest) async throws -> ParseTaskResponse {
        guard hasInput(request) else {
            throw PlanningError.invalidInput
        }

        try await simulatedDelay()
        return generator.parse(request)
    }

    func generatePlan(_ request: GeneratePlanRequest) async throws -> GeneratePlanResponse {
        let hasText = !request.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !request.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        guard hasText || request.selectedType != .unknown else {
            throw PlanningError.invalidInput
        }

        try await simulatedDelay()
        return generator.generate(request)
    }

    func regeneratePlan(_ request: RegeneratePlanRequest) async throws -> RegeneratePlanResponse {
        try await simulatedDelay()
        return generator.generate(
            GeneratePlanRequest(
                conversationID: request.conversationID,
                taskID: request.taskID,
                title: request.title,
                description: request.description,
                courseName: request.courseName,
                deadline: request.deadline,
                selectedType: request.selectedType,
                completedStageIDs: request.completedStageIDs,
                attachment: request.attachment,
                conversationHistory: request.conversationHistory
            )
        )
    }

    private func hasInput(_ request: ParseTaskRequest) -> Bool {
        let textual = [
            request.title,
            request.description,
            request.courseName,
        ]
        .joined()
        .trimmingCharacters(in: .whitespacesAndNewlines)

        return !textual.isEmpty || request.attachment != nil
    }

    private func simulatedDelay() async throws {
        try await Task.sleep(nanoseconds: 450_000_000)
    }
}
