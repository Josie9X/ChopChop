import Foundation
import SwiftData

@MainActor
final class GeneratePlanViewModel: ObservableObject {
    struct ChatMessage: Identifiable {
        enum Role {
            case user
            case system
        }

        let id: UUID
        let role: Role
        var text: String
        var isLoading: Bool
        var confirmation: ConfirmationSnapshot?
        var regeneration: RegenerationSnapshot?
        var planResult: GeneratePlanResponse?
        let createdAt: Date = BeijingClock.now

        init(
            id: UUID = UUID(),
            role: Role,
            text: String,
            isLoading: Bool = false,
            confirmation: ConfirmationSnapshot? = nil,
            regeneration: RegenerationSnapshot? = nil,
            planResult: GeneratePlanResponse? = nil
        ) {
            self.id = id
            self.role = role
            self.text = text
            self.isLoading = isLoading
            self.confirmation = confirmation
            self.regeneration = regeneration
            self.planResult = planResult
        }
    }

    struct ConfirmationSnapshot: Identifiable {
        let id: UUID = UUID()
        var response: ParseTaskResponse
        var selectedType: TaskType
        var isTaskTypeConfirmed: Bool
        var deadline: Date
        var isDeadlineConfirmed: Bool
        var completedStageIDs: Set<String>
        var hasNotStarted: Bool
        var completionStatusConfirmed: Bool
        var isActive: Bool
    }

    struct RegenerationSnapshot: Identifiable {
        let id: UUID = UUID()
        var isActive: Bool
    }

    enum PlanningPhase {
        case input
        case parsing
        case stageConfirm
        case planGenerated
    }

    @Published var title: String = ""
    @Published var description: String = ""
    @Published var courseName: String = ""
    @Published var deadline: Date = BeijingClock.defaultDeadline
    @Published var attachedDocumentName: String?
    @Published var attachedAttachment: UploadedAttachment?
    @Published var messages: [ChatMessage] = []
    @Published var parseResponse: ParseTaskResponse?
    @Published var generatedPlan: GeneratePlanResponse?
    @Published var selectedType: TaskType = .unknown
    @Published var completedStageIDs: Set<String> = []
    @Published var hasNotStarted: Bool = false
    @Published var isDeadlineConfirmed: Bool = false
    @Published var completionStatusConfirmed: Bool = false
    @Published var phase: PlanningPhase = .input
    @Published var isBusy: Bool = false
    @Published var isImporterPresented: Bool = false
    @Published var inlineErrorMessage: String?
    @Published var documentWarning: String?
    @Published var deadlineClarification: String?
    @Published var isTaskTypeConfirmed: Bool = false
    @Published var isConfirmationCardVisible: Bool = false

    private let service: TaskPlanningService
    private let planGenerator = PlanGenerator()
    private let deadlineParser = DeadlineParser()
    private var conversationID = UUID()
    private var submittedDescription: String = ""
    private var submittedCourseName: String = ""
    private var submittedDeadline: Date?
    private var submittedDocumentName: String?
    private var submittedAttachment: UploadedAttachment?
    private var submittedTaskSummary: String?
    private var submittedFileSummary: String?
    private var editingTask: PlannerTask?

    init(service: TaskPlanningService) {
        self.service = service
        deadline = BeijingClock.defaultDeadline
    }

    var canSubmit: Bool {
        !isBusy &&
            (!description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || attachedDocumentName != nil)
    }

    var canGeneratePlan: Bool {
        !isBusy && hasCompletePlanContext
    }

    func importDocument(from result: Result<URL, Error>) async {
        switch result {
        case .success(let url):
            let allowedExtensions = ["pdf", "png", "jpg", "jpeg", "heic"]
            guard allowedExtensions.contains(url.pathExtension.lowercased()) else {
                documentWarning = "当前支持 PDF、PNG、JPG 图片，请改用文字补充。"
                return
            }
            do {
                let attachment = try await AttachmentTextExtractor.attachment(fromFileURL: url)
                attachedAttachment = attachment
                attachedDocumentName = attachment.fileName
                documentWarning = nil
            } catch {
                attachedAttachment = nil
                attachedDocumentName = nil
                documentWarning = "文件解析失败，请改用文字补充。"
            }
        case .failure:
            documentWarning = PlanningError.documentParsingFailed.localizedDescription
        }
    }

