import Foundation

extension Date {
    // 日付のみを取得（時間部分を00:00:00に設定）
    var startOfDay: Date {
        return Calendar.current.startOfDay(for: self)
    }
    
    // 指定した日数を加算した日付を取得
    func addingDays(_ days: Int) -> Date {
        return Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }
    
    // 指定した月数を加算した日付を取得
    func addingMonths(_ months: Int) -> Date {
        return Calendar.current.date(byAdding: .month, value: months, to: self) ?? self
    }
    
    // 日付から年齢を計算
    func yearsFrom() -> Int {
        return Calendar.current.dateComponents([.year], from: self, to: Date()).year ?? 0
    }
    
    // 「〇〇歳〇ヶ月」形式の文字列を取得
    func ageString() -> String {
        let components = Calendar.current.dateComponents([.year, .month], from: self, to: Date())
        let years = components.year ?? 0
        let months = components.month ?? 0
        
        if years == 0 {
            return "\(months)ヶ月"
        } else {
            return "\(years)歳\(months)ヶ月"
        }
    }
    
    // 曜日を取得
    var weekday: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "E"
        return formatter.string(from: self)
    }
    
    // 日付フォーマット（yyyy/MM/dd）
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: self)
    }
    
    // 時刻フォーマット（HH:mm）
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: self)
    }
    
    // 日時フォーマット（yyyy/MM/dd HH:mm）
    var formattedDateTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: self)
    }
}
