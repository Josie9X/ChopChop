import Foundation

struct DeadlineParser {
    enum DetectionKind: Equatable {
        case explicitDateTime
        case explicitDateMissingTime
        case vagueTimeExpression
        case noDeadlineMentioned
        case refusedToProvide
        case userAllowedSystemDefault
    }

    struct Detection: Equatable {
        let date: Date?
        let kind: DetectionKind
        let matchedText: String?

        var hasExplicitDate: Bool {
            switch kind {
            case .explicitDateTime, .explicitDateMissingTime:
                return true
            case .vagueTimeExpression, .noDeadlineMentioned, .refusedToProvide, .userAllowedSystemDefault:
                return false
            }
        }

        var hasExplicitTime: Bool {
            kind == .explicitDateTime
        }

        var isConfirmed: Bool {
            kind == .explicitDateTime || kind == .userAllowedSystemDefault
        }

        var clarificationQuestion: String? {
            switch kind {
            case .explicitDateTime, .userAllowedSystemDefault:
                return nil
            case .explicitDateMissingTime:
                return "我识别到了日期，但还需要确认具体几点前截止。"
            case .vagueTimeExpression:
                return "你提到了较模糊的截止时间，请确认具体日期和几点前截止。"
            case .noDeadlineMentioned:
                return "请补充 DDL 的具体日期和时间点。"
            case .refusedToProvide:
                return "暂时不能生成计划：请手动选择 DDL，或明确说明允许系统代定截止时间。"
            }
        }
    }

    private let nowProvider: () -> Date

    init(nowProvider: @escaping () -> Date = { BeijingClock.now }) {
        self.nowProvider = nowProvider
    }

    func detect(in text: String) -> Detection {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return Detection(date: nil, kind: .noDeadlineMentioned, matchedText: nil)
        }

        if mentionsDeadlineRefusal(normalized) {
            return Detection(date: nil, kind: .refusedToProvide, matchedText: nil)
        }

        if mentionsSystemDefaultPermission(normalized) {
            return Detection(date: BeijingClock.defaultDeadline, kind: .userAllowedSystemDefault, matchedText: nil)
        }

        let time = extractedTime(from: normalized)

        if let relative = relativeDayDeadline(from: normalized, time: time) {
            return Detection(
                date: time.kind == .vague ? nil : relative.date,
                kind: detectionKind(for: time.kind),
                matchedText: relative.matchedText
            )
        }

        if let absolute = absoluteDateDeadline(from: normalized, time: time) {
            return Detection(
                date: time.kind == .vague ? nil : absolute,
                kind: detectionKind(for: time.kind),
                matchedText: nil
            )
        }

        if mentionsVagueDeadline(normalized) {
            return Detection(date: nil, kind: .vagueTimeExpression, matchedText: nil)
        }