    func attachPhoto(data: Data, named name: String = "相册图片.jpg") async {
        do {
            let attachment = try await AttachmentTextExtractor.attachment(fromPhotoData: data, fileName: name)
            attachedAttachment = attachment
            attachedDocumentName = attachment.fileName
            documentWarning = nil
        } catch {
            attachedAttachment = nil
            attachedDocumentName = nil
            documentWarning = "图片文字识别失败，请改用文字补充。"
        }
    }

    func startNewTask() {
        resetComposer()
    }

    func updateSelectedType(_ type: TaskType) {
        selectedType = type
        isConfirmationCardVisible = true
        isTaskTypeConfirmed = type != .unknown
        guard var response = parseResponse else { return }
        response = ParseTaskResponse(
            suggestedType: type,
            stages: type == .unknown ? response.stages : planGenerator.stageDescriptors(for: type),
            clarifyingQuestions: requiredClarifyingQuestions,
            confidence: type == .unknown ? response.confidence : max(response.confidence, 0.8),
            summary: response.summary
        )
        parseResponse = response
        completedStageIDs = []
        hasNotStarted = false
        completionStatusConfirmed = false
        refreshActiveConfirmationCard()
    }

    func confirmTaskType() {
        isTaskTypeConfirmed = selectedType != .unknown
        isConfirmationCardVisible = true
        refreshClarifyingQuestions()
    }

    func toggleCompletedStage(_ stageID: String) {
        isConfirmationCardVisible = true
        hasNotStarted = false
        if completedStageIDs.contains(stageID) {
            completedStageIDs.remove(stageID)
        } else {
            completedStageIDs.insert(stageID)
        }
        completionStatusConfirmed = !completedStageIDs.isEmpty
        refreshClarifyingQuestions()
    }

    func toggleNotStarted() {
        isConfirmationCardVisible = true
        hasNotStarted.toggle()
        if hasNotStarted {
            completedStageIDs.removeAll()
            completionStatusConfirmed = true
        } else {
            completionStatusConfirmed = !completedStageIDs.isEmpty
        }
        refreshClarifyingQuestions()
    }

    func confirmDeadlineSelection() {
        submittedDeadline = deadline
        isDeadlineConfirmed = true
        isConfirmationCardVisible = true
        deadlineClarification = nil
        refreshClarifyingQuestions()
    }

    func updateDeadline(_ newDeadline: Date) {
        deadline = newDeadline
        submittedDeadline = newDeadline
        isDeadlineConfirmed = false
        isConfirmationCardVisible = true
        deadlineClarification = "请点击“确认 DDL”确认这个具体日期和时间点。"
        refreshClarifyingQuestions()
    }

