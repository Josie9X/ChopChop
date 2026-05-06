import SwiftData
import SwiftUI
import PhotosUI
import UIKit
import UniformTypeIdentifiers

struct GeneratePlanView: View {
    @EnvironmentObject private var composer: GeneratePlanViewModel
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\PlannerTask.createdAt, order: .reverse)])
    private var historicalTasks: [PlannerTask]
    @State private var isHistoryPresented = false
    @State private var isAttachmentOptionsPresented = false
    @State private var isPhotoPickerPresented = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @FocusState private var isComposerFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if composer.messages.isEmpty && composer.parseResponse == nil && composer.generatedPlan == nil {
                            VStack(alignment: .leading, spacing: 10) {
                                Spacer()
                                    .frame(height: 120)
                                Text("把任务内容输到下方。")
                                    .font(.title3.weight(.semibold))
                                Text("系统会先给你一个初版结果，再根据已完成进度生成稳健模式和救火模式。")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                        }

                        if !composer.messages.isEmpty {
                            LazyVStack(spacing: 10) {
                                ForEach(composer.messages) { message in
                                    VStack(alignment: .leading, spacing: 10) {
                                        ChatBubble(
                                            text: message.text,
                                            isUser: message.role == .user,
                                            isLoading: message.isLoading
                                        )

                                        if let confirmation = message.confirmation {
                                            confirmationCard(confirmation)
                                        }

                                        if let regeneration = message.regeneration {
                                            regenerationCard(regeneration)
                                        }

                                        if let planResult = message.planResult {
                                            generatedPlansCard(planResult)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }

                        Spacer()
                            .frame(height: 180)
                    }
                    .padding(.top, 12)
                }
                .scrollDismissesKeyboard(.interactively)
                .simultaneousGesture(
                    TapGesture().onEnded {
                        isComposerFocused = false
                    }
                )

                if isAttachmentOptionsPresented {
                    attachmentOptionsOverlay
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    VStack(spacing: 8) {
                        HStack(alignment: .bottom, spacing: 10) {
                            Button {
                                isComposerFocused = false
                                withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
                                    isAttachmentOptionsPresented = true
                                }
                            } label: {
                                Image(systemName: "plus")
                                    .font(.title3.weight(.semibold))
                                    .frame(width: 24, height: 24)
                                    .foregroundStyle(.primary)
                            }
                            .padding(.leading, 6)
                            .disabled(composer.isBusy)
                            .opacity(composer.isBusy ? 0.35 : 1)

                            ComposerTextEditor(
                                placeholder: "输入你的任务内容…",
                                text: $composer.description,
                                isFocused: $isComposerFocused,
                                isDisabled: composer.isBusy
                            )

                            Button {
                                guard composer.canSubmit else { return }
                                isComposerFocused = false
                                Task {
                                    await composer.sendForParsing()
                                }
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(composer.canSubmit && !composer.isBusy ? Color.black : Color.gray.opacity(0.35))
                                        .frame(width: 34, height: 34)

                                    if composer.isBusy && composer.phase == .parsing {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Image(systemName: "arrow.up")
                                            .font(.headline.weight(.bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                            .disabled(!composer.canSubmit || composer.isBusy)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(
                            maxWidth: composerInputMaxWidth,
                            alignment: .leading
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .fill(Color(.systemGray6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                                )
                        )

                        VStack(alignment: .leading, spacing: 4) {
                            if let document = composer.attachedDocumentName {
                                Label("已附加：\(document)", systemImage: "paperclip")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if composer.isBusy {
                                Text(progressText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 82)
                    .background(Color(.systemBackground))
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isHistoryPresented = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.title3.weight(.medium))
                            .frame(width: 42, height: 42)
                            .background(Color(.systemGray6), in: Circle())
                    }
                    .buttonStyle(.plain)
                }

                ToolbarItem(placement: .principal) {
                    Text(composer.generatedPlan == nil ? "生成计划" : "计划结果")
                        .font(.headline.weight(.semibold))
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            composer.startNewTask()
                        }
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.title3.weight(.medium))
                            .frame(width: 42, height: 42)
                            .background(Color(.systemGray6), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("新建任务")
                }
            }
            .sheet(isPresented: $isHistoryPresented) {
                NavigationStack {
                    List {
                        if historicalTasks.isEmpty {
                            Text("还没有历史内容")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(historicalTasks) { task in
                                Button {
                                    composer.loadTaskForEditing(task)
                                    isHistoryPresented = false
                                } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(task.displayTitle)
                                            .font(.headline)
                                        Text(task.createdAt.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        if let summary = task.planningSummary {
                                            Text(summary)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(2)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .navigationTitle("历史对话")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("关闭") {
                                isHistoryPresented = false
                            }
                        }
                    }
                }
            }
            .fileImporter(
                isPresented: $composer.isImporterPresented,
                allowedContentTypes: [.pdf, .png, .jpeg, .image]
            ) { result in
                Task {
                    await composer.importDocument(from: result)
                }
            }
            .photosPicker(
                isPresented: $isPhotoPickerPresented,
                selection: $selectedPhotoItem,
                matching: .images
            )
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let item = newItem else { return }
                Task {
                    defer { selectedPhotoItem = nil }
                    guard let data = try? await item.loadTransferable(type: Data.self) else {
                        composer.documentWarning = "图片读取失败，请改用文字补充。"
                        return
                    }
                    await composer.attachPhoto(data: data)
                }
            }
            .alert(
                "提示",
                isPresented: Binding(
                    get: { composer.inlineErrorMessage != nil || composer.documentWarning != nil },
                    set: { isPresented in
                        if !isPresented {
                            composer.inlineErrorMessage = nil
                            composer.documentWarning = nil
                        }
                    }
                )
            ) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(composer.inlineErrorMessage ?? composer.documentWarning ?? "")
            }
            }
    }

    private var attachmentOptionsOverlay: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.16)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                        isAttachmentOptionsPresented = false
                    }
                }

            VStack(alignment: .leading, spacing: 18) {
                Capsule()
                    .fill(Color.secondary.opacity(0.25))
                    .frame(width: 48, height: 5)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                HStack {
                    Text("添加附件")
                        .font(.title3.weight(.bold))
                    Spacer()
                    Button("关闭") {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                            isAttachmentOptionsPresented = false
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                }

                Button {
                    guard !composer.isBusy else { return }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                        isAttachmentOptionsPresented = false
                    }
                    isPhotoPickerPresented = true
                } label: {
                    attachmentOptionRow(
                        icon: "photo.on.rectangle.angled",
                        title: "从相册选择图片",
                        subtitle: "适合上传作业截图、老师要求或图片说明"
                    )
                }
                .buttonStyle(.plain)

                Button {
                    guard !composer.isBusy else { return }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                        isAttachmentOptionsPresented = false
                    }
                    composer.isImporterPresented = true
                } label: {
                    attachmentOptionRow(
                        icon: "paperclip",
                        title: "上传 PDF 或图片文件",
                        subtitle: "支持 PDF、PNG、JPG、HEIC"
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 34)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: UnevenRoundedRectangle(topLeadingRadius: 34, topTrailingRadius: 34))
            .shadow(color: .black.opacity(0.14), radius: 24, y: -8)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .zIndex(20)
    }

    private func attachmentOptionRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2.weight(.medium))
                .frame(width: 42, height: 42)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func parseResultCard(_ parseResponse: ParseTaskResponse) -> some View {
        SurfaceCard {
            Text("任务识别与阶段确认")
                .font(.headline)

            HStack {
                StatusPill(title: parseResponse.suggestedType.displayName, color: .blue)
                Text("置信度 \(Int(parseResponse.confidence * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Picker("任务类型", selection: Binding(
                get: { composer.selectedType },
                set: { composer.updateSelectedType($0) }
            )) {
                ForEach(TaskType.allCases) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.menu)

            if composer.selectedType != .unknown {
                HStack {
                    Text(composer.isTaskTypeConfirmed ? "任务类型已确认" : "请先确认任务类型")
                        .font(.caption)
                        .foregroundStyle(composer.isTaskTypeConfirmed ? .green : .secondary)
                    Spacer()
                    Button(composer.isTaskTypeConfirmed ? "已确认" : "确认任务类型") {
                        composer.confirmTaskType()
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .disabled(composer.isTaskTypeConfirmed)
                }
            }

            if !parseResponse.clarifyingQuestions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("建议补充确认")
                        .font(.subheadline.weight(.semibold))
                    ForEach(parseResponse.clarifyingQuestions, id: \.self) { question in
                        Label(question, systemImage: "questionmark.circle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if composer.selectedType != .unknown {
                VStack(alignment: .leading, spacing: 10) {
                    Text("DDL 日期和时间（北京时间）")
                        .font(.subheadline.weight(.semibold))
                    DatePicker(
                        "选择 DDL",
                        selection: Binding(
                            get: { composer.deadline },
                            set: { composer.updateDeadline($0) }
                        ),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                    .environment(\.calendar, BeijingClock.calendar)
                    .environment(\.timeZone, BeijingClock.timeZone)
                    .environment(\.locale, Locale(identifier: "zh_Hans_CN"))

                    HStack {
                        Text(composer.isDeadlineConfirmed ? "已确认具体 DDL" : "请确认日期和具体时间点")
                            .font(.caption)
                            .foregroundStyle(composer.isDeadlineConfirmed ? .green : .secondary)
                        Spacer()
                        Button(composer.isDeadlineConfirmed ? "重新确认" : "确认 DDL") {
                            composer.confirmDeadlineSelection()
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                    }
                }
            }

            if composer.selectedType != .unknown && composer.isDeadlineConfirmed {
                Text("已完成哪些阶段？")
                    .font(.subheadline.weight(.semibold))

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(parseResponse.stages) { stage in
                        Button {
                            composer.toggleCompletedStage(stage.id)
                        } label: {
                            StageChip(
                                stage: stage,
                                isSelected: composer.completedStageIDs.contains(stage.id),
                                isDisabled: composer.hasNotStarted
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(composer.hasNotStarted)
                    }
                }

                HStack {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            composer.toggleNotStarted()
                        }
                    } label: {
                        Text("还未开始")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(composer.hasNotStarted ? .white : .primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(composer.hasNotStarted ? Color.black : Color(.systemGray6), in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button {
                        Task {
                            await composer.generatePlans()
                        }
                    } label: {
                        if composer.isBusy && composer.phase != .parsing {
                            ProgressView()
                        } else {
                            Text(generateButtonTitle)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!composer.canGeneratePlan || composer.isBusy)
                }
            }
        }
    }

    @ViewBuilder
    private func confirmationCard(_ snapshot: GeneratePlanViewModel.ConfirmationSnapshot) -> some View {
        if snapshot.isActive {
            parseResultCard(snapshot.response)
        } else {
            confirmationSnapshotCard(snapshot)
        }
    }

    private func regenerationCard(_ snapshot: GeneratePlanViewModel.RegenerationSnapshot) -> some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: snapshot.isActive ? "arrow.triangle.2.circlepath" : "checkmark.circle")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(snapshot.isActive ? .blue : .secondary)
                        .frame(width: 28, height: 28)
                        .background((snapshot.isActive ? Color.blue : Color.secondary).opacity(0.12), in: Circle())

                    VStack(alignment: .leading, spacing: 6) {
                        Text("是否重新生成方案？")
                            .font(.headline)
                        Text(snapshot.isActive ? "我已根据新信息更新任务理解，是否需要我重新生成稳健模式和救火模式两套方案？" : "这次补充已记录。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if snapshot.isActive {
                    if !composer.canGeneratePlan {
                        Text("请先完成上方必要确认，再重新生成方案。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 10) {
                        Button("暂不生成") {
                            composer.dismissRegenerationPrompt(id: snapshot.id)
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .disabled(composer.isBusy)

                        Button {
                            Task {
                                await composer.regeneratePlans(from: snapshot.id)
                            }
                        } label: {
                            if composer.isBusy {
                                ProgressView()
                            } else {
                                Text("重新生成方案")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .disabled(!composer.canGeneratePlan || composer.isBusy)
                    }
                } else {
                    StatusPill(title: "已处理", color: .secondary)
                }
            }
        }
    }

    private func confirmationSnapshotCard(_ snapshot: GeneratePlanViewModel.ConfirmationSnapshot) -> some View {
        SurfaceCard {
            HStack {
                Text("任务识别与阶段确认")
                    .font(.headline)
                Spacer()
                Text("历史确认")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(.systemGray6), in: Capsule())
            }

            HStack(spacing: 8) {
                StatusPill(title: snapshot.selectedType.displayName, color: .blue)
                if snapshot.isTaskTypeConfirmed {
                    StatusPill(title: "类型已确认", color: .green)
                }
            }

            if snapshot.selectedType != .unknown {
                VStack(alignment: .leading, spacing: 6) {
                    Text("DDL（北京时间）")
                        .font(.subheadline.weight(.semibold))
                    Text(snapshot.isDeadlineConfirmed ? snapshot.deadline.formatted(date: .abbreviated, time: .shortened) : "尚未确认具体 DDL")
                        .font(.caption)
                        .foregroundStyle(snapshot.isDeadlineConfirmed ? .primary : .secondary)
                }
            }

            if snapshot.selectedType != .unknown && snapshot.isDeadlineConfirmed {
                VStack(alignment: .leading, spacing: 8) {
                    Text("完成情况")
                        .font(.subheadline.weight(.semibold))

                    if snapshot.hasNotStarted {
                        StatusPill(title: "还未开始", color: .secondary)
                    } else if snapshot.completedStageIDs.isEmpty {
                        Text(snapshot.completionStatusConfirmed ? "已确认暂无已完成阶段" : "尚未确认完成阶段")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(snapshot.response.stages.filter { snapshot.completedStageIDs.contains($0.id) }) { stage in
                                Text(stage.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.green)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.green.opacity(0.12), in: Capsule())
                            }
                        }
                    }
                }
            }
        }
    }

    private var generateButtonTitle: String {
        if composer.selectedType == .unknown {
            return "先确认任务类型"
        }
        if !composer.isTaskTypeConfirmed {
            return "先确认任务类型"
        }
        if !composer.isDeadlineConfirmed {
            return "先确认 DDL"
        }
        if !composer.completionStatusConfirmed {
            return "先确认完成情况"
        }
        return "生成两套计划"
    }

    private func generatedPlansCard(_ generated: GeneratePlanResponse) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SurfaceCard {
                VStack(alignment: .leading, spacing: 12) {
                    ModelSourceBadge(generated: generated)

                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("计划结果")
                                .font(.headline)
                            Text(generated.taskSummary)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            Task {
                                await composer.regeneratePlans()
                            }
                        } label: {
                            Label("重新生成", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .disabled(composer.isBusy)
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    PlanModeCard(plan: generated.steadyPlan, actionTitle: "开始执行稳健模式") {
                        confirm(plan: generated.steadyPlan)
                    }
                    .frame(width: 292)

                    PlanModeCard(plan: generated.rescuePlan, actionTitle: "开始执行救火模式") {
                        confirm(plan: generated.rescuePlan)
                    }
                    .frame(width: 292)
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private struct ModelSourceBadge: View {
        let generated: GeneratePlanResponse

        var body: some View {
            HStack(spacing: 10) {
                Image(systemName: generated.isFallback ? "exclamationmark.triangle.fill" : "sparkles")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(generated.isFallback ? .orange : .green)

                VStack(alignment: .leading, spacing: 2) {
                    Text(generated.generationSourceTitle)
                        .font(.subheadline.weight(.semibold))
                    Text(generated.generationSourceDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Text(generated.generationSource)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color(.systemBackground).opacity(0.75), in: Capsule())
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(generated.isFallback ? Color.orange.opacity(0.12) : Color.green.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(generated.isFallback ? Color.orange.opacity(0.22) : Color.green.opacity(0.22), lineWidth: 1)
            )
        }
    }

    private var progressText: String {
        switch composer.phase {
        case .input:
            return "等待输入"
        case .parsing:
            return "正在分析任务类型和标准阶段…"
        case .stageConfirm:
            return "正在准备阶段确认…"
        case .planGenerated:
            return "正在生成稳健与救火两套方案…"
        }
    }

    private var composerInputMaxWidth: CGFloat {
        let trimmed = composer.description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 300 }
        let screenWidth = UIScreen.main.bounds.width - 32
        let textWidth = CGFloat(min(trimmed.count, 26)) * 10 + 138
        return min(screenWidth, max(300, textWidth))
    }

    private func confirm(plan: PlannedMode) {
        guard let task = composer.confirmExecution(plan: plan, in: modelContext) else { return }
        appState.highlightedTaskID = task.id
        appState.selectedTab = .myTasks
    }
}
