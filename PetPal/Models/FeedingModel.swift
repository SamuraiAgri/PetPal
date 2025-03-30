// PetPal/Models/FeedingModel.swift
import Foundation
import CoreData
import CloudKit

struct FeedingLogModel: Identifiable {
    var id: UUID
    var foodType: String
    var amount: Double
    var unit: String
    var timestamp: Date
    var notes: String
    var performedBy: String
    var cloudKitRecordID: String?
    var petId: UUID?
    
    // CoreDataエンティティからモデルを初期化
    init(entity: FeedingLog) {
        self.id = entity.id ?? UUID()
        self.foodType = entity.foodType ?? ""
        self.amount = entity.amount
        self.unit = entity.unit ?? "g"
        self.timestamp = entity.timestamp ?? Date()
        self.notes = entity.notes ?? ""
        self.performedBy = entity.performedBy ?? ""
        self.cloudKitRecordID = entity.cloudKitRecordID
        self.petId = entity.pet?.firstObject.flatMap { ($0 as? Pet)?.id }
    }
    
    // 新規作成用の初期化
    init(foodType: String, amount: Double, unit: String = "g", notes: String = "", performedBy: String = "", petId: UUID? = nil) {
        self.id = UUID()
        self.foodType = foodType
        self.amount = amount
        self.unit = unit
        self.timestamp = Date()
        self.notes = notes
        self.performedBy = performedBy
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
            recordID = CKRecord.ID(recordName: id.uuidString, zoneID: CKRecordZone.ID(zoneName: Constants.CloudKit.petZoneName, ownerName: CKCurrentUserDefaultName))
        }
        
        let record = CKRecord(recordType: "FeedingLog", recordID: recordID)
        record["id"] = id.uuidString as CKRecordValue
        record["foodType"] = foodType as CKRecordValue
        record["amount"] = amount as CKRecordValue
        record["unit"] = unit as CKRecordValue
        record["timestamp"] = timestamp as CKRecordValue
        record["notes"] = notes as CKRecordValue
        record["performedBy"] = performedBy as CKRecordValue
        
        if let petId = petId {
            record["petId"] = petId.uuidString as CKRecordValue
        }
        
        return record
    }
}