    func sendForParsing() async {
        guard canSubmit else { return }

        isBusy = true
        defer { isBusy = false }
        inlineErrorMessage = nil
        phase = .parsing

        let currentDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentCourseName = courseName.trimmingCharacters(in: .whitespacesAndNewlines)
        let requestedNewTask = editingTask != nil && shouldTreatAsNewTask(currentDescription)
        if requestedNewTask {
            editingTask = nil
            conversationID = UUID()
            submittedDescription = ""
            submittedCourseName = ""
            submittedDeadline = nil
            submittedDocumentName = nil
            submittedAttachment = nil
            messages = []
            parseResponse = nil
            selectedType = .unknown
            isTaskTypeConfirmed = false
            completedStageIDs = []
            hasNotStarted = false
            completionStatusConfirmed = false
        }

        let wasContinuingTask = hasActiveConversationContext
        let previousType = selectedType
        let previousTypeConfirmed = isTaskTypeConfirmed
        let previousCompletedStageIDs = completedStageIDs
        let previousNotStarted = hasNotStarted
        let previousCompletionConfirmed = completionStatusConfirmed
        let shouldRecheckDeadline = !wasContinuingTask ||
            mentionsDeadlineUpdate(currentDescription) ||
            deadlineParser.containsExplicitDeadline(in: currentDescription)
        let shouldRecheckTaskStructure = !wasContinuingTask ||
            mentionsTaskTypeUpdate(currentDescription) ||
            mentionsScopeUpdate(currentDescription)
        let shouldRecheckCompletion = !wasContinuingTask ||
            mentionsProgressUpdate(currentDescription) ||
            mentionsScopeUpdate(currentDescription)
        let shouldShowConfirmationAfterParse = !wasContinuingTask ||
            shouldRecheckDeadline ||
            shouldRecheckTaskStructure ||
            shouldRecheckCompletion
        let explicitRegenerationRequested = wasContinuingTask &&
            mentionsExplicitRegenerationRequest(currentDescription)
        let shouldOfferRegenerationAfterDetailUpdate = wasContinuingTask &&
            !explicitRegenerationRequested &&
            (
                mentionsPlanImpactingDetailUpdate(currentDescription) ||
                mentionsScopeUpdate(currentDescription) ||
                mentionsProgressUpdate(currentDescription)
            )
        if !shouldOfferRegenerationAfterDetailUpdate {
            generatedPlan = nil
        }
        let contextDescription = contextualDescription(with: currentDescription)
        let detection = shouldRecheckDeadline
            ? deadlineParser.detect(in: currentDescription)
            : DeadlineParser.Detection(date: nil, kind: .noDeadlineMentioned, matchedText: nil)
        let detectedDeadline = detection.date
        let currentDeadline = detectedDeadline ?? submittedDeadline
        let currentAttachment = attachedAttachment ?? submittedAttachment
        let currentDocumentName = currentAttachment?.fileName ?? attachedDocumentName
        let userMessage = userFacingMessage(text: currentDescription, attachment: currentAttachment)

        submittedDescription = contextDescription
        submittedCourseName = currentCourseName.isEmpty ? submittedCourseName : currentCourseName
        submittedDeadline = currentDeadline
        submittedDocumentName = currentDocumentName
        submittedAttachment = currentAttachment
        if let currentDeadline {
            deadline = currentDeadline
        }
        isDeadlineConfirmed = detection.isConfirmed || (!shouldRecheckDeadline && currentDeadline != nil)
        deadlineClarification = isDeadlineConfirmed ? nil : detection.clarificationQuestion

        messages.append(.init(role: .user, text: userMessage))
        let loadingMessageID = appendLoadingMessage("正在调用 Doubao-Seed-2.0-mini 大模型识别任务类型和阶段…")
        description = ""
        attachedDocumentName = nil
        attachedAttachment = nil

        do {
            let response = try await service.parseTask(
                ParseTaskRequest(
                    conversationID: conversationID,
                    taskID: editingTask?.id,
                    title: currentDeadline.map { formattedTaskTitle(for: .unknown, deadline: $0) } ?? "待确认 DDL 任务",
                    description: contextDescription,
                    courseName: workingCourseName,
                    deadline: currentDeadline,
                    attachment: currentAttachment,
                    conversationHistory: recentConversationWindow(),
                    taskSummary: submittedTaskSummary,
                    fileSummary: submittedFileSummary,
                    recentConversation: recentConversationWindow()
                )
            )

            parseResponse = response
            submittedTaskSummary = response.taskSummary ?? response.summary
            if let fileSummary = response.fileSummary?.trimmingCharacters(in: .whitespacesAndNewlines), !fileSummary.isEmpty {
                submittedFileSummary = fileSummary
                submittedAttachment = nil
            }
            if shouldRecheckTaskStructure {
                selectedType = response.suggestedType
                isTaskTypeConfirmed = response.suggestedType != .unknown && response.confidence >= 0.75
            } else {
                selectedType = previousTypeConfirmed ? previousType : response.suggestedType
                isTaskTypeConfirmed = previousTypeConfirmed || (response.suggestedType != .unknown && response.confidence >= 0.75)
            }

            if shouldRecheckCompletion {
                if mentionsNotStarted(currentDescription) {
                    completedStageIDs = []
                    hasNotStarted = true
                    completionStatusConfirmed = true
                } else {
                    let inferredStages = inferredCompletedStageIDs(
                        from: currentDescription,
                        stages: parseResponse?.stages ?? response.stages
                    )
                    completedStageIDs = inferredStages
                    hasNotStarted = false
                    completionStatusConfirmed = !inferredStages.isEmpty
                }
            } else {
                completedStageIDs = previousCompletedStageIDs
                hasNotStarted = previousNotStarted
                completionStatusConfirmed = previousCompletionConfirmed
            }
            refreshClarifyingQuestions(summary: response.summary, confidence: response.confidence)
            phase = .stageConfirm
            replaceMessage(id: loadingMessageID, text: systemReplyText(summary: response.summary))
            if explicitRegenerationRequested && hasCompletePlanContext {
                replaceMessage(id: loadingMessageID, text: "已根据新信息更新任务理解，正在重新生成稳健模式和救火模式两套方案。")
                await requestRegeneratedPlans(managesBusy: false)
                return
            }
            if shouldShowConfirmationAfterParse || !requiredClarifyingQuestions.isEmpty {
                attachActiveConfirmationCard(to: loadingMessageID)
            }
            if shouldOfferRegenerationAfterDetailUpdate {
                attachActiveRegenerationCard(to: loadingMessageID)
            }
        } catch {
            removeMessage(id: loadingMessageID)
            handleRequestFailure(error, fallbackPhase: .input)
        }
    }

