// PetPal/Models/CareLogModel.swift
import Foundation
import CoreData
import CloudKit

struct CareLogModel: Identifiable {
    var id: UUID
    var type: String
    var timestamp: Date
    var notes: String
    var performedBy: String
    var cloudKitRecordID: String?
    var isCompleted: Bool
    var petId: UUID?
    
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
    }
    
    // 新規作成用の初期化
    init(type: String, notes: String = "", performedBy: String = "", petId: UUID? = nil) {
        self.id = UUID()
        self.type = type
        self.timestamp = Date()
        self.notes = notes
        self.performedBy = performedBy
        self.cloudKitRecordID = nil
        self.isCompleted = true
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
            recordID = CKRecord.ID(recordName: id.uuidString, zoneID: CKRecordZone.ID(zoneName: Constants.CloudKit.petZoneName, ownerName: CKCurrentUserDefaultName))
        }
        
        let record = CKRecord(recordType: "CareLog", recordID: recordID)
        record["id"] = id.uuidString as CKRecordValue
        record["type"] = type as CKRecordValue
        record["timestamp"] = timestamp as CKRecordValue
        record["notes"] = notes as CKRecordValue
        record["performedBy"] = performedBy as CKRecordValue
        record["isCompleted"] = isCompleted as CKRecordValue
        
        if let petId = petId {
            record["petId"] = petId.uuidString as CKRecordValue
        }
        
        return record
    }
}
