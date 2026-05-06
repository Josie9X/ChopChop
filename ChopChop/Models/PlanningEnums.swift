import Foundation
import SwiftUI

enum TaskType: String, Codable, CaseIterable, Identifiable {
    case essay
    case report
    case presentation
    case coding
    case design
    case revision
    case unknown

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .essay: return "论文"
        case .report: return "报告"
        case .presentation: return "展示 / PPT"
        case .coding: return "编程作业"
        case .design: return "设计项目"
        case .revision: return "复习任务"
        case .unknown: return "待确认"
        }
    }

    var titleDisplayName: String {
        switch self {
        case .essay: return "论文作业"
        case .report: return "报告作业"
        case .presentation: return "展示作业"
        case .coding: return "编程作业"
        case .design: return "设计作业"
        case .revision: return "复习任务"
        case .unknown: return "任务"
        }
    }
}

enum PlanMode: String, Codable, CaseIterable, Identifiable {
    case steady
    case rescue

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .steady: return "稳健模式"
        case .rescue: return "救火模式"
        }
    }

    var tint: Color {
        switch self {
        case .steady: return Color.blue
        case .rescue: return Color.orange
        }
    }
}

enum TaskStatus: String, Codable, CaseIterable {
    case draft
    case generated
    case selected
    case inProgress
    case completed
    case overdue

    var displayName: String {
        switch self {
        case .draft: return "待输入"
        case .generated: return "已生成"
        case .selected: return "已选模式"
        case .inProgress: return "进行中"
        case .completed: return "已完成"
        case .overdue: return "已逾期"
        }
    }

    var tint: Color {
        switch self {
        case .draft: return .gray
        case .generated: return .blue
        case .selected: return .indigo
        case .inProgress: return .green
        case .completed: return .mint
        case .overdue: return .red
        }
    }
}

enum StepStatus: String, Codable, CaseIterable, Identifiable {
    case todo
    case doing
    case done
    case skipped

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .todo: return "待做"
        case .doing: return "进行中"
        case .done: return "已完成"
        case .skipped: return "已跳过"
        }
    }

    var tint: Color {
        switch self {
        case .todo: return .secondary
        case .doing: return .orange
        case .done: return .green
        case .skipped: return .gray
        }
    }
}

enum BeijingClock {
    static let timeZone = TimeZone(identifier: "Asia/Shanghai")!

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_Hans_CN")
        calendar.timeZone = timeZone
        return calendar
    }

    static var now: Date {
        Date()
    }

    static var defaultDeadline: Date {
        deadline(onSameDayAs: now)
    }

    static func deadline(onSameDayAs date: Date) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = 23
        components.minute = 55
        components.second = 0
        return calendar.date(from: components) ?? date
    }

    static func formatter(template: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter
    }
}