    func generatePlans() async {
        guard canGeneratePlan else { return }

        isBusy = true
        defer { isBusy = false }
        inlineErrorMessage = nil
        generatedPlan = nil
        let loadingMessageID = appendLoadingMessage("正在调用 Doubao-Seed-2.0-mini 大模型辅助拆解任务…")

        do {
            let activeDeadline = workingDeadline
            let response = try await service.generatePlan(
                GeneratePlanRequest(
                    conversationID: conversationID,
                    taskID: editingTask?.id,
                    title: formattedTaskTitle(for: selectedType, deadline: activeDeadline),
                    description: workingDescription,
                    courseName: workingCourseName,
                    deadline: activeDeadline,
                    selectedType: selectedType,
                    completedStageIDs: Array(completedStageIDs),
                    attachment: nil,
                    conversationHistory: recentConversationWindow(),
                    taskSummary: submittedTaskSummary,
                    fileSummary: submittedFileSummary,
                    recentConversation: recentConversationWindow()
                )
            )

            generatedPlan = response
            deactivateActiveConfirmationCards()
            submittedTaskSummary = response.updatedTaskSummary ?? response.taskSummary
            if let fileSummary = response.updatedFileSummary?.trimmingCharacters(in: .whitespacesAndNewlines), !fileSummary.isEmpty {
                submittedFileSummary = fileSummary
                submittedAttachment = nil
            }
            phase = .planGenerated
            replaceMessage(id: loadingMessageID, text: modelCallResultText(response))
            attachPlanResult(response, to: loadingMessageID)
        } catch PlanningError.needsClarification(let question) {
            generatedPlan = nil
            isDeadlineConfirmed = false
            isConfirmationCardVisible = true
            deadlineClarification = question
            refreshClarifyingQuestions()
            replaceMessage(id: loadingMessageID, text: question)
            attachActiveConfirmationCard(to: loadingMessageID)
        } catch {
            removeMessage(id: loadingMessageID)
            handleRequestFailure(error)
        }
    }

    func regeneratePlans() async {
        guard parseResponse != nil else { return }

        await requestRegeneratedPlans(managesBusy: true)
    }

    private func requestRegeneratedPlans(managesBusy: Bool) async {
        if managesBusy {
            isBusy = true
        }
        defer {
            if managesBusy {
                isBusy = false
            }
        }

        inlineErrorMessage = nil
        generatedPlan = nil
        deactivateActiveRegenerationCards()
        let loadingMessageID = appendLoadingMessage("正在重新请求 Doubao-Seed-2.0-mini 大模型更新计划…")

        do {
            let activeDeadline = workingDeadline
            let response = try await service.regeneratePlan(
                RegeneratePlanRequest(
                    conversationID: conversationID,
                    taskID: editingTask?.id,
                    title: formattedTaskTitle(for: selectedType, deadline: activeDeadline),
                    description: workingDescription,
                    courseName: workingCourseName,
                    deadline: activeDeadline,
                    selectedType: selectedType,
                    completedStageIDs: Array(completedStageIDs),
                    attachment: nil,
                    conversationHistory: recentConversationWindow(),
                    taskSummary: submittedTaskSummary,
                    fileSummary: submittedFileSummary,
                    recentConversation: recentConversationWindow()
                )
            )

            generatedPlan = response
            deactivateActiveConfirmationCards()
            submittedTaskSummary = response.updatedTaskSummary ?? response.taskSummary
            if let fileSummary = response.updatedFileSummary?.trimmingCharacters(in: .whitespacesAndNewlines), !fileSummary.isEmpty {
                submittedFileSummary = fileSummary
                submittedAttachment = nil
            }
            phase = .planGenerated
            replaceMessage(id: loadingMessageID, text: modelCallResultText(response))
            attachPlanResult(response, to: loadingMessageID)
        } catch PlanningError.needsClarification(let question) {
            generatedPlan = nil
            isDeadlineConfirmed = false
            isConfirmationCardVisible = true
            deadlineClarification = question
            refreshClarifyingQuestions()
            replaceMessage(id: loadingMessageID, text: question)
            attachActiveConfirmationCard(to: loadingMessageID)
        } catch {
            removeMessage(id: loadingMessageID)
            handleRequestFailure(error)
        }
    }

    func regeneratePlans(from promptID: UUID) async {
        resolveRegenerationPrompt(id: promptID, keepActive: false)
        await regeneratePlans()
    }

