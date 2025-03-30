import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {
        requestPermission()
    }
    
    // 通知許可リクエスト
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("通知許可エラー: \(error)")
            }
        }
    }
    
    // 給餌リマインダーの設定
    func scheduleFeedingReminder(petId: UUID, petName: String, time: Date) {
        let content = UNMutableNotificationContent()
        content.title = "給餌リマインダー"
        content.body = "\(petName)の給餌時間です"
        content.sound = .default
        content.badge = 1
        content.categoryIdentifier = Constants.Notification.feedingReminderCategory
        content.userInfo = ["petId": petId.uuidString]
        
        // 時間コンポーネントの作成
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        
        // リクエストの作成と登録
        let request = UNNotificationRequest(
            identifier: "feeding-\(petId.uuidString)-\(components.hour ?? 0)-\(components.minute ?? 0)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("給餌リマインダー設定エラー: \(error)")
            }
        }
    }
    
    // ケアリマインダーの設定
    func scheduleCareReminder(petId: UUID, petName: String, careType: String, time: Date) {
        let content = UNMutableNotificationContent()
        content.title = "\(careType)リマインダー"
        content.body = "\(petName)の\(careType)時間です"
        content.sound = .default
        content.badge = 1
        content.categoryIdentifier = Constants.Notification.careReminderCategory
        content.userInfo = ["petId": petId.uuidString, "careType": careType]
        
        // 時間コンポーネントの作成
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        
        // リクエストの作成と登録
        let request = UNNotificationRequest(
            identifier: "care-\(petId.uuidString)-\(careType)-\(components.hour ?? 0)-\(components.minute ?? 0)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("ケアリマインダー設定エラー: \(error)")
            }
        }
    }
    
    // ワクチンリマインダーの設定
    func scheduleVaccinationReminder(petId: UUID, petName: String, vaccineName: String, date: Date) {
        let content = UNMutableNotificationContent()
        content.title = "ワクチンリマインダー"
        content.body = "\(petName)の\(vaccineName)の接種予定日が近づいています"
        content.sound = .default
        content.badge = 1
        content.categoryIdentifier = Constants.Notification.vaccinationReminderCategory
        content.userInfo = ["petId": petId.uuidString, "vaccineName": vaccineName]
        
        // 日付コンポーネントの作成（当日の朝9時に通知）
        var reminderDate = date
        reminderDate = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: reminderDate) ?? date
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        // リクエストの作成と登録
        let request = UNNotificationRequest(
            identifier: "vaccine-\(petId.uuidString)-\(vaccineName)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("ワクチンリマインダー設定エラー: \(error)")
            }
        }
    }
    
    // 特定ペットに関する全ての通知をキャンセル
    func cancelAllNotificationsForPet(petId: UUID) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let petRequests = requests.filter { request in
                if let petIdString = request.content.userInfo["petId"] as? String {
                    return petIdString == petId.uuidString
                }
                return false
            }
            
            let identifiers = petRequests.map { $0.identifier }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }
    
    // 特定タイプのケア通知をキャンセル
    func cancelCareNotifications(petId: UUID, careType: String) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let careRequests = requests.filter { request in
                if let petIdString = request.content.userInfo["petId"] as? String,
                   let requestCareType = request.content.userInfo["careType"] as? String {
                    return petIdString == petId.uuidString && requestCareType == careType
                }
                return false
            }
            
            let identifiers = careRequests.map { $0.identifier }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }
    
    // 全ての通知をキャンセル
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    // すべての給餌通知をキャンセル
    func cancelAllFeedingNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let feedingRequests = requests.filter { request in
                return request.content.categoryIdentifier == Constants.Notification.feedingReminderCategory
            }
            
            let identifiers = feedingRequests.map { $0.identifier }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }

    // 給餌時間リマインダーを複数設定
    func scheduleFeedingReminders(petId: UUID, petName: String, times: [Date]) {
        // 既存の給餌リマインダーをキャンセル
        cancelFeedingNotificationsForPet(petId: petId)
        
        // 新しいリマインダーを設定
        for time in times {
            scheduleFeedingReminder(petId: petId, petName: petName, time: time)
        }
    }

    // 特定ペットの給餌通知をキャンセル
    func cancelFeedingNotificationsForPet(petId: UUID) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let petFeedingRequests = requests.filter { request in
                if let requestPetId = request.content.userInfo["petId"] as? String,
                   request.content.categoryIdentifier == Constants.Notification.feedingReminderCategory {
                    return requestPetId == petId.uuidString
                }
                return false
            }
            
            let identifiers = petFeedingRequests.map { $0.identifier }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }
}
