import SwiftUI

struct Constants {
    // MARK: - App全般
    struct App {
        static let name = "PetPal"
        static let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        static let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    // MARK: - レイアウト
    struct Layout {
        static let cornerRadius: CGFloat = 12.0
        static let smallCornerRadius: CGFloat = 8.0
        static let standardPadding: CGFloat = 16.0
        static let smallPadding: CGFloat = 8.0
        static let largePadding: CGFloat = 24.0
        static let avatarSize: CGFloat = 50.0
        static let largeAvatarSize: CGFloat = 120.0
        static let iconSize: CGFloat = 24.0
    }
    
    // MARK: - アニメーション
    struct Animation {
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let quick = SwiftUI.Animation.easeOut(duration: 0.2)
    }
    
    // MARK: - ケアタイプ
    struct CareTypes {
        static let walk = "散歩"
        static let feeding = "給餌"
        static let grooming = "グルーミング"
        static let medication = "投薬"
        static let healthCheck = "健康チェック"
        
        static let all = [walk, feeding, grooming, medication, healthCheck]
    }
    
    // MARK: - PetSpecies
    struct PetSpecies {
        static let dog = "犬"
        static let cat = "猫"
        static let bird = "鳥"
        static let smallAnimal = "小動物"
        static let other = "その他"
        
        static let all = [dog, cat, bird, smallAnimal, other]
    }
    
    // MARK: - CloudKit
    struct CloudKit {
        static let containerIdentifier = "iCloud.com.samuraiagri.PetPal"
        static let petZoneName = "PetZone"
        static let userZoneName = "UserZone"
        static let careZoneName = "CareZone"
        static let syncInterval: TimeInterval = 60 // 1分間隔で同期
        
        // 共有関連
        static let maxShareParticipants = 10 // 最大共有人数
        static let shareInvitationSubject = "ペットのケア情報を共有します"
        static let shareInvitationBody = "PetPalアプリでペットの情報を共有するよう招待されました。リンクをタップして承認してください。"
    }
    
    // MARK: - 通知
    struct Notification {
        static let feedingReminderCategory = "FEEDING_REMINDER"
        static let careReminderCategory = "CARE_REMINDER"
        static let vaccinationReminderCategory = "VACCINATION_REMINDER"
        static let sharedPetUpdateCategory = "SHARED_PET_UPDATE"
        static let careAssignmentCategory = "CARE_ASSIGNMENT"
    }
    
    // MARK: - ケアスケジュール
    struct CareSchedule {
        static let maxDaysInAdvance = 30 // 何日先まで予定を設定できるか
        static let reminderTimeBeforeCare = 30 // ケア予定の何分前に通知するか
    }
    
    // MARK: - ケア記録ラベル
    struct CareLabels {
        static let doneByCurrentUser = "あなたが実施"
        static let doneByOthers = "が実施"
        static let scheduledLabel = "予定:"
        static let assignedToYou = "あなたの担当"
        static let assignedToOthers = "の担当"
        static let unassigned = "担当者未設定"
    }
}