    func dismissRegenerationPrompt(id: UUID) {
        resolveRegenerationPrompt(id: id, keepActive: false)
    }

    private func modelCallResultText(_ response: GeneratePlanResponse) -> String {
        [
            response.isFallback ? "已生成计划" : "已调用大模型生成计划",
            response.generationSourceTitle,
            response.generationSourceDetail,
            response.taskSummary,
        ].joined(separator: "\n")
    }

    @discardableResult
    func confirmExecution(plan: PlannedMode, in modelContext: ModelContext) -> PlannerTask? {
        let steps = plan.steps.map { plannedStep in
            PlannerStep(
                title: plannedStep.title,
                stepDetail: plannedStep.detail,
                orderIndex: plannedStep.order,
                estimatedMin: plannedStep.estimatedMin,
                estimatedMax: plannedStep.estimatedMax,
                estimateReason: plannedStep.estimateReason,
                toolWarning: plannedStep.toolWarning,
                status: plannedStep.order == 1 ? .doing : .todo,
                phaseID: plannedStep.phaseID,
                phaseTitle: plannedStep.phaseTitle,
                isCore: plannedStep.isCore
            )
        }

        let task: PlannerTask
        if let existingTask = editingTask {
            let wasDefaultTitle = existingTask.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || existingTask.title == existingTask.defaultDisplayTitle

            for oldStep in existingTask.steps {
                modelContext.delete(oldStep)
            }

            existingTask.taskDescription = workingDescription
            existingTask.courseName = workingCourseName
            existingTask.deadline = workingDeadline
            existingTask.type = selectedType
            existingTask.selectedMode = plan.mode
            existingTask.status = .inProgress
            existingTask.sourceDocumentName = workingDocumentName
            existingTask.completedStageIDs = Array(completedStageIDs)
            existingTask.lastRiskNote = plan.riskNote
            existingTask.planningSummary = submittedTaskSummary ?? generatedPlan?.taskSummary
            existingTask.fileSummary = submittedFileSummary
            existingTask.conversationHistory = persistedConversationHistory(plan: plan)
            existingTask.steps = steps

            for step in steps {
                step.task = existingTask
            }

            if wasDefaultTitle {
                existingTask.title = formattedTaskTitle(for: selectedType, deadline: workingDeadline)
            }

            task = existingTask
        } else {
            task = PlannerTask(
                title: formattedTaskTitle(for: selectedType, deadline: workingDeadline),
                taskDescription: workingDescription,
                courseName: workingCourseName,
                deadline: workingDeadline,
                type: selectedType,
                selectedMode: plan.mode,
                status: .inProgress,
                sourceDocumentName: workingDocumentName,
                completedStageIDs: Array(completedStageIDs),
                lastRiskNote: plan.riskNote,
                planningSummary: submittedTaskSummary ?? generatedPlan?.taskSummary,
                fileSummary: submittedFileSummary,
                conversationHistory: persistedConversationHistory(plan: plan),
                steps: steps
            )

            modelContext.insert(task)
        }

        task.refreshDerivedState()

        do {
            try modelContext.save()
            resetComposer()
            return task
        } catch {
            inlineErrorMessage = "保存任务失败：\(error.localizedDescription)"
            return nil
        }
    }

    func resetComposer() {
        title = ""
        description = ""
        courseName = ""
        deadline = BeijingClock.defaultDeadline
        attachedDocumentName = nil
        attachedAttachment = nil
        parseResponse = nil
        generatedPlan = nil
        selectedType = .unknown
        isTaskTypeConfirmed = false
        completedStageIDs = []
        hasNotStarted = false
        isDeadlineConfirmed = false
        completionStatusConfirmed = false
        isConfirmationCardVisible = false
        phase = .input
        messages = []
        inlineErrorMessage = nil
        documentWarning = nil
        deadlineClarification = nil
        submittedDescription = ""
        submittedCourseName = ""
        submittedDeadline = nil
        submittedDocumentName = nil
        submittedAttachment = nil
        submittedTaskSummary = nil
        submittedFileSummary = nil
        editingTask = nil
        conversationID = UUID()
        deadline = BeijingClock.defaultDeadline
    }

