// PetPal/Models/HealthModel.swift
import Foundation
import CoreData
import CloudKit

struct HealthLogModel: Identifiable {
    var id: UUID
    var date: Date
    var condition: String
    var symptoms: String
    var medication: String
    var notes: String
    var cloudKitRecordID: String?
    var petId: UUID?
    
    // CoreDataエンティティからモデルを初期化
    init(entity: HealthLog) {
        self.id = entity.id ?? UUID()
        self.date = entity.date ?? Date()
        self.condition = entity.condition ?? ""
        self.symptoms = entity.symptoms ?? ""
        self.medication = entity.medication ?? ""
        self.notes = entity.notes ?? ""
        self.cloudKitRecordID = entity.cloudKitRecordID
        self.petId = entity.pet?.id
    }
    
    // 新規作成用の初期化
    init(date: Date = Date(), condition: String = "良好", symptoms: String = "", medication: String = "", notes: String = "", petId: UUID? = nil) {
        self.id = UUID()
        self.date = date
        self.condition = condition
        self.symptoms = symptoms
        self.medication = medication
        self.notes = notes
        self.cloudKitRecordID = nil
        self.petId = petId
    }
    
    // CloudKitレコードへの変換
    func toCloudKitRecord() -> CKRecord {
        let recordID: CKRecord.ID
        
        if let existingRecordID = cloudKitRecordID, let components = existingRecordID.components(separatedBy: ":"), components.count == 2 {
            recordID = CKRecord.ID(recordName: components[1], zoneID: CKRecordZone.ID(zoneName: components[0], ownerName: CKCurrentUserDefaultName))
        } else {
            recordID = CKRecord.ID(recordName: id.uuidString, zoneID: CKRecordZone.ID(zoneName: Constants.CloudKit.petZoneName, ownerName: CKCurrentUserDefaultName))
        }
        
        let record = CKRecord(recordType: "HealthLog", recordID: recordID)
        record["id"] = id.uuidString as CKRecordValue
        record["date"] = date as CKRecordValue
        record["condition"] = condition as CKRecordValue
        record["symptoms"] = symptoms as CKRecordValue
        record["medication"] = medication as CKRecordValue
        record["notes"] = notes as CKRecordValue
        
        if let petId = petId {
            record["petId"] = petId.uuidString as CKRecordValue
        }
        
        return record
    }
}

struct VaccinationModel: Identifiable {
    var id: UUID
    var name: String
    var date: Date
    var expiryDate: Date?
    var reminderDate: Date?
    var clinicName: String
    var vetName: String
    var notes: String
    var cloudKitRecordID: String?
    var petId: UUID?
    
    // CoreDataエンティティからモデルを初期化
    init(entity: Vaccination) {
        self.id = entity.id ?? UUID()
        self.name = entity.name ?? ""
        self.date = entity.date ?? Date()
        self.expiryDate = entity.expiryDate
        self.reminderDate = entity.reminderDate
        // Dateを文字列として扱う
        self.clinicName = entity.clinicName?.description ?? ""
        self.vetName = entity.vetName?.description ?? ""
        self.notes = entity.notes ?? ""
        self.cloudKitRecordID = entity.cloudKitRecordID
        self.petId = entity.pet?.id
    }
    
    // 新規作成用の初期化
    init(name: String, date: Date = Date(), expiryDate: Date? = nil, reminderDate: Date? = nil, clinicName: String = "", vetName: String = "", notes: String = "", petId: UUID? = nil) {
        self.id = UUID()
        self.name = name
        self.date = date
        self.expiryDate = expiryDate
        self.reminderDate = reminderDate
        self.clinicName = clinicName
        self.vetName = vetName
        self.notes = notes
        self.cloudKitRecordID = nil
        self.petId = petId
    }
    
    // CloudKitレコードへの変換
    func toCloudKitRecord() -> CKRecord {
        let recordID: CKRecord.ID
        
        if let existingRecordID = cloudKitRecordID, let components = existingRecordID.components(separatedBy: ":"), components.count == 2 {
            recordID = CKRecord.ID(recordName: components[1], zoneID: CKRecordZone.ID(zoneName: components[0], ownerName: CKCurrentUserDefaultName))
        } else {
            recordID = CKRecord.ID(recordName: id.uuidString, zoneID: CKRecordZone.ID(zoneName: Constants.CloudKit.petZoneName, ownerName: CKCurrentUserDefaultName))
        }
        
        let record = CKRecord(recordType: "Vaccination", recordID: recordID)
        record["id"] = id.uuidString as CKRecordValue
        record["name"] = name as CKRecordValue
        record["date"] = date as CKRecordValue
        
        if let expiryDate = expiryDate {
            record["expiryDate"] = expiryDate as CKRecordValue
        }
        
        if let reminderDate = reminderDate {
            record["reminderDate"] = reminderDate as CKRecordValue
        }
        
        record["clinicName"] = clinicName as CKRecordValue
        record["vetName"] = vetName as CKRecordValue
        record["notes"] = notes as CKRecordValue
        
        if let petId = petId {
            record["petId"] = petId.uuidString as CKRecordValue
        }
        
        return record
    }
}

struct WeightLogModel: Identifiable {
    var id: UUID
    var date: Date
    var weight: Double
    var unit: String
    var notes: String
    var cloudKitRecordID: String?
    var petId: UUID?
    
    // CoreDataエンティティからモデルを初期化
    init(entity: WeightLog) {
        self.id = entity.id ?? UUID()
        self.date = entity.date ?? Date()
        self.weight = entity.weight
        self.unit = entity.unit ?? "kg"
        self.notes = entity.notes ?? ""
        self.cloudKitRecordID = entity.cloudKitRecordID
        self.petId = entity.pet?.id
    }
    
    // 新規作成用の初期化
    init(date: Date = Date(), weight: Double, unit: String = "kg", notes: String = "", petId: UUID? = nil) {
        self.id = UUID()
        self.date = date
        self.weight = weight
        self.unit = unit
        self.notes = notes
        self.cloudKitRecordID = nil
        self.petId = petId
    }
    
    // CloudKitレコードへの変換
    func toCloudKitRecord() -> CKRecord {
        let recordID: CKRecord.ID
        
        if let existingRecordID = cloudKitRecordID, let components = existingRecordID.components(separatedBy: ":"), components.count == 2 {
            recordID = CKRecord.ID(recordName: components[1], zoneID: CKRecordZone.ID(zoneName: components[0], ownerName: CKCurrentUserDefaultName))
        } else {
            recordID = CKRecord.ID(recordName: id.uuidString, zoneID: CKRecordZone.ID(zoneName: Constants.CloudKit.petZoneName, ownerName: CKCurrentUserDefaultName))
        }
        
        let record = CKRecord(recordType: "WeightLog", recordID: recordID)
        record["id"] = id.uuidString as CKRecordValue
        record["date"] = date as CKRecordValue
        record["weight"] = weight as CKRecordValue
        record["unit"] = unit as CKRecordValue
        record["notes"] = notes as CKRecordValue
        
        if let petId = petId {
            record["petId"] = petId.uuidString as CKRecordValue
        }
        
        return record
    }
}
