// PetPal/Models/CareScheduleModel.swift
import Foundation
import CoreData
import CloudKit

struct CareScheduleModel: Identifiable {
    var id: UUID
    var type: String
    var assignedUserProfileID: UUID?
    var assignedUserProfile: UserProfileModel?
    var scheduledDate: Date
    var notes: String
    var isCompleted: Bool
    var completedBy: UUID?
    var completedDate: Date?
    var createdBy: UUID?
    var createdByProfile: UserProfileModel?
    var createdAt: Date
    var updatedAt: Date
    var cloudKitRecordID: String?
    var petId: UUID?
    
    // CoreDataエンティティからモデルを初期化
    init(entity: CareSchedule) {
        self.id = entity.id ?? UUID()
        self.type = entity.type ?? ""
        self.assignedUserProfileID = entity.assignedUserProfileID
        self.scheduledDate = entity.scheduledDate ?? Date()
        self.notes = entity.notes ?? ""
        self.isCompleted = entity.isCompleted
        self.completedBy = entity.completedBy
        self.completedDate = entity.completedDate
        self.createdBy = entity.createdBy
        self.createdAt = entity.createdAt ?? Date()
        self.updatedAt = entity.updatedAt ?? Date()
        self.cloudKitRecordID = entity.cloudKitRecordID
        self.petId = entity.pet?.id
    }
    
    // 新規作成用の初期化
    init(type: String, assignedUserProfileID: UUID? = nil, scheduledDate: Date, notes: String = "", createdBy: UUID? = nil, petId: UUID? = nil) {
        self.id = UUID()
        self.type = type
        self.assignedUserProfileID = assignedUserProfileID
        self.scheduledDate = scheduledDate
        self.notes = notes
        self.isCompleted = false
        self.completedBy = nil
        self.completedDate = nil
        self.createdBy = createdBy
        self.createdAt = Date()
        self.updatedAt = Date()
        self.cloudKitRecordID = nil
        self.petId = petId
    }
    
    // CloudKitレコードへの変換
    func toCloudKitRecord() -> CKRecord {
        let recordID: CKRecord.ID
        
        if let existingRecordID = cloudKitRecordID, let components = existingRecordID.components(separatedBy: ":").first, components.count == 2 {
            let zoneString = components
            let recordString = existingRecordID.components(separatedBy: ":").last ?? id.uuidString
            recordID = CKRecord.ID(recordName: recordString, zoneID: CKRecordZone.ID(zoneName: zoneString, ownerName: CKCurrentUserDefaultName))
        } else {
            recordID = CKRecord.ID(recordName: id.uuidString, zoneID: CKRecordZone.ID(zoneName: Constants.CloudKit.careZoneName, ownerName: CKCurrentUserDefaultName))
        }
        
        let record = CKRecord(recordType: "CareSchedule", recordID: recordID)
        record["id"] = id.uuidString as CKRecordValue
        record["type"] = type as CKRecordValue
        
        if let assignedUserProfileID = assignedUserProfileID {
            record["assignedUserProfileID"] = assignedUserProfileID.uuidString as CKRecordValue
        }
        
        record["scheduledDate"] = scheduledDate as CKRecordValue
        record["notes"] = notes as CKRecordValue
        record["isCompleted"] = isCompleted as CKRecordValue
        
        if let completedBy = completedBy {
            record["completedBy"] = completedBy.uuidString as CKRecordValue
        }
        
        if let completedDate = completedDate {
            record["completedDate"] = completedDate as CKRecordValue
        }
        
        if let createdBy = createdBy {
            record["createdBy"] = createdBy.uuidString as CKRecordValue
        }
        
        record["createdAt"] = createdAt as CKRecordValue
        record["updatedAt"] = updatedAt as CKRecordValue
        
        if let petId = petId {
            record["petId"] = petId.uuidString as CKRecordValue
        }
        
        return record
    }
    
    // ケアスケジュールを完了としてマーク
    mutating func markAsCompleted(byUserID: UUID) {
        self.isCompleted = true
        self.completedBy = byUserID
        self.completedDate = Date()
        self.updatedAt = Date()
    }
    
    // スケジュールが今日のものかチェック
    var isToday: Bool {
        Calendar.current.isDateInToday(scheduledDate)
    }
    
    // スケジュールが将来のものかチェック
    var isFuture: Bool {
        scheduledDate > Date()
    }
    
    // スケジュールが過去のものかチェック
    var isPast: Bool {
        !isToday && scheduledDate < Date()
    }
    
    // スケジュールの残り時間を計算（分単位）
    var minutesRemaining: Int? {
        guard !isCompleted && !isPast else { return nil }
        let now = Date()
        return Calendar.current.dateComponents([.minute], from: now, to: scheduledDate).minute
    }
    
    // 表示用の担当者ラベルを生成
    func getAssigneeLabel(currentUserID: UUID?) -> String {
        if let assignedID = assignedUserProfileID, let currentID = currentUserID, assignedID == currentID {
            return Constants.CareLabels.assignedToYou
        } else if let profile = assignedUserProfile {
            return "\(profile.name)\(Constants.CareLabels.assignedToOthers)"
        } else {
            return Constants.CareLabels.unassigned
        }
    }
    
    // ステータスに基づいた表示色を取得
    func getStatusColor() -> Color {
        if isCompleted {
            return .successApp
        } else if isPast {
            return .errorApp
        } else if isToday {
            return .warningApp
        } else {
            return .infoApp
        }
    }
}