        return Detection(date: nil, kind: .noDeadlineMentioned, matchedText: nil)
    }

    func containsExplicitDeadline(in text: String) -> Bool {
        let detection = detect(in: text)
        return detection.kind == .explicitDateTime || detection.kind == .explicitDateMissingTime
    }

    private func mentionsDeadlineRefusal(_ text: String) -> Bool {
        let signals = ["不知道截止", "不知道ddl", "不知道 ddl", "没有截止", "不确定截止", "先不填", "之后再说", "晚点再说"]
        return signals.contains { text.localizedCaseInsensitiveContains($0) }
    }

    private func mentionsSystemDefaultPermission(_ text: String) -> Bool {
        let signals = ["你帮我定", "系统代定", "帮我定一个", "随便定", "默认时间", "你来定ddl", "你来定 ddl"]
        return signals.contains { text.localizedCaseInsensitiveContains($0) }
    }

    private func mentionsVagueDeadline(_ text: String) -> Bool {
        let signals = ["明晚", "今晚", "下周", "周末", "月底", "月末", "最近", "这几天", "尽快", "asap"]
        return signals.contains { text.localizedCaseInsensitiveContains($0) }
    }

    private func relativeDayDeadline(
        from text: String,
        time: (hour: Int, minute: Int, kind: TimeKind)
    ) -> (date: Date, matchedText: String)? {
        let lowercasedText = text.lowercased()
        let days: Int
        let matchedText: String

        if lowercasedText.contains("今天") || lowercasedText.contains("今晚") {
            days = 0
            matchedText = lowercasedText.contains("今晚") ? "今晚" : "今天"
        } else if lowercasedText.contains("明天") || lowercasedText.contains("明早") || lowercasedText.contains("明晚") {
            days = 1
            matchedText = lowercasedText.contains("明晚") ? "明晚" : (lowercasedText.contains("明早") ? "明早" : "明天")
        } else if lowercasedText.contains("后天") {
            days = 2
            matchedText = "后天"
        } else {
            return nil
        }

        guard let baseDate = BeijingClock.calendar.date(byAdding: .day, value: days, to: nowProvider()) else {
            return nil
        }

        var components = BeijingClock.calendar.dateComponents([.year, .month, .day], from: baseDate)
        components.hour = time.hour
        components.minute = time.minute
        return BeijingClock.calendar.date(from: components).map { ($0, matchedText) }
    }

    private func absoluteDateDeadline(
        from text: String,
        time: (hour: Int, minute: Int, kind: TimeKind)
    ) -> Date? {
        let patterns = [
            #"(?:截止|ddl|due|deadline|到期|交付|提交|在)?\s*(\d{1,2})月(\d{1,2})[日号]"#,
            #"(?:截止|ddl|due|deadline|到期|交付|提交|在)?\s*(\d{1,2})[./](\d{1,2})"#,
            #"(?<!\d)(\d{4})(?!\d)"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            guard let match = regex.firstMatch(in: text, options: [], range: range) else { continue }

            let month: Int
            let day: Int
            if match.numberOfRanges == 2,
               let compactRange = Range(match.range(at: 1), in: text) {
                let compact = String(text[compactRange])
                let splitIndex = compact.index(compact.startIndex, offsetBy: 2)
                guard let parsedMonth = Int(compact[..<splitIndex]),
                      let parsedDay = Int(compact[splitIndex...]) else {
                    continue
                }
                month = parsedMonth
                day = parsedDay
            } else {
                guard let monthRange = Range(match.range(at: 1), in: text),
                      let dayRange = Range(match.range(at: 2), in: text),
                      let parsedMonth = Int(text[monthRange]),
                      let parsedDay = Int(text[dayRange]) else {
                    continue
                }
                month = parsedMonth
                day = parsedDay
            }

            if let candidate = date(month: month, day: day, time: time) {
                return candidate
            }
        }

        return chineseMonthDay(from: text, time: time)
    }

    fileprivate enum TimeKind {
        case explicit
        case vague
        case missing
    }

    private func detectionKind(for timeKind: TimeKind) -> DetectionKind {
        switch timeKind {
        case .explicit:
            return .explicitDateTime
        case .vague:
            return .vagueTimeExpression
        case .missing:
            return .explicitDateMissingTime
        }
    }

    private func extractedTime(from text: String) -> (hour: Int, minute: Int, kind: TimeKind) {
        let patterns = [
            #"(\d{1,2})[:：](\d{1,2})"#,
            #"(上午|早上|中午|下午|晚上|今晚)?\s*(\d{1,2})点(?:(\d{1,2})分?)?"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            guard let match = regex.firstMatch(in: text, range: range) else {
                continue
            }

            let hasPeriod = match.numberOfRanges > 3
            let hourGroupIndex = hasPeriod ? 2 : 1
            let minuteGroupIndex = hasPeriod ? 3 : 2

            guard let hourRange = Range(match.range(at: hourGroupIndex), in: text),
                  var hour = Int(text[hourRange]) else {
                continue
            }

            if hasPeriod,
               match.range(at: 1).location != NSNotFound,
               let periodRange = Range(match.range(at: 1), in: text) {
                let period = String(text[periodRange])
                if ["下午", "晚上", "今晚"].contains(period), hour < 12 {
                    hour += 12
                } else if period == "中午", hour < 11 {
                    hour += 12
                }
            }

            let minute: Int
            if match.numberOfRanges > minuteGroupIndex,
               match.range(at: minuteGroupIndex).location != NSNotFound,
               let minuteRange = Range(match.range(at: minuteGroupIndex), in: text),
               let parsedMinute = Int(text[minuteRange]) {
                minute = parsedMinute
            } else {
                minute = 0
            }

            if (0...23).contains(hour), (0...59).contains(minute) {
                return (hour, minute, .explicit)
            }
        }

        if text.contains("明晚") || text.contains("今晚") || text.contains("晚上") || text.contains("明早") {
            return (20, 0, .vague)
        }

        return (23, 55, .missing)
    }

    private func date(month: Int, day: Int, time: (hour: Int, minute: Int, kind: TimeKind)) -> Date? {
        guard (1...12).contains(month), (1...31).contains(day) else { return nil }
        var components = BeijingClock.calendar.dateComponents([.year], from: nowProvider())
        components.month = month
        components.day = day
        components.hour = time.hour
        components.minute = time.minute

        guard let candidate = BeijingClock.calendar.date(from: components) else { return nil }
        if candidate < BeijingClock.calendar.startOfDay(for: nowProvider()) {
            return BeijingClock.calendar.date(byAdding: .year, value: 1, to: candidate)
        }
        return candidate
    }

    private func chineseMonthDay(from text: String, time: (hour: Int, minute: Int, kind: TimeKind)) -> Date? {
        let pattern = #"([一二三四五六七八九十〇零]{1,3})月([一二三四五六七八九十〇零]{1,3})[日号]"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)),
              let monthRange = Range(match.range(at: 1), in: text),
              let dayRange = Range(match.range(at: 2), in: text),
              let month = chineseNumber(String(text[monthRange])),
              let day = chineseNumber(String(text[dayRange])) else {
            return nil
        }
        return date(month: month, day: day, time: time)
    }

    private func chineseNumber(_ text: String) -> Int? {
        let values: [Character: Int] = [
            "零": 0, "〇": 0, "一": 1, "二": 2, "三": 3, "四": 4,
            "五": 5, "六": 6, "七": 7, "八": 8, "九": 9
        ]

        if text == "十" { return 10 }
        if text.hasPrefix("十") {
            let ones = text.dropFirst().first.flatMap { values[$0] } ?? 0
            return 10 + ones
        }
        if text.contains("十") {
            let parts = text.split(separator: "十", omittingEmptySubsequences: false)
            let tens = parts.first?.first.flatMap { values[$0] } ?? 1
            let ones = parts.dropFirst().first?.first.flatMap { values[$0] } ?? 0
            return tens * 10 + ones
        }
        return text.reduce(0) { partial, character in
            guard let value = values[character] else { return partial }
            return partial * 10 + value
        }
    }
}
