import Foundation

struct BackendPlanningService: TaskPlanningService {
    private let apiClient: PlanAPIClient

    init(
        apiClient: PlanAPIClient = PlanAPIClient()
    ) {
        self.apiClient = apiClient
    }

    func parseTask(_ request: ParseTaskRequest) async throws -> ParseTaskResponse {
        do {
            let response = try await apiClient.parseTask(
                BackendParseTaskRequest(
                    conversationID: request.conversationID.uuidString,
                    taskID: request.taskID?.uuidString,
                    title: request.title,
                    userText: request.description,
                    courseName: request.courseName,
                    deadline: request.deadline.map { ISO8601DateFormatter.backend.string(from: $0) },
                    attachment: request.attachment.map(BackendUploadedAttachment.init),
                    extractedFileText: request.attachment?.backendExtractedText,
                    conversationHistory: request.conversationHistory,
                    taskSummary: request.taskSummary,
                    fileSummary: request.fileSummary,
                    recentConversation: request.recentConversation
                )
            )
            guard !response.fallback else {
                throw PlanningError.modelServiceFailed("任务识别未使用 Ark 结果：\(response.errorMessage ?? response.summary)")
            }
            let taskType = TaskType(rawValue: response.taskType) ?? .unknown
            return ParseTaskResponse(
                suggestedType: taskType,
                stages: response.stages.map {
                    StageDescriptor(id: $0.id, title: $0.title, detail: $0.detail)
                },
                clarifyingQuestions: response.clarifyingQuestions,
                confidence: response.confidence,
                summary: response.fallback ? response.summary : "已识别任务：\(response.summary)",
                taskSummary: response.taskSummary,
                fileSummary: response.fileSummary
            )
        } catch let error as PlanningError {
            Self.debugLog("parse planning error: \(error.localizedDescription)")
            throw error
        } catch {
            Self.debugLog("parse failed without iOS fallback: \(error.localizedDescription)")
            throw PlanningError.modelServiceFailed("任务识别失败：\(error.localizedDescription)")
        }
    }

    func generatePlan(_ request: GeneratePlanRequest) async throws -> GeneratePlanResponse {
        do {
            let response = try await apiClient.generatePlan(
                BackendGeneratePlanRequest(
                    conversationID: request.conversationID.uuidString,
                    taskID: request.taskID?.uuidString,
                    title: request.title,
                    userText: request.description,
                    courseName: request.courseName,
                    taskType: request.selectedType.rawValue,
                    deadline: ISO8601DateFormatter.backend.string(from: request.deadline),
                    completedStageIDs: request.completedStageIDs,
                    attachment: request.attachment.map(BackendUploadedAttachment.init),
                    extractedFileText: request.attachment?.backendExtractedText,
                    conversationHistory: request.conversationHistory,
                    taskSummary: request.taskSummary,
                    fileSummary: request.fileSummary,
                    recentConversation: request.recentConversation
                )
            )
            if response.status == "needs_clarification" {
                throw PlanningError.needsClarification(
                    response.question
                        ?? "我还没有识别到你的截止时间，请告诉我这项任务的 DDL（例如：5月1日14:00）"
                )
            }
            guard !response.fallback else {
                throw PlanningError.modelServiceFailed("计划生成未使用 Ark 结果：\(response.errorMessage ?? response.summary)")
            }
            guard !response.steps.isEmpty else {
                throw PlanningError.modelServiceFailed("计划生成返回空步骤，请稍后重试。")
            }
            return buildGeneratePlanResponse(from: response, request: request)
        } catch let error as PlanningError {
            Self.debugLog("generate planning error: \(error.localizedDescription)")
            throw error
        } catch {
            Self.debugLog("generate failed without iOS fallback: \(error.localizedDescription)")
            throw PlanningError.modelServiceFailed("计划生成失败：\(error.localizedDescription)")
        }
    }

