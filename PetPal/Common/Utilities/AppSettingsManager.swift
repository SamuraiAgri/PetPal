// PetPal/Common/Utilities/AppSettingsManager.swift

import Foundation
import Combine
import UserNotifications

class AppSettingsManager: ObservableObject {
    static let shared = AppSettingsManager()
    
    // 設定項目
    @Published var enableFeedingReminders: Bool
    @Published var enableCareReminders: Bool
    @Published var enableVaccinationReminders: Bool
    @Published var feedingReminderTimes: [Date]
    
    // 設定保存のための UserDefaults キー
    private enum Keys {
        static let enableFeedingReminders = "enableFeedingReminders"
        static let enableCareReminders = "enableCareReminders"
        static let enableVaccinationReminders = "enableVaccinationReminders"
        static let feedingReminderTimes = "feedingReminderTimes"
    }
    
    private init() {
        // 設定を UserDefaults から読み込む
        self.enableFeedingReminders = UserDefaults.standard.bool(forKey: Keys.enableFeedingReminders)
        self.enableCareReminders = UserDefaults.standard.bool(forKey: Keys.enableCareReminders)
        self.enableVaccinationReminders = UserDefaults.standard.bool(forKey: Keys.enableVaccinationReminders)
        
        // デフォルトの給餌時間（朝7時と夕方6時）
        let defaultMorning = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
        let defaultEvening = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date()) ?? Date()
        
        // 保存されている時間を読み込むか、デフォルト値を使用
        if let timeIntervals = UserDefaults.standard.array(forKey: Keys.feedingReminderTimes) as? [Double] {
            self.feedingReminderTimes = timeIntervals.map { Date(timeIntervalSince1970: $0) }
        } else {
            self.feedingReminderTimes = [defaultMorning, defaultEvening]
        }
        
        // 設定変更を監視し、自動保存
        setupPublishers()
    }
    
    private func setupPublishers() {
        // 各設定変更時に自動保存するための Publisher を設定
        $enableFeedingReminders
            .dropFirst() // 初期化時の発行をスキップ
            .sink { [weak self] value in
                self?.saveBoolean(value, forKey: Keys.enableFeedingReminders)
                // 必要に応じて通知を更新
                self?.updateFeedingNotifications()
            }
            .store(in: &cancellables)
        
        $enableCareReminders
            .dropFirst()
            .sink { [weak self] value in
                self?.saveBoolean(value, forKey: Keys.enableCareReminders)
                // 必要に応じて通知を更新
            }
            .store(in: &cancellables)
        
        $enableVaccinationReminders
            .dropFirst()
            .sink { [weak self] value in
                self?.saveBoolean(value, forKey: Keys.enableVaccinationReminders)
                // 必要に応じて通知を更新
            }
            .store(in: &cancellables)
        
        $feedingReminderTimes
            .dropFirst()
            .sink { [weak self] times in
                self?.saveFeedingTimes(times)
                // 必要に応じて通知を更新
                self?.updateFeedingNotifications()
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    // 設定保存メソッド
    private func saveBoolean(_ value: Bool, forKey key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }
    
    private func saveFeedingTimes(_ times: [Date]) {
        let timeIntervals = times.map { $0.timeIntervalSince1970 }
        UserDefaults.standard.set(timeIntervals, forKey: Keys.feedingReminderTimes)
    }
    
    // 通知更新メソッド
    private func updateFeedingNotifications() {
        guard enableFeedingReminders else {
            // 通知が無効化されたら、関連する通知をキャンセル
            // NotificationManager.shared.cancelAllFeedingNotifications()
            
            // 代わりに、以下の方法でキャンセル
            UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                let feedingRequests = requests.filter { request in
                    return request.content.categoryIdentifier == Constants.Notification.feedingReminderCategory
                }
                
                let identifiers = feedingRequests.map { $0.identifier }
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
            }
            return
        }
        
        // 有効な全てのペットに対して給餌通知を設定し直す
        // 実際のアプリでは、PetViewModel を通じてアクティブなペットを取得
    }
    
    // 設定をリセット
    func resetToDefaults() {
        enableFeedingReminders = true
        enableCareReminders = true
        enableVaccinationReminders = true
        
        let defaultMorning = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
        let defaultEvening = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date()) ?? Date()
        feedingReminderTimes = [defaultMorning, defaultEvening]
    }
}
