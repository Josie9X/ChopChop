import SwiftUI

struct SurfaceCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground).opacity(0.92))
        )
    }
}

struct StatusPill: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}

struct ChatBubble: View {
    let text: String
    let isUser: Bool
    var isLoading: Bool = false

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 40) }
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
                Text(text)
                    .font(.subheadline)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isUser ? Color.black : Color(.secondarySystemBackground))
            )
            .foregroundStyle(isUser ? .white : .primary)
            if !isUser { Spacer(minLength: 40) }
        }
    }
}

struct StageChip: View {
    let stage: StageDescriptor
    let isSelected: Bool
    var isDisabled: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(stage.title)
                .font(.subheadline.weight(.semibold))
            Text(stage.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isSelected ? Color.green.opacity(0.18) : Color(.tertiarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isSelected ? Color.green : Color.clear, lineWidth: 1)
        )
        .opacity(isDisabled ? 0.35 : 1)
    }
}

struct PlanModeCard: View {
    let plan: PlannedMode
    let actionTitle: String
    let action: () -> Void
    @State private var isExpanded = false

    var body: some View {
        SurfaceCard {
            HStack {
                StatusPill(title: plan.mode.displayName, color: plan.mode.tint)
                Spacer()
                Text("\(plan.totalMin)-\(plan.totalMax) 分钟")
                    .font(.subheadline.weight(.semibold))
            }

            if let riskNote = plan.riskNote {
                Label(riskNote, systemImage: plan.isHighRisk ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                    .font(.footnote)
                    .foregroundStyle(plan.isHighRisk ? .orange : .secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(displayedSteps) { step in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(step.order). \(step.title)")
                            .font(.subheadline.weight(.medium))
                        Text(step.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        HStack(spacing: 6) {
                            Text("\(step.estimatedMin)-\(step.estimatedMax) 分钟")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            EstimateInfoButton(reason: step.estimateReason)
                        }

                        if let toolWarning = step.toolWarning {
                            Text(toolWarning)
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                }

                if plan.steps.count > 4 {
                    Button(isExpanded ? "收起步骤" : "展开剩余 \(plan.steps.count - 4) 个步骤") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain)
                }
            }

            Button(actionTitle, action: action)
                .buttonStyle(.borderedProminent)
                .tint(plan.mode.tint)
        }
    }

    private var displayedSteps: [PlannedStep] {
        isExpanded ? plan.steps : Array(plan.steps.prefix(4))
    }
}

struct ComposerTextEditor: View {
    let placeholder: String
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    var isDisabled: Bool = false
    @State private var measuredTextHeight: CGFloat = 28

    private let minHeight: CGFloat = 28
    private let lineHeight: CGFloat = 22
    private let maxVisibleLines: CGFloat = 12

    private var editorHeight: CGFloat {
        min(maxVisibleLines * lineHeight, max(minHeight, measuredTextHeight))
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(placeholder)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
                    .padding(.leading, 6)
            }

            TextEditor(text: $text)
                .focused(isFocused)
                .disabled(isDisabled)
                .scrollContentBackground(.hidden)
                .frame(height: editorHeight)
                .padding(.horizontal, 2)
                .padding(.vertical, 0)
                .opacity(isDisabled ? 0.55 : 1)

            Text(measurementText)
                .font(.body)
                .lineSpacing(0)
                .padding(.horizontal, 7)
                .padding(.vertical, 8)
                .foregroundStyle(.clear)
                .allowsHitTesting(false)
                .background(
                    GeometryReader { proxy in
                        Color.clear
                            .preference(key: ComposerTextHeightPreferenceKey.self, value: proxy.size.height)
                    }
                )
        }
        .onPreferenceChange(ComposerTextHeightPreferenceKey.self) { height in
            measuredTextHeight = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? minHeight
                : height
        }
        .onChange(of: text) { _, newValue in
            if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                measuredTextHeight = minHeight
            }
        }
        .animation(.spring(response: 0.22, dampingFraction: 0.9), value: editorHeight)
    }

    private var measurementText: String {
        let content = text.isEmpty ? " " : text
        return content.hasSuffix("\n") ? content + " " : content
    }
}

private struct ComposerTextHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 28

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct EstimateInfoButton: View {
    let reason: String
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .alert("系统如何估算时间", isPresented: $isPresented) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(reason)
        }
    }
}

struct HistoryTranscriptView: View {
    let task: PlannerTask

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SurfaceCard {
                    Text(task.displayTitle)
                        .font(.title3.weight(.bold))

                    HStack(spacing: 8) {
                        StatusPill(title: task.type.displayName, color: .indigo)
                        if let mode = task.selectedMode {
                            StatusPill(title: mode.displayName, color: mode.tint)
                        }
                    }

                    Text(task.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if let summary = task.planningSummary {
                        Text(summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("历史对话")
                        .font(.headline)

                    if task.conversationHistory.isEmpty {
                        Text("这条历史记录还没有保存详细对话。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(task.conversationHistory.enumerated()), id: \.offset) { _, line in
                            SurfaceCard {
                                Text(line)
                                    .font(.subheadline)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("历史内容")
        .navigationBarTitleDisplayMode(.inline)
    }
}