    func regeneratePlan(_ request: RegeneratePlanRequest) async throws -> RegeneratePlanResponse {
        try await generatePlan(
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
                conversationHistory: request.conversationHistory,
                taskSummary: request.taskSummary,
                fileSummary: request.fileSummary,
                recentConversation: request.recentConversation
            )
        )
    }

    private func buildGeneratePlanResponse(
        from response: BackendGeneratePlanResponse,
        request: GeneratePlanRequest
    ) -> GeneratePlanResponse {
        let taskType = TaskType(rawValue: response.taskType) ?? request.selectedType
        let steadySteps = plannedSteps(
            from: response.steps,
            taskType: taskType,
            compressionRatio: 1.0
        )
        let rescueSteps = plannedSteps(
            from: response.steps,
            taskType: taskType,
            compressionRatio: 0.72
        )
        let steadyPlan = plannedMode(
            mode: .steady,
            steps: steadySteps,
            deadline: request.deadline,
            riskNote: response.riskNote
        )
        let rescuePlan = plannedMode(
            mode: .rescue,
            steps: rescueSteps,
            deadline: request.deadline,
            riskNote: response.riskNote ?? "救火模式会压缩非核心步骤，请优先保证可提交版本。"
        )

        let sourceLabel = response.fallback ? "后端生成" : "Ark"
        let errorLine = response.errorMessage.map { "\n后端提示：\($0)" } ?? ""
        return GeneratePlanResponse(
            taskSummary: "\(sourceLabel)已生成：\(response.summary)\(errorLine)",
            steadyPlan: steadyPlan,
            rescuePlan: rescuePlan,
            generationSource: response.source,
            isFallback: response.fallback,
            updatedTaskSummary: response.taskSummary,
            updatedFileSummary: response.fileSummary
        )
    }

    private func plannedSteps(
        from steps: [BackendPlanStep],
        taskType: TaskType,
        compressionRatio: Double
    ) -> [PlannedStep] {
        return steps.enumerated().map { index, step in
            let minEstimate = roundToFive(Int(Double(step.durationMin) * compressionRatio), minimum: 5)
            let maxEstimate = max(minEstimate, roundToFive(Int(Double(step.durationMax) * compressionRatio), minimum: 10))
            return PlannedStep(
                title: step.title,
                detail: step.description,
                order: index + 1,
                estimatedMin: minEstimate,
                estimatedMax: maxEstimate,
                estimateReason: step.estimateReason ?? "根据任务规模、复杂度、DDL 和材料要求，完成“\(step.title)”阶段大致所需用时为 \(minEstimate)-\(maxEstimate) 分钟。",
                toolWarning: step.toolWarning ?? toolWarning(for: taskType, title: step.title),
                phaseID: "backend-\(index + 1)",
                phaseTitle: step.title,
                isCore: step.isCore ?? true
            )
        }
    }

    private func plannedMode(
        mode: PlanMode,
        steps: [PlannedStep],
        deadline: Date,
        riskNote: String?
    ) -> PlannedMode {
        let totalMin = steps.reduce(0) { $0 + $1.estimatedMin }
        let totalMax = steps.reduce(0) { $0 + $1.estimatedMax }
        let minutesRemaining = max(deadline.timeIntervalSince(BeijingClock.now) / 60, 0)
        let highRisk = Double(totalMin) > minutesRemaining * 0.7
        let resolvedRiskNote = riskNote ?? (highRisk ? "时间不足，建议优先完成核心部分" : nil)

        return PlannedMode(
            mode: mode,
            totalMin: totalMin,
            totalMax: totalMax,
            isHighRisk: highRisk,
            riskNote: resolvedRiskNote,
            steps: steps
        )
    }

    private func toolWarning(for taskType: TaskType, title: String) -> String? {
        guard taskType == .coding || taskType == .design else { return nil }
        let toolKeywords = ["实现", "开发", "代码", "调试", "设计", "制作", "导出"]
        return toolKeywords.contains { title.contains($0) } ? "如不熟悉该工具，建议预留额外时间" : nil
    }

    private func roundToFive(_ value: Int, minimum: Int) -> Int {
        max(minimum, Int((Double(value) / 5.0).rounded()) * 5)
    }

    private static func debugLog(_ message: String) {
        guard AppConfig.networkLoggingEnabled else { return }
        print("[BackendPlanningService] \(message)")
    }
}

struct PlanAPIClient {
    private let baseURL: URL
    private let session: URLSession

    init(
        baseURL: URL = AppConfig.backendBaseURL,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
        debugLog("runtime network: \(AppConfig.runtimeNetworkSummary)")
    }