    func loadTaskForEditing(_ task: PlannerTask) {
        editingTask = task
        conversationID = task.id
        title = task.displayTitle
        description = ""
        courseName = task.courseName
        deadline = task.deadline
        attachedDocumentName = nil
        submittedDescription = task.taskDescription
        submittedCourseName = task.courseName
        submittedDeadline = task.deadline
        submittedDocumentName = task.sourceDocumentName
        submittedAttachment = nil
        submittedTaskSummary = task.planningSummary
        submittedFileSummary = task.fileSummary
        selectedType = task.type
        isTaskTypeConfirmed = task.type != .unknown
        completedStageIDs = Set(task.completedStageIDs)
        hasNotStarted = task.completedStageIDs.isEmpty
        isDeadlineConfirmed = true
        completionStatusConfirmed = true
        parseResponse = ParseTaskResponse(
            suggestedType: task.type,
            stages: planGenerator.stageDescriptors(for: task.type),
            clarifyingQuestions: [],
            confidence: 0.95,
            summary: "已载入历史任务，你可以继续调整已完成阶段或重新生成计划。"
        )
        generatedPlan = nil
        phase = .stageConfirm
        isConfirmationCardVisible = true
        inlineErrorMessage = nil
        documentWarning = nil
        deadlineClarification = nil
        messages = task.conversationHistory.compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }

            if trimmed.hasPrefix("我：") {
                return ChatMessage(role: .user, text: String(trimmed.dropFirst(2)))
            }
            if trimmed.hasPrefix("系统：") {
                return ChatMessage(role: .system, text: String(trimmed.dropFirst(3)))
            }
            return ChatMessage(role: .system, text: trimmed)
        }

        if messages.isEmpty {
            messages = [
                .init(role: .system, text: "已载入历史任务，你可以继续修改计划。")
            ]
        }
        if let lastMessageID = messages.last?.id {
            attachActiveConfirmationCard(to: lastMessageID)
        }
    }

    private func persistedConversationHistory(plan: PlannedMode) -> [String] {
        var transcript = messages.map { message in
            let prefix = message.role == .user ? "我：" : "系统："
            return prefix + message.text
        }

        if let document = workingDocumentName {
            transcript.append("系统：参考文档 \(document)")
        }

        if let taskSummary = submittedTaskSummary, !taskSummary.isBlankForPlanning {
            transcript.append("系统：任务摘要 \(taskSummary)")
        }

        if let fileSummary = submittedFileSummary, !fileSummary.isBlankForPlanning {
            transcript.append("系统：文件摘要 \(fileSummary)")
        }

        transcript.append("系统：最终选择了\(plan.mode.displayName)")

        return transcript
    }

    private var workingDescription: String {
        let current = description.trimmingCharacters(in: .whitespacesAndNewlines)
        return current.isEmpty ? submittedDescription : current
    }

    private var workingCourseName: String {
        let current = courseName.trimmingCharacters(in: .whitespacesAndNewlines)
        return current.isEmpty ? submittedCourseName : current
    }

    private var workingDeadline: Date {
        submittedDeadline ?? deadline
    }

    private var workingDocumentName: String? {
        attachedDocumentName ?? submittedDocumentName
    }

    private var workingAttachment: UploadedAttachment? {
        attachedAttachment ?? submittedAttachment
    }

    private func formattedTaskTitle(for type: TaskType, deadline: Date) -> String {
        "\(deadline.deadlineTitlePrefix)\(type.titleDisplayName)"
    }

    private var requiredClarifyingQuestions: [String] {
        if selectedType == .unknown {
            return ["这次作业更接近哪一种任务类型？请先确认任务类型。"]
        }
        if !isTaskTypeConfirmed {
            return ["请确认任务类型是否正确，或在下拉菜单中修改后再继续。"]
        }
        if !isDeadlineConfirmed {
            return [deadlineClarification ?? "请确认 DDL 的具体日期和时间点。"]
        }
        if !completionStatusConfirmed {
            return ["请确认目前完成情况：选择已完成阶段，或选择“还未开始”。"]
        }
        return []
    }

    private func refreshClarifyingQuestions(summary: String? = nil, confidence: Double? = nil) {
        guard let response = parseResponse else { return }
        parseResponse = ParseTaskResponse(
            suggestedType: selectedType,
            stages: selectedType == .unknown ? response.stages : planGenerator.stageDescriptors(for: selectedType),
            clarifyingQuestions: requiredClarifyingQuestions,
            confidence: confidence ?? response.confidence,
            summary: summary ?? response.summary
        )
        refreshActiveConfirmationCard()
    }

    private func systemReplyText(summary: String) -> String {
        let questions = requiredClarifyingQuestions
        guard !questions.isEmpty else { return summary }
        return ([summary, "还需要补充："] + questions.map { "· \($0)" }).joined(separator: "\n")
    }

    private func appendLoadingMessage(_ text: String) -> UUID {
        let message = ChatMessage(role: .system, text: text, isLoading: true)
        messages.append(message)
        return message.id
    }

    private func replaceMessage(id: UUID, text: String) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else {
            messages.append(.init(role: .system, text: text))
            return
        }
        messages[index].text = text
        messages[index].isLoading = false
    }

    private func removeMessage(id: UUID) {
        messages.removeAll { $0.id == id }
    }

    private func appendErrorMessage(_ text: String) {
        messages.append(.init(role: .system, text: "调用失败：\(text)"))
    }

    private func handleRequestFailure(_ error: Error, fallbackPhase: PlanningPhase? = nil) {
        let message = error.localizedDescription
        if hasVisiblePlanResult {
            messages.append(
                .init(
                    role: .system,
                    text: "这次后台更新暂时失败，已保留上一次生成的计划。你可以稍后再试。\n\(message)"
                )
            )
            return
        }

        appendErrorMessage(message)
        inlineErrorMessage = message
        if let fallbackPhase {
            phase = fallbackPhase
        }
    }

    private func attachPlanResult(_ response: GeneratePlanResponse, to messageID: UUID) {
        guard let index = messages.firstIndex(where: { $0.id == messageID }) else {
            return
        }
        messages[index].planResult = response
    }

    private func currentConfirmationSnapshot(isActive: Bool) -> ConfirmationSnapshot? {
        guard let parseResponse else { return nil }
        return ConfirmationSnapshot(
            response: parseResponse,
            selectedType: selectedType,
            isTaskTypeConfirmed: isTaskTypeConfirmed,
            deadline: deadline,
            isDeadlineConfirmed: isDeadlineConfirmed,
            completedStageIDs: completedStageIDs,
            hasNotStarted: hasNotStarted,
            completionStatusConfirmed: completionStatusConfirmed,
            isActive: isActive
        )
    }

    private func attachActiveConfirmationCard(to messageID: UUID) {
        guard let snapshot = currentConfirmationSnapshot(isActive: true),
              let targetIndex = messages.firstIndex(where: { $0.id == messageID }) else {
            return
        }

        deactivateActiveConfirmationCards()
        messages[targetIndex].confirmation = snapshot
    }

    private func refreshActiveConfirmationCard() {
        guard let snapshot = currentConfirmationSnapshot(isActive: true),
              let index = messages.lastIndex(where: { $0.confirmation?.isActive == true }) else {
            return
        }
        messages[index].confirmation = snapshot
    }

    private func deactivateActiveConfirmationCards() {
        for index in messages.indices where messages[index].confirmation != nil {
            messages[index].confirmation?.isActive = false
        }
    }

    private func attachActiveRegenerationCard(to messageID: UUID) {
        guard let targetIndex = messages.firstIndex(where: { $0.id == messageID }) else {
            return
        }

        deactivateActiveRegenerationCards()
        messages[targetIndex].regeneration = RegenerationSnapshot(isActive: true)
    }

    private func deactivateActiveRegenerationCards() {
        for index in messages.indices where messages[index].regeneration != nil {
            messages[index].regeneration?.isActive = false
        }
    }

    private func resolveRegenerationPrompt(id: UUID, keepActive: Bool) {
        guard let index = messages.firstIndex(where: { $0.regeneration?.id == id }) else {
            return
        }
        messages[index].regeneration?.isActive = keepActive
    }

    private func contextualDescription(with newText: String) -> String {
        let trimmedPrevious = submittedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrevious.isEmpty, !newText.isEmpty else {
            return newText.isEmpty ? trimmedPrevious : newText
        }

        return "\(trimmedPrevious)\n补充修改：\(newText)"
    }

    private func userFacingMessage(text: String, attachment: UploadedAttachment?) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let attachment else {
            return trimmed
        }
        if trimmed.isEmpty {
            return "已上传附件：\(attachment.fileName)"
        }
        return "\(trimmed)\n已上传附件：\(attachment.fileName)"
    }

    private func currentConversationHistory() -> [String] {
        messages.map { message in
            let prefix = message.role == .user ? "用户" : "系统"
            return "\(prefix)：\(message.text)"
        }
    }

    private func recentConversationWindow(maxMessages: Int = 10) -> [String] {
        currentConversationHistory().suffix(maxMessages).map { $0 }
    }

    private var hasActiveConversationContext: Bool {
        editingTask != nil ||
            parseResponse != nil ||
            generatedPlan != nil ||
            !submittedDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            submittedTaskSummary?.isBlankForPlanning == false
    }

    private var hasVisiblePlanResult: Bool {
        generatedPlan != nil || messages.contains { $0.planResult != nil }
    }

    private var hasCompletePlanContext: Bool {
        parseResponse != nil &&
            selectedType != .unknown &&
            isTaskTypeConfirmed &&
            isDeadlineConfirmed &&
            completionStatusConfirmed
    }

    private func shouldTreatAsNewTask(_ text: String) -> Bool {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return false }

        let newTaskSignals = [
            "新任务", "新的任务", "另一个任务", "另一个作业", "另外一个作业",
            "新建", "重新新建", "不是这个", "换一个任务", "还有一个"
        ]

        return newTaskSignals.contains { normalized.contains($0) }
    }

    private func mentionsDeadlineUpdate(_ text: String) -> Bool {
        containsAny(
            text,
            [
                "时间变了", "时间改了", "改时间", "换时间", "截止时间变了", "截止时间改了",
                "deadline 改了", "deadline变了", "ddl 改了", "ddl变了", "DDL 改了", "DDL变了",
                "延期", "提前截止", "改到", "换到"
            ]
        )
    }

    private func mentionsProgressUpdate(_ text: String) -> Bool {
        containsAny(
            text,
            [
                "完成进度", "进度变了", "进度改了", "已经完成", "我完成了", "做完了",
                "还没开始", "没有开始", "完成阶段", "阶段变了", "阶段改了"
            ]
        )
    }

    private func mentionsNotStarted(_ text: String) -> Bool {
        containsAny(text, ["还没开始", "没有开始", "还未开始", "完全没开始", "从零开始"])
    }

    private func inferredCompletedStageIDs(from text: String, stages: [StageDescriptor]) -> Set<String> {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return [] }
        let completionSignals = ["完成", "做完", "写完", "整理完", "已经", "搞定", "结束"]
        guard completionSignals.contains(where: { normalized.localizedCaseInsensitiveContains($0) }) else {
            return []
        }

        let matched = stages.compactMap { stage -> String? in
            let titleTokens = stage.title
                .split { $0.isWhitespace || "，。、：:；;/-".contains($0) }
                .map(String.init)
                .filter { $0.count >= 2 }
            let detailTokens = stage.detail
                .split { $0.isWhitespace || "，。、：:；;/-".contains($0) }
                .map(String.init)
                .filter { $0.count >= 2 }
            let tokens = [stage.id, stage.title] + titleTokens + detailTokens.prefix(3)
            return tokens.contains { normalized.localizedCaseInsensitiveContains($0) } ? stage.id : nil
        }

        return Set(matched)
    }

    private func mentionsTaskTypeUpdate(_ text: String) -> Bool {
        containsAny(
            text,
            [
                "任务类型", "类型变了", "类型改了", "改成论文", "改成报告",
                "改成展示", "改成编程", "改成设计", "不是论文", "不是报告"
            ]
        )
    }

    private func mentionsScopeUpdate(_ text: String) -> Bool {
        containsAny(
            text,
            [
                "作业要求变了", "要求变了", "要求改了", "新增要求", "任务范围变了",
                "范围变了", "范围改了", "老师改要求", "题目变了", "题目改了"
            ]
        )
    }

    private func mentionsExplicitRegenerationRequest(_ text: String) -> Bool {
        containsAny(
            text,
            [
                "重新生成计划", "重新生成方案", "重新生成两套方案", "重新为我生成计划",
                "重新帮我生成计划", "请你重新", "帮我重新", "重新调整方案", "重新调整计划",
                "重新安排时间", "重新安排计划", "重新规划", "重新拆解", "再生成一次",
                "再帮我生成", "重新做一版", "重新出一版", "更新计划", "调整方案"
            ]
        )
    }

    private func mentionsPlanImpactingDetailUpdate(_ text: String) -> Bool {
        containsAny(
            text,
            [
                "难度变高", "更难", "很难", "复杂", "中等偏难", "工作量变大", "工作量很大",
                "花很多时间", "需要建模", "建模", "实验", "做实验", "写作", "调研",
                "文献", "查资料", "数据分析", "问卷", "访谈", "额外步骤", "新增步骤",
                "补充要求", "细节要求", "要求更多", "范围更大", "需要软件", "需要工具"
            ]
        )
    }

    private func containsAny(_ text: String, _ signals: [String]) -> Bool {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return false }
        return signals.contains { normalized.localizedCaseInsensitiveContains($0) }
    }

}

private extension String {
    var isBlankForPlanning: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
