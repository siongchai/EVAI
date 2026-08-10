import Foundation

extension Date {
    var startOfMonth: Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: self)) ?? self
    }

    var endOfMonth: Date {
        guard let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: startOfMonth),
              let end = Calendar.current.date(byAdding: .day, value: -1, to: nextMonth) else {
            return self
        }
        return Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: end) ?? end
    }

    func isSameMonth(as other: Date) -> Bool {
        Calendar.current.isDate(self, equalTo: other, toGranularity: .month)
    }

    var monthYearDisplay: String {
        formatted(.dateTime.month(.wide).year())
    }

    var dayMonthYearDisplay: String {
        formatted(.dateTime.day().month(.abbreviated).year())
    }

    var timeDisplay: String {
        formatted(date: .omitted, time: .shortened)
    }

    var dayOfMonth: Int {
        Calendar.current.component(.day, from: self)
    }
}