    func generatePlan(_ request: BackendGeneratePlanRequest) async throws -> BackendGeneratePlanResponse {
        let endpoint = baseURL.appending(path: "/api/plan/generate")
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 180
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        let startedAt = Date()
        let requestID = String(UUID().uuidString.prefix(8))

        debugLog("[\(requestID)] request start: POST \(endpoint.absoluteString)")
        debugLog("[\(requestID)] baseURL: \(baseURL.absoluteString)")
        debugLog("[\(requestID)] timeout: \(Int(urlRequest.timeoutInterval))s")
        debugLog("[\(requestID)] start time: \(logTimestamp(startedAt))")
        if let body = urlRequest.httpBody.flatMap({ String(data: $0, encoding: .utf8) }) {
            debugLog("[\(requestID)] request body: \(body)")
        }

        do {
            let (data, response) = try await session.data(for: urlRequest)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw PlanningError.networkUnavailable
            }

            let rawBody = String(data: data, encoding: .utf8) ?? ""
            logRequestEnd(
                requestID: requestID,
                endpoint: endpoint,
                startedAt: startedAt,
                statusCode: httpResponse.statusCode,
                rawBody: rawBody
            )

            guard (200..<300).contains(httpResponse.statusCode) else {
                throw PlanningError.modelServiceFailed("后端返回 HTTP \(httpResponse.statusCode)：\(rawBody)")
            }

            do {
                return try JSONDecoder().decode(BackendGeneratePlanResponse.self, from: data)
            } catch {
                debugLog("decode error: \(error.localizedDescription)")
                throw PlanningError.invalidModelResponse
            }
        } catch let error as PlanningError {
            debugLog("planning error: \(error.localizedDescription)")
            throw error
        } catch let error as URLError {
            logRequestFailure(requestID: requestID, endpoint: endpoint, startedAt: startedAt, error: error)
            if error.code == .timedOut {
                throw PlanningError.modelServiceFailed("请求 \(endpoint.path) 超时。计划可能仍在云端生成中，请稍后重试。")
            }
            throw PlanningError.modelServiceFailed("无法连接服务，请检查网络或稍后重试。\(error.localizedDescription)")
        } catch {
            logRequestFailure(requestID: requestID, endpoint: endpoint, startedAt: startedAt, error: error)
            throw error
        }
    }

    func parseTask(_ request: BackendParseTaskRequest) async throws -> BackendParseTaskResponse {
        let endpoint = baseURL.appending(path: "/api/plan/parse")
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 180
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        let startedAt = Date()
        let requestID = String(UUID().uuidString.prefix(8))

        debugLog("[\(requestID)] request start: POST \(endpoint.absoluteString)")
        debugLog("[\(requestID)] baseURL: \(baseURL.absoluteString)")
        debugLog("[\(requestID)] timeout: \(Int(urlRequest.timeoutInterval))s")
        debugLog("[\(requestID)] start time: \(logTimestamp(startedAt))")
        if let body = urlRequest.httpBody.flatMap({ String(data: $0, encoding: .utf8) }) {
            debugLog("[\(requestID)] parse request body: \(body)")
        }

        do {
            let (data, response) = try await session.data(for: urlRequest)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw PlanningError.networkUnavailable
            }

            let rawBody = String(data: data, encoding: .utf8) ?? ""
            logRequestEnd(
                requestID: requestID,
                endpoint: endpoint,
                startedAt: startedAt,
                statusCode: httpResponse.statusCode,
                rawBody: rawBody
            )

            guard (200..<300).contains(httpResponse.statusCode) else {
                throw PlanningError.modelServiceFailed("后端解析返回 HTTP \(httpResponse.statusCode)：\(rawBody)")
            }

            do {
                return try JSONDecoder().decode(BackendParseTaskResponse.self, from: data)
            } catch {
                debugLog("parse decode error: \(error.localizedDescription)")
                throw PlanningError.invalidModelResponse
            }
        } catch let error as PlanningError {
            debugLog("parse planning error: \(error.localizedDescription)")
            throw error
        } catch let error as URLError {
            logRequestFailure(requestID: requestID, endpoint: endpoint, startedAt: startedAt, error: error)
            if error.code == .timedOut {
                throw PlanningError.modelServiceFailed("请求 \(endpoint.path) 超时。请稍后重试。")
            }
            throw PlanningError.modelServiceFailed("无法连接服务，请检查网络或稍后重试。\(error.localizedDescription)")
        } catch {
            logRequestFailure(requestID: requestID, endpoint: endpoint, startedAt: startedAt, error: error)
            throw error
        }
    }

    private func debugLog(_ message: String) {
        guard AppConfig.networkLoggingEnabled else { return }
        print("[PlanAPIClient] \(message)")
    }

    private func logRequestEnd(
        requestID: String,
        endpoint: URL,
        startedAt: Date,
        statusCode: Int,
        rawBody: String
    ) {
        let finishedAt = Date()
        debugLog("[\(requestID)] request end: \(endpoint.absoluteString)")
        debugLog("[\(requestID)] end time: \(logTimestamp(finishedAt))")
        debugLog("[\(requestID)] duration: \(String(format: "%.2f", finishedAt.timeIntervalSince(startedAt)))s")
        debugLog("[\(requestID)] HTTP status code: \(statusCode)")
        debugLog("[\(requestID)] raw response body: \(rawBody)")
    }

    private func logRequestFailure(
        requestID: String,
        endpoint: URL,
        startedAt: Date,
        error: Error
    ) {
        let finishedAt = Date()
        debugLog("[\(requestID)] request failed: \(endpoint.absoluteString)")
        debugLog("[\(requestID)] end time: \(logTimestamp(finishedAt))")
        debugLog("[\(requestID)] duration: \(String(format: "%.2f", finishedAt.timeIntervalSince(startedAt)))s")
        debugLog("[\(requestID)] error: \(error.localizedDescription)")
        if let urlError = error as? URLError {
            debugLog("[\(requestID)] URL error code: \(urlError.code.rawValue)")
        }
    }

    private func logTimestamp(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}

