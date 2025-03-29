import SwiftUI

extension Color {
    // メインカラー
    static let primaryApp = Color("PrimaryApp")
    static let secondaryApp = Color("SecondaryApp")
    static let accentApp = Color("AccentApp")
    
    // 背景色
    static let backgroundPrimary = Color("BackgroundPrimary")
    static let backgroundSecondary = Color("BackgroundSecondary")
    
    // テキスト色
    static let textPrimary = Color("TextPrimary")
    static let textSecondary = Color("TextSecondary")
    static let textAccent = Color("TextAccent")
    
    // ステータス色
    static let successApp = Color("SuccessApp")
    static let warningApp = Color("WarningApp")
    static let errorApp = Color("ErrorApp")
    static let infoApp = Color("InfoApp")
    
    // ケアタイプ色
    static let walkApp = Color("WalkApp")
    static let feedingApp = Color("FeedingApp")
    static let groomingApp = Color("GroomingApp")
    static let medicationApp = Color("MedicationApp")
    static let healthApp = Color("HealthApp")
    
    // カラー取得ヘルパー
    static func forCareType(_ type: String) -> Color {
        switch type.lowercased() {
        case "walk", "散歩":
            return .walkApp
        case "feeding", "feed", "給餌":
            return .feedingApp
        case "grooming", "groom", "グルーミング":
            return .groomingApp
        case "medication", "medicine", "投薬":
            return .medicationApp
        case "health", "healthcheck", "健康チェック":
            return .healthApp
        default:
            return .accentApp
        }
    }
}
