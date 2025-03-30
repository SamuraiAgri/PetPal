// PetPal/Models/UserProfileModel.swift
import Foundation
import CoreData
import CloudKit

struct UserProfileModel: Identifiable, Equatable {
    var id: UUID
    var name: String
    var avatarImageData: Data?
    var iCloudID: String
    var colorHex: String // ユーザーを識別するための色 (散歩ログなどの表示に使用)
    var isCurrentUser: Bool
    var createdAt: Date
    var updatedAt: Date
    var cloudKitRecordID: String?
    
    // Equatableプロトコル準拠
    static func == (lhs: UserProfileModel, rhs: UserProfileModel) -> Bool {
        return lhs.id == rhs.id
    }
    
    // CoreDataエンティティからモデルを初期化
    init(entity: UserProfile) {
        self.id = entity.id ?? UUID()
        self.name = entity.name ?? ""
        self.avatarImageData = entity.avatarImageData
        self.iCloudID = entity.iCloudID ?? ""
        self.colorHex = entity.colorHex ?? "#3CB371" // デフォルト色：ミディアムシーグリーン
        self.isCurrentUser = entity.isCurrentUser
        self.createdAt = entity.createdAt ?? Date()
        self.updatedAt = entity.updatedAt ?? Date()
        self.cloudKitRecordID = entity.cloudKitRecordID
    }
    
    // 新規ユーザー作成用の初期化
    init(name: String, iCloudID: String, avatarImageData: Data? = nil, colorHex: String = "#3CB371", isCurrentUser: Bool = false) {
        self.id = UUID()
        self.name = name
        self.avatarImageData = avatarImageData
        self.iCloudID = iCloudID
        self.colorHex = colorHex
        self.isCurrentUser = isCurrentUser
        self.createdAt = Date()
        self.updatedAt = Date()
        self.cloudKitRecordID = nil
    }
    
    // CoreDataエンティティを更新
    func updateEntity(entity: UserProfile) {
        entity.id = self.id
        entity.name = self.name
        entity.avatarImageData = self.avatarImageData
        entity.iCloudID = self.iCloudID
        entity.colorHex = self.colorHex
        entity.isCurrentUser = self.isCurrentUser
        entity.updatedAt = Date()
        entity.cloudKitRecordID = self.cloudKitRecordID
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
                recordID = CKRecord.ID(recordName: id.uuidString, zoneID: CKRecordZone.ID(zoneName: Constants.CloudKit.userZoneName, ownerName: CKCurrentUserDefaultName))
            }
        } else {
            recordID = CKRecord.ID(recordName: id.uuidString, zoneID: CKRecordZone.ID(zoneName: Constants.CloudKit.userZoneName, ownerName: CKCurrentUserDefaultName))
        }
        
        let record = CKRecord(recordType: "UserProfile", recordID: recordID)
        record["id"] = id.uuidString as CKRecordValue
        record["name"] = name as CKRecordValue
        record["iCloudID"] = iCloudID as CKRecordValue
        record["colorHex"] = colorHex as CKRecordValue
        record["isCurrentUser"] = isCurrentUser as CKRecordValue
        record["createdAt"] = createdAt as CKRecordValue
        record["updatedAt"] = updatedAt as CKRecordValue
        
        if let avatarData = avatarImageData {
            let asset = CKAsset(fileURL: saveAvatarTemporarily(data: avatarData))
            record["avatarImageAsset"] = asset
        }
        
        return record
    }
    
    // アバター画像を一時ファイルとして保存しURLを返す（CloudKit用）
    private func saveAvatarTemporarily(data: Data) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(UUID().uuidString)
        
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("Error saving avatar image temporarily: \(error)")
            // エラー時は空のファイルを作成して返す
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
            return fileURL
        }
    }
    
    // 色をUIColorに変換
    func color() -> UIColor {
        return UIColor(hex: colorHex) ?? UIColor.systemGreen
    }
}

// UIColorをHex文字列から初期化する拡張
extension UIColor {
    convenience init?(hex: String) {
        let r, g, b, a: CGFloat
        
        if hex.hasPrefix("#") {
            let start = hex.index(hex.startIndex, offsetBy: 1)
            let hexColor = String(hex[start...])
            
            if hexColor.count == 6 {
                let scanner = Scanner(string: hexColor)
                var hexNumber: UInt64 = 0
                
                if scanner.scanHexInt64(&hexNumber) {
                    r = CGFloat((hexNumber & 0xff0000) >> 16) / 255
                    g = CGFloat((hexNumber & 0x00ff00) >> 8) / 255
                    b = CGFloat(hexNumber & 0x0000ff) / 255
                    a = 1.0
                    
                    self.init(red: r, green: g, blue: b, alpha: a)
                    return
                }
            }
        }
        
        return nil
    }
    
    // UIColorをHex文字列に変換
    func toHex() -> String? {
        guard let components = self.cgColor.components, components.count >= 3 else {
            return nil
        }
        
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        
        return String(format: "#%02lX%02lX%02lX", lround(r * 255), lround(g * 255), lround(b * 255))
    }
}