struct BackendParseTaskRequest: Codable {
    let conversationID: String
    let taskID: String?
    let title: String
    let userText: String
    let courseName: String
    let deadline: String?
    let attachment: BackendUploadedAttachment?
    let extractedFileText: String?
    let conversationHistory: [String]
    let taskSummary: String?
    let fileSummary: String?
    let recentConversation: [String]
}

struct BackendParseTaskResponse: Codable {
    let taskType: String
    let summary: String
    let confidence: Double
    let clarifyingQuestions: [String]
    let stages: [BackendStageDescriptor]
    let source: String
    let fallback: Bool
    let errorMessage: String?
    let taskSummary: String?
    let fileSummary: String?
}

struct BackendStageDescriptor: Codable {
    let id: String
    let title: String
    let detail: String
}

struct BackendGeneratePlanRequest: Codable {
    let conversationID: String
    let taskID: String?
    let title: String
    let userText: String
    let courseName: String
    let taskType: String
    let deadline: String
    let completedStageIDs: [String]
    let attachment: BackendUploadedAttachment?
    let extractedFileText: String?
    let conversationHistory: [String]
    let taskSummary: String?
    let fileSummary: String?
    let recentConversation: [String]
}

struct BackendGeneratePlanResponse: Codable {
    let status: String?
    let missingField: String?
    let question: String?
    let detectedDeadline: String?
    let taskType: String
    let summary: String
    let source: String
    let fallback: Bool
    let errorMessage: String?
    let steps: [BackendPlanStep]
    let riskNote: String?
    let taskSummary: String?
    let fileSummary: String?
}

struct BackendPlanStep: Codable {
    let title: String
    let description: String
    let durationMin: Int
    let durationMax: Int
    let estimateReason: String?
    let toolWarning: String?
    let isCore: Bool?
}

struct BackendUploadedAttachment: Codable {
    let fileName: String
    let mimeType: String
    let fileSize: Int
    let extractedText: String
    let fileBase64: String?

    init(_ attachment: UploadedAttachment) {
        fileName = attachment.fileName
        mimeType = attachment.mimeType
        fileSize = attachment.fileSize
        extractedText = attachment.backendExtractedText
        // The cloud planner only needs extracted text/summary. Keeping raw file bytes
        // out of the request prevents large PDFs from causing API Gateway timeouts.
        fileBase64 = nil
    }
}

private extension ISO8601DateFormatter {
    static let backend: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = BeijingClock.timeZone
        return formatter
    }()
}

private extension UploadedAttachment {
    var backendExtractedText: String {
        let maxLength = 12_000
        guard extractedText.count > maxLength else { return extractedText }
        let endIndex = extractedText.index(extractedText.startIndex, offsetBy: maxLength)
        return String(extractedText[..<endIndex]) + "\n[文件内容较长，已在客户端截断；云端会基于摘要继续规划]"
    }
}
