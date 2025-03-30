// PetPal/Common/Extensions/Color+Extension.swift

import SwiftUI

extension Color {
    // メインカラーをより魅力的な色に変更
    static let primaryApp = Color(red: 0.2, green: 0.5, blue: 0.8) // 鮮やかなブルー
    static let secondaryApp = Color(red: 0.9, green: 0.6, blue: 0.3) // オレンジ系
    static let accentApp = Color(red: 0.6, green: 0.2, blue: 0.8) // パープル
    
    // 背景色を微調整
    static let backgroundPrimary = Color(red: 0.98, green: 0.98, blue: 0.98) // わずかに色のある白
    static let backgroundSecondary = Color(red: 0.95, green: 0.95, blue: 0.97) // 薄い青紫
    
    // テキスト色
    static let textPrimary = Color(red: 0.2, green: 0.2, blue: 0.25) // 濃い青灰色
    static let textSecondary = Color(red: 0.5, green: 0.5, blue: 0.55) // 中間の青灰色
    static let textAccent = Color(red: 0.3, green: 0.5, blue: 0.8) // 明るい青
    
    // ステータス色
    static let successApp = Color(red: 0.2, green: 0.7, blue: 0.4) // 鮮やかな緑
    static let warningApp = Color(red: 0.95, green: 0.7, blue: 0.2) // 鮮やかな黄色
    static let errorApp = Color(red: 0.9, green: 0.3, blue: 0.3) // 鮮やかな赤
    static let infoApp = Color(red: 0.3, green: 0.6, blue: 0.9) // 明るい青
    
    // ケアタイプ色をより鮮やかに
    static let walkApp = Color(red: 0.3, green: 0.7, blue: 0.9) // 明るいスカイブルー
    static let feedingApp = Color(red: 0.8, green: 0.6, blue: 0.3) // ゴールデン
    static let groomingApp = Color(red: 0.7, green: 0.4, blue: 0.7) // ラベンダー
    static let medicationApp = Color(red: 0.9, green: 0.4, blue: 0.4) // サーモンピンク
    static let healthApp = Color(red: 0.4, green: 0.8, blue: 0.6) // ミントグリーン
    
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
