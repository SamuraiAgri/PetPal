import Foundation
import CloudKit
import Combine

class CloudKitManager {
    private let container: CKContainer
    private let database: CKDatabase
    
    init() {
        container = CKContainer(identifier: Constants.CloudKit.containerIdentifier)
        database = container.privateCloudDatabase
        
        // カスタムゾーンの作成（初回のみ）
        createCustomZoneIfNeeded()
    }
    
    // カスタムゾーンの作成
    private func createCustomZoneIfNeeded() {
        let zoneID = CKRecordZone.ID(zoneName: Constants.CloudKit.petZoneName, ownerName: CKCurrentUserDefaultName)
        let zone = CKRecordZone(zoneID: zoneID)
        
        let operation = CKModifyRecordZonesOperation(recordZonesToSave: [zone], recordZoneIDsToDelete: nil)
        operation.qualityOfService = .userInitiated
        
        operation.modifyRecordZonesCompletionBlock = { _, _, error in
            if let error = error {
                print("Error creating custom zone: \(error)")
            } else {
                print("Custom zone created or already exists")
            }
        }
        
        database.add(operation)
    }
    
    // MARK: - Pet関連操作
    
    // ペット保存
    func savePet(_ pet: PetModel, completion: @escaping (Result<CKRecord.ID, Error>) -> Void) {
        let record = pet.toCloudKitRecord()
        
        database.save(record) { record, error in
            if let error = error {
                completion(.failure(error))
            } else if let record = record {
                completion(.success(record.recordID))
            } else {
                completion(.failure(NSError(domain: "CloudKitManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "レコードの保存に失敗しました"])))
            }
        }
    }
    
    // ペット取得
    func fetchPet(id: UUID, completion: @escaping (Result<PetModel?, Error>) -> Void) {
        let predicate = NSPredicate(format: "id == %@", id.uuidString)
        let query = CKQuery(recordType: "Pet", predicate: predicate)
        
        database.perform(query, inZoneWith: CKRecordZone.ID(zoneName: Constants.CloudKit.petZoneName, ownerName: CKCurrentUserDefaultName)) { records, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let record = records?.first else {
                // レコードが見つからなかった場合
                completion(.success(nil))
                return
            }
            
            self.petModelFromRecord(record) { result in
                switch result {
                case .success(let petModel):
                    completion(.success(petModel))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    // 全ペット取得
    func fetchAllPets(completion: @escaping (Result<[PetModel], Error>) -> Void) {
        let query = CKQuery(recordType: "Pet", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        database.perform(query, inZoneWith: CKRecordZone.ID(zoneName: Constants.CloudKit.petZoneName, ownerName: CKCurrentUserDefaultName)) { records, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let records = records else {
                completion(.success([]))
                return
            }
            
            let group = DispatchGroup()
            var petModels: [PetModel] = []
            var fetchErrors: [Error] = []
            
            for record in records {
                group.enter()
                self.petModelFromRecord(record) { result in
                    switch result {
                    case .success(let petModel):
                        if let model = petModel {
                            petModels.append(model)
                        }
                    case .failure(let error):
                        fetchErrors.append(error)
                    }
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                if !fetchErrors.isEmpty {
                    completion(.failure(fetchErrors.first!))
                } else {
                    completion(.success(petModels))
                }
            }
        }
    }
    
    // CKRecordからPetModelへの変換
    private func petModelFromRecord(_ record: CKRecord, completion: @escaping (Result<PetModel?, Error>) -> Void) {
        guard let idString = record["id"] as? String,
              let id = UUID(uuidString: idString),
              let name = record["name"] as? String,
              let species = record["species"] as? String,
              let birthDate = record["birthDate"] as? Date else {
            completion(.failure(NSError(domain: "CloudKitManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "レコードの変換に失敗しました"])))
            return
        }
        
        let breed = record["breed"] as? String ?? ""
        let gender = record["gender"] as? String ?? ""
        let notes = record["notes"] as? String ?? ""
        let createdAt = record["createdAt"] as? Date ?? Date()
        let updatedAt = record["updatedAt"] as? Date ?? Date()
        let isActive = record["isActive"] as? Bool ?? true
        
        // アイコン画像の処理
        var iconImageData: Data? = nil
        if let iconAsset = record["iconImageAsset"] as? CKAsset, let url = iconAsset.fileURL {
            do {
                iconImageData = try Data(contentsOf: url)
            } catch {
                print("Error loading icon image data: \(error)")
            }
        }
        
        // CloudKitレコードIDを文字列として保存
        let cloudKitRecordID = "\(Constants.CloudKit.petZoneName):\(record.recordID.recordName)"
        
        var petModel = PetModel(
            name: name,
            species: species,
            breed: breed,
            birthDate: birthDate,
            gender: gender,
            iconImageData: iconImageData,
            notes: notes
        )
        
        petModel.id = id
        petModel.createdAt = createdAt
        petModel.updatedAt = updatedAt
        petModel.cloudKitRecordID = cloudKitRecordID
        petModel.isActive = isActive
        
        completion(.success(petModel))
    }
    
    // MARK: - CareLog関連操作
    
    // 以下に CareLog, FeedingLog, HealthLog などの同様の操作を実装
    // (紙面の都合で省略しますが、実際には同様のパターンで実装します)
}
