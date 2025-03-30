// PetPal/Models/PetModel.swift
import Foundation
import CoreData
import CloudKit

struct PetModel: Identifiable, Equatable {
    var id: UUID
    var name: String
    var species: String
    var breed: String
    var birthDate: Date
    var gender: String
    var iconImageData: Data?
    var notes: String
    var createdAt: Date
    var updatedAt: Date
    var cloudKitRecordID: String?
    var isActive: Bool
    
    // Equatableプロトコル準拠
    static func == (lhs: PetModel, rhs: PetModel) -> Bool {
        return lhs.id == rhs.id
    }
    
    // CoreDataエンティティからモデルを初期化
    init(entity: Pet) {
        self.id = entity.id ?? UUID()
        self.name = entity.name ?? ""
        self.species = entity.species ?? ""
        self.breed = entity.breed ?? ""
        self.birthDate = entity.birthDate ?? Date()
        self.gender = entity.gender ?? ""
        self.iconImageData = entity.iconImageData
        self.notes = entity.notes ?? ""
        self.createdAt = entity.createdAt ?? Date()
        self.updatedAt = entity.updatedAt ?? Date()
        self.cloudKitRecordID = entity.cloudKitRecordID
        self.isActive = entity.isActive
    }
    
    // 新規ペット作成用の初期化
    init(name: String, species: String, breed: String = "", birthDate: Date, gender: String = "", iconImageData: Data? = nil, notes: String = "") {
        self.id = UUID()
        self.name = name
        self.species = species
        self.breed = breed
        self.birthDate = birthDate
        self.gender = gender
        self.iconImageData = iconImageData
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = Date()
        self.cloudKitRecordID = nil
        self.isActive = true
    }
    
    // CoreDataエンティティを更新
    func updateEntity(entity: Pet) {
        entity.id = self.id
        entity.name = self.name
        entity.species = self.species
        entity.breed = self.breed
        entity.birthDate = self.birthDate
        entity.gender = self.gender
        entity.iconImageData = self.iconImageData
        entity.notes = self.notes
        entity.updatedAt = Date()
        entity.cloudKitRecordID = self.cloudKitRecordID
        entity.isActive = self.isActive
    }
    
    // ペットの年齢を計算
    var age: String {
        return birthDate.ageString()
    }
    
    // CloudKitレコードへの変換
    func toCloudKitRecord() -> CKRecord {
        let recordID: CKRecord.ID
        
        if let existingRecordID = cloudKitRecordID {
            // 文字列分割の修正
            let components = existingRecordID.components(separatedBy: ":")
            if components.count == 2 {
                recordID = CKRecord.ID(recordName: components[1], zoneID: CKRecordZone.ID(zoneName: components[0], ownerName: CKCurrentUserDefaultName))
            } else {
                recordID = CKRecord.ID(recordName: id.uuidString, zoneID: CKRecordZone.ID(zoneName: Constants.CloudKit.petZoneName, ownerName: CKCurrentUserDefaultName))
            }
        } else {
            recordID = CKRecord.ID(recordName: id.uuidString, zoneID: CKRecordZone.ID(zoneName: Constants.CloudKit.petZoneName, ownerName: CKCurrentUserDefaultName))
        }
        
        let record = CKRecord(recordType: "Pet", recordID: recordID)
        record["id"] = id.uuidString as CKRecordValue
        record["name"] = name as CKRecordValue
        record["species"] = species as CKRecordValue
        record["breed"] = breed as CKRecordValue
        record["birthDate"] = birthDate as CKRecordValue
        record["gender"] = gender as CKRecordValue
        
        if let iconData = iconImageData {
            let asset = CKAsset(fileURL: saveIconTemporarily(data: iconData))
            record["iconImageAsset"] = asset
        }
        
        record["notes"] = notes as CKRecordValue
        record["createdAt"] = createdAt as CKRecordValue
        record["updatedAt"] = updatedAt as CKRecordValue
        record["isActive"] = isActive as CKRecordValue
        
        return record
    }
    
    // アイコン画像を一時ファイルとして保存しURLを返す（CloudKit用）
    private func saveIconTemporarily(data: Data) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(UUID().uuidString)
        
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("Error saving icon image temporarily: \(error)")
            // エラー時は空のファイルを作成して返す
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
            return fileURL
        }
    }
}
