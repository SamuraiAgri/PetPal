// PetPal/Models/CareLogModel.swift
import Foundation
import CoreData
import CloudKit

struct CareLogModel: Identifiable {
    var id: UUID
    var type: String
    var timestamp: Date
    var notes: String
    var performedBy: String  // 下位互換性のために残す
    var cloudKitRecordID: String?
    var isCompleted: Bool
    var petId: UUID?
    
    // 新規追加フィールド
    var userProfileID: UUID?      // 実施したユーザーのID
    var userProfile: UserProfileModel?  // 実施したユーザーの情報
    var assignedUserProfileID: UUID?  // 担当予定だったユーザーのID（スケジュール用）
    var assignedUserProfile: UserProfileModel?  // 担当予定だったユーザーの情報
    var scheduledDate: Date?      // 予定日時（スケジュール用）
    var isScheduled: Bool = false  // 予定か実績か
    
    // CoreDataエンティティからモデルを初期化
    init(entity: CareLog) {
        self.id = entity.id ?? UUID()
        self.type = entity.type ?? ""
        self.timestamp = entity.timestamp ?? Date()
        self.notes = entity.notes ?? ""
        self.performedBy = entity.performedBy ?? ""
        self.cloudKitRecordID = entity.cloudKitRecordID
        self.isCompleted = entity.isCompleted
        self.petId = entity.pet?.id
        
        // 新規フィールド
        self.userProfileID = entity.userProfileID
        self.assignedUserProfileID = entity.assignedUserProfileID
        self.scheduledDate = entity.scheduledDate
        self.isScheduled = entity.isScheduled
    }
    
    // 新規作成用の初期化
    init(type: String, notes: String = "", performedBy: String = "", petId: UUID? = nil, userProfileID: UUID? = nil, isScheduled: Bool = false, scheduledDate: Date? = nil, assignedUserProfileID: UUID? = nil) {
        self.id = UUID()
        self.type = type
        self.timestamp = Date()
        self.notes = notes
        self.performedBy = performedBy
        self.cloudKitRecordID = nil
        self.isCompleted = !isScheduled // スケジュールの場合は未完了
        self.petId = petId
        self.userProfileID = userProfileID
        self.isScheduled = isScheduled
        self.scheduledDate = scheduledDate
        self.assignedUserProfileID = assignedUserProfileID
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
        
        let record = CKRecord(recordType: "CareLog", recordID: recordID)
        record["id"] = id.uuidString as CKRecordValue
        record["type"] = type as CKRecordValue
        record["timestamp"] = timestamp as CKRecordValue
        record["notes"] = notes as CKRecordValue
        record["performedBy"] = performedBy as CKRecordValue
        record["isCompleted"] = isCompleted as CKRecordValue
        
        // 新規フィールド
        if let userProfileID = userProfileID {
            record["userProfileID"] = userProfileID.uuidString as CKRecordValue
        }
        
        if let assignedUserProfileID = assignedUserProfileID {
            record["assignedUserProfileID"] = assignedUserProfileID.uuidString as CKRecordValue
        }
        
        if let scheduledDate = scheduledDate {
            record["scheduledDate"] = scheduledDate as CKRecordValue
        }
        
        record["isScheduled"] = isScheduled as CKRecordValue
        
        if let petId = petId {
            record["petId"] = petId.uuidString as CKRecordValue
        }
        
        return record
    }
    
    // 表示用の担当者ラベルを生成
    func getPerformerLabel(currentUserID: UUID?) -> String {
        if isScheduled {
            // 予定の場合
            if let assignedID = assignedUserProfileID, let currentID = currentUserID, assignedID == currentID {
                return Constants.CareLabels.assignedToYou
            } else if let profile = assignedUserProfile {
                return "\(profile.name)\(Constants.CareLabels.assignedToOthers)"
            } else {
                return Constants.CareLabels.unassigned
            }
        } else {
            // 実績の場合
            if let userID = userProfileID, let currentID = currentUserID, userID == currentID {
                return Constants.CareLabels.doneByCurrentUser
            } else if let profile = userProfile {
                return "\(profile.name)\(Constants.CareLabels.doneByOthers)"
            } else {
                return performedBy // 後方互換性
            }
        }
    }
}
