import Foundation

struct PlanGenerator {
    struct StageBlueprint {
        let id: String
        let title: String
        let detail: String
        let stepTitle: String
        let stepDetail: String
        let baseMin: Int
        let baseMax: Int
        let isCore: Bool
    }

    private let nowProvider: () -> Date

    init(nowProvider: @escaping () -> Date = { BeijingClock.now }) {
        self.nowProvider = nowProvider
    }

    func stageDescriptors(for type: TaskType) -> [StageDescriptor] {
        stages(for: type).map { StageDescriptor(id: $0.id, title: $0.title, detail: $0.detail) }
    }

    func parse(_ request: ParseTaskRequest) -> ParseTaskResponse {
        let combined = [
            request.title,
            request.description,
            request.courseName,
            request.attachment?.fileName ?? "",
            request.attachment?.extractedText ?? "",
        ]
        .joined(separator: " ")
        .lowercased()

        let scores = TaskType.allCases.reduce(into: [TaskType: Int]()) { partialResult, type in
            partialResult[type] = keywords(for: type).reduce(into: 0) { score, keyword in
                if combined.contains(keyword) {
                    score += 1
                }
            }
        }

        let ranked = scores
            .filter { $0.key != .unknown }
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key.rawValue < rhs.key.rawValue
                }
                return lhs.value > rhs.value
            }

        let bestType = ranked.first?.value ?? 0 > 0 ? ranked.first!.key : fallbackType(from: combined)
        let confidence = confidenceScore(from: ranked)
        let stages = stageDescriptors(for: bestType)

        var questions: [String] = []
        if confidence < 0.55 || bestType == .unknown {
            questions.append("这次作业更接近哪一种任务类型，比如论文、编程作业、展示还是设计作业？")
        } else if request.description.count < 14 && request.attachment == nil {
            questions.append("这次作业更接近哪一种任务类型，比如论文、编程作业还是设计作业？")
        }

        if !containsDeadlineSignal(in: combined) {
            questions.append("这项任务的 DDL 是哪一天、几点前？")
        }

        if request.description.count < 30 || combined.contains("还没") || combined.contains("未开始") {
            questions.append("你目前已经完成了哪些阶段，还是完全还未开始？")
        }

        return ParseTaskResponse(
            suggestedType: bestType,
            stages: stages,
            clarifyingQuestions: questions,
            confidence: confidence,
            summary: summary(for: request, type: bestType, stages: stages)
        )
    }

    func generate(_ request: GeneratePlanRequest) -> GeneratePlanResponse {
        let taskType = request.selectedType == .unknown ? fallbackType(from: request.description.lowercased()) : request.selectedType
        let stageBlueprints = stages(for: taskType)
        let rawRemainingBlueprints = stageBlueprints.filter { !request.completedStageIDs.contains($0.id) }
        let remainingBlueprints = rawRemainingBlueprints.isEmpty ? [stageBlueprints.last].compactMap { $0 } : rawRemainingBlueprints

        let steadyPlan = buildMode(
            mode: .steady,
            sourceStages: remainingBlueprints,
            deadline: request.deadline,
            taskType: taskType
        )

        let rescuePlan = buildMode(
            mode: .rescue,
            sourceStages: remainingBlueprints,
            deadline: request.deadline,
            taskType: taskType
        )

        let summary = [
            "已识别为 \(taskType.displayName)",
            "剩余阶段 \(remainingBlueprints.count) 个",
            "已根据 DDL 生成稳健与救火两套可执行方案",
        ].joined(separator: " · ")

        return GeneratePlanResponse(
            taskSummary: summary,
            steadyPlan: steadyPlan,
            rescuePlan: rescuePlan
        )
    }

    private func buildMode(
        mode: PlanMode,
        sourceStages: [StageBlueprint],
        deadline: Date,
        taskType: TaskType
    ) -> PlannedMode {
        let now = nowProvider()
        let hoursRemaining = max(deadline.timeIntervalSince(now) / 3600, 0)
        let urgency = urgencyLevel(hoursRemaining: hoursRemaining)

        let filteredStages: [StageBlueprint]
        switch mode {
        case .steady:
            filteredStages = sourceStages
        case .rescue:
            filteredStages = compress(stages: sourceStages, urgency: urgency)
        }

        let multiplier: Double
        switch (mode, urgency) {
        case (.steady, .comfortable): multiplier = 1.0
        case (.steady, .tight): multiplier = 0.95
        case (.steady, .critical): multiplier = 0.9
        case (.rescue, .comfortable): multiplier = 0.8
        case (.rescue, .tight): multiplier = 0.68
        case (.rescue, .critical): multiplier = 0.52
        }

        let plannedSteps = filteredStages.enumerated().map { index, stage in
            let estimatedMin = roundedToFive(Double(stage.baseMin) * multiplier, minimum: 10)
            let estimatedMax = max(
                estimatedMin,
                roundedToFive(Double(stage.baseMax) * multiplier, minimum: 15)
            )

            return PlannedStep(
                title: stage.stepTitle,
                detail: adjustedDetail(for: stage, mode: mode, urgency: urgency, taskType: taskType),
                order: index + 1,
                estimatedMin: estimatedMin,
                estimatedMax: estimatedMax,
                estimateReason: estimateReason(
                    for: stage,
                    taskType: taskType,
                    mode: mode,
                    urgency: urgency,
                    multiplier: multiplier,
                    estimatedMin: estimatedMin,
                    estimatedMax: estimatedMax
                ),
                toolWarning: toolWarning(for: stage, taskType: taskType),
                phaseID: stage.id,
                phaseTitle: stage.title,
                isCore: stage.isCore
            )
        }

        let totalMin = plannedSteps.reduce(0) { $0 + $1.estimatedMin }
        let totalMax = plannedSteps.reduce(0) { $0 + $1.estimatedMax }
        let riskThreshold = hoursRemaining * 60 * 0.7
        let highRisk = Double(totalMin) > riskThreshold || urgency == .critical

        let riskNote: String?
        if highRisk {
            riskNote = mode == .rescue
                ? "剩余时间偏紧，已压缩非核心步骤，优先保证可提交版本。"
                : "按当前剩余时间看风险较高，建议优先评估救火模式。"
        } else if mode == .steady {
            riskNote = "时间仍可控，建议保留检查与缓冲。"
        } else {
            riskNote = "当前时间允许更快推进，但建议优先完成核心交付。"
        }

        return PlannedMode(
            mode: mode,
            totalMin: totalMin,
            totalMax: totalMax,
            isHighRisk: highRisk,
            riskNote: riskNote,
            steps: plannedSteps
        )
    }

    private func adjustedDetail(for stage: StageBlueprint, mode: PlanMode, urgency: UrgencyLevel, taskType: TaskType) -> String {
        switch (mode, urgency) {
        case (.rescue, .critical):
            return "\(stage.stepDetail) 先完成最低可交付版本，不在这一轮追求打磨。"
        case (.rescue, .tight):
            return "\(stage.stepDetail) 优先做核心产出，非关键润色放到最后。"
        case (.steady, .comfortable):
            return "\(stage.stepDetail) 建议留出检查和缓冲时间。"
        default:
            return stage.stepDetail
        }
    }

    private func compress(stages: [StageBlueprint], urgency: UrgencyLevel) -> [StageBlueprint] {
        switch urgency {
        case .comfortable:
            return stages
        case .tight:
            return stages.filter { $0.isCore || $0.id == "submission" || $0.id == "qa" }
        case .critical:
            let critical = stages.filter { $0.isCore || $0.id == "submission" }
            return critical.isEmpty ? Array(stages.prefix(2)) : critical
        }
    }

    private func estimateReason(
        for stage: StageBlueprint,
        taskType: TaskType,
        mode: PlanMode,
        urgency: UrgencyLevel,
        multiplier: Double,
        estimatedMin: Int,
        estimatedMax: Int
    ) -> String {
        let contextHint: String
        switch (mode, urgency) {
        case (.rescue, _):
            contextHint = "并结合当前时间比较紧张的情况做了压缩"
        case (_, .critical), (_, .tight):
            contextHint = "并参考当前截止时间做了适度调整"
        default:
            contextHint = "并保留了正常检查和缓冲空间"
        }

        return "根据研究分析得，完成“\(stage.title)”阶段大致所需用时为 \(estimatedMin)-\(estimatedMax) 分钟。系统会先参考同类\(taskType.displayName)任务的常见耗时区间，再\(contextHint)。"
    }

    private func toolWarning(for stage: StageBlueprint, taskType: TaskType) -> String? {
        switch taskType {
        case .coding:
            return stage.isCore ? "如不熟悉该工具，建议预留额外时间" : nil
        case .design:
            return stage.isCore || stage.id == "render" ? "如不熟悉该工具，建议预留额外时间" : nil
        case .presentation:
            return stage.id == "slides" || stage.id == "visual" ? "如不熟悉该工具，建议预留额外时间" : nil
        default:
            return nil
        }
    }

    private func summary(for request: ParseTaskRequest, type: TaskType, stages: [StageDescriptor]) -> String {
        let title = request.title.isEmpty ? "未命名任务" : request.title
        return "\(title) 已识别为 \(type.displayName)，建议先从 \(stages.first?.title ?? "准备阶段") 开始。"
    }

    private func confidenceScore(from ranked: [(key: TaskType, value: Int)]) -> Double {
        guard let best = ranked.first else { return 0.25 }
        let second = ranked.dropFirst().first?.value ?? 0
        return min(0.95, 0.4 + Double(best.value - second) * 0.18 + Double(best.value) * 0.05)
    }

    private func fallbackType(from text: String) -> TaskType {
        if text.contains("ppt") || text.contains("展示") || text.contains("汇报") {
            return .presentation
        }
        if text.contains("代码") || text.contains("编程") || text.contains("app") {
            return .coding
        }
        if text.contains("设计") || text.contains("渲染") || text.contains("作品集") {
            return .design
        }
        if text.contains("复习") || text.contains("考试") {
            return .revision
        }
        if text.contains("论文") || text.contains("报告") || text.contains("文献") {
            return .essay
        }
        return .unknown
    }

    private func containsDeadlineSignal(in text: String) -> Bool {
        let patterns = [
            #"\d{1,2}月\d{1,2}日"#,
            #"\d{1,2}/\d{1,2}"#,
            #"ddl|due|截止|deadline|明天|后天|今晚|明早|今天"#
        ]

        return patterns.contains { pattern in
            text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
        }
    }

    private func keywords(for type: TaskType) -> [String] {
        switch type {
        case .essay, .report:
            return ["论文", "report", "essay", "paper", "报告", "research", "文献", "reference"]
        case .presentation:
            return ["ppt", "presentation", "slides", "展示", "答辩", "汇报", "演讲"]
        case .coding:
            return ["编程", "代码", "code", "coding", "swift", "java", "python", "app", "开发"]
        case .design:
            return ["设计", "render", "渲染", "cad", "作品集", "海报", "prototype", "figma", "建模"]
        case .revision:
            return ["复习", "考试", "quiz", "revision", "midterm", "final"]
        case .unknown:
            return []
        }
    }

    private func stages(for type: TaskType) -> [StageBlueprint] {
        switch type {
        case .essay, .report:
            return [
                StageBlueprint(id: "scope", title: "确认题目与要求", detail: "明确题目范围、格式、评分点和提交要求。", stepTitle: "确认论文要求", stepDetail: "整理题目、字数、引用规范与评分标准，避免后续返工。", baseMin: 25, baseMax: 45, isCore: true),
                StageBlueprint(id: "research", title: "资料收集", detail: "收集参考文献和案例，建立论据基础。", stepTitle: "收集文献与素材", stepDetail: "优先寻找最相关的 3-5 个资料来源，避免无限扩散。", baseMin: 60, baseMax: 120, isCore: true),
                StageBlueprint(id: "outline", title: "搭建结构", detail: "先搭建框架，再补充内容。", stepTitle: "搭建提纲", stepDetail: "明确各章节顺序、核心论点和证据对应关系。", baseMin: 35, baseMax: 60, isCore: true),
                StageBlueprint(id: "draft", title: "完成初稿", detail: "按照提纲写出完整初稿。", stepTitle: "完成初稿", stepDetail: "先保证全文连贯，再补细节和润色。", baseMin: 90, baseMax: 180, isCore: true),
                StageBlueprint(id: "qa", title: "检查与润色", detail: "检查逻辑、引用、格式和错别字。", stepTitle: "润色与格式检查", stepDetail: "逐项核对参考文献、格式和论证逻辑。", baseMin: 35, baseMax: 70, isCore: false),
                StageBlueprint(id: "submission", title: "导出与提交", detail: "最终导出并提交到指定平台。", stepTitle: "提交终稿", stepDetail: "预留最终导出、命名和上传时间。", baseMin: 10, baseMax: 20, isCore: true),
            ]
        case .presentation:
            return [
                StageBlueprint(id: "scope", title: "明确汇报要求", detail: "确认时长、格式、主题和提交物。", stepTitle: "确认展示范围", stepDetail: "明确汇报主题、页数、是否需要口播稿或视频。", baseMin: 20, baseMax: 35, isCore: true),
                StageBlueprint(id: "storyline", title: "搭建叙事结构", detail: "先确定故事线，再逐页展开。", stepTitle: "搭建 PPT 逻辑结构", stepDetail: "列出每一页的核心结论，保证信息顺序清晰。", baseMin: 35, baseMax: 60, isCore: true),
                StageBlueprint(id: "slides", title: "制作核心页面", detail: "优先完成关键页面内容。", stepTitle: "完成核心页面", stepDetail: "先把结论页、方法页、结果页做完整。", baseMin: 80, baseMax: 150, isCore: true),
                StageBlueprint(id: "visual", title: "视觉统一与补强", detail: "调整图表、排版和视觉统一性。", stepTitle: "统一排版与视觉", stepDetail: "保证字体、配色、图表和留白一致。", baseMin: 40, baseMax: 80, isCore: false),
                StageBlueprint(id: "rehearsal", title: "试讲与修正", detail: "根据时长和表达效果调整页面。", stepTitle: "试讲并修正", stepDetail: "走一遍完整演示，删减超时或不清楚的内容。", baseMin: 30, baseMax: 60, isCore: false),
                StageBlueprint(id: "submission", title: "导出与提交", detail: "导出最终文件并检查兼容性。", stepTitle: "导出并提交 PPT", stepDetail: "导出 PDF/PPT，检查字体和动画是否正常。", baseMin: 10, baseMax: 20, isCore: true),
            ]
        case .coding:
            return [
                StageBlueprint(id: "scope", title: "确认需求与评分点", detail: "读懂题目、输入输出、限制和评分标准。", stepTitle: "确认编程作业要求", stepDetail: "明确功能边界、语言要求和交付格式。", baseMin: 25, baseMax: 45, isCore: true),
                StageBlueprint(id: "design", title: "拆分模块与方案", detail: "先设计结构，再开始编码。", stepTitle: "设计实现方案", stepDetail: "把功能拆成模块，列出数据流和关键函数。", baseMin: 35, baseMax: 60, isCore: true),
                StageBlueprint(id: "implementation", title: "实现核心功能", detail: "优先完成能跑通的主链路。", stepTitle: "编码核心功能", stepDetail: "先实现主要路径，再补边界条件和优化。", baseMin: 120, baseMax: 240, isCore: true),
                StageBlueprint(id: "testing", title: "调试与测试", detail: "覆盖常见输入与错误场景。", stepTitle: "调试并补测试", stepDetail: "检查报错、边界输入和示例数据结果。", baseMin: 45, baseMax: 90, isCore: true),
                StageBlueprint(id: "qa", title: "整理提交材料", detail: "检查注释、README、截图或演示要求。", stepTitle: "整理提交材料", stepDetail: "确认代码、说明文档、截图和压缩包命名。", baseMin: 20, baseMax: 40, isCore: false),
                StageBlueprint(id: "submission", title: "最终提交", detail: "打包并上传。", stepTitle: "提交代码成果", stepDetail: "预留打包、上传和平台检查时间。", baseMin: 10, baseMax: 20, isCore: true),
            ]
        case .design:
            return [
                StageBlueprint(id: "scope", title: "明确设计要求", detail: "确认提交物、尺寸、风格和评分标准。", stepTitle: "确认设计作业要求", stepDetail: "先对齐交付格式、版式尺寸和必交内容。", baseMin: 25, baseMax: 45, isCore: true),
                StageBlueprint(id: "concept", title: "确定概念方向", detail: "先定概念和参考，再动手制作。", stepTitle: "整理参考与概念", stepDetail: "选定 1-2 个主方向，避免反复推翻。", baseMin: 45, baseMax: 90, isCore: true),
                StageBlueprint(id: "production", title: "完成主体制作", detail: "进行建模、排版、绘制或页面制作。", stepTitle: "完成主体设计", stepDetail: "优先完成主体构图和关键画面。", baseMin: 120, baseMax: 240, isCore: true),
                StageBlueprint(id: "render", title: "渲染与导出", detail: "处理高耗时输出环节。", stepTitle: "渲染 / 导出中间成果", stepDetail: "提前跑渲染或导出，给失败重来留时间。", baseMin: 45, baseMax: 120, isCore: true),
                StageBlueprint(id: "qa", title: "排版与检查", detail: "统一版式，检查细节和展示效果。", stepTitle: "排版与细节检查", stepDetail: "检查对齐、分辨率、标注和最终展示效果。", baseMin: 35, baseMax: 70, isCore: false),
                StageBlueprint(id: "submission", title: "最终提交", detail: "命名、压缩并上传。", stepTitle: "提交设计成果", stepDetail: "确认导出格式和文件命名后再提交。", baseMin: 10, baseMax: 20, isCore: true),
            ]
        case .revision:
            return [
                StageBlueprint(id: "scope", title: "梳理考试范围", detail: "明确章节、题型与权重。", stepTitle: "确认复习范围", stepDetail: "先列出考试范围和高频考点。", baseMin: 20, baseMax: 35, isCore: true),
                StageBlueprint(id: "plan", title: "拆分复习模块", detail: "把内容拆成多个可执行块。", stepTitle: "拆分复习模块", stepDetail: "按章节或题型拆成几个可完成的复习块。", baseMin: 30, baseMax: 45, isCore: true),
                StageBlueprint(id: "practice", title: "完成重点练习", detail: "优先攻克高频与薄弱点。", stepTitle: "集中练习重点题型", stepDetail: "先补最薄弱、最容易失分的部分。", baseMin: 90, baseMax: 180, isCore: true),
                StageBlueprint(id: "review", title: "错题回顾", detail: "回收错误并查漏补缺。", stepTitle: "错题回顾", stepDetail: "把做错和不会的内容重新梳理一遍。", baseMin: 35, baseMax: 60, isCore: false),
                StageBlueprint(id: "submission", title: "考前检查", detail: "准备材料与考试安排。", stepTitle: "考前准备", stepDetail: "确认考试时间、地点、文具和登录信息。", baseMin: 10, baseMax: 20, isCore: true),
            ]
        case .unknown:
            return stages(for: .report)
        }
    }

    private enum UrgencyLevel {
        case comfortable
        case tight
        case critical

        var description: String {
            switch self {
            case .comfortable:
                return "DDL 还比较充裕"
            case .tight:
                return "DDL 已经比较接近"
            case .critical:
                return "DDL 非常紧急"
            }
        }
    }

    private func urgencyLevel(hoursRemaining: Double) -> UrgencyLevel {
        if hoursRemaining < 18 {
            return .critical
        }
        if hoursRemaining < 72 {
            return .tight
        }
        return .comfortable
    }

    private func roundedToFive(_ rawValue: Double, minimum: Int) -> Int {
        let rounded = Int((rawValue / 5.0).rounded()) * 5
        return max(minimum, rounded)
    }
}
