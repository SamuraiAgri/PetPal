// PetPal/Common/Utilities/CloudKitManager.swift
import Foundation
import CloudKit
import Combine
import UIKit

class CloudKitManager {
    let container: CKContainer
    let privateDatabase: CKDatabase
    let sharedDatabase: CKDatabase
    
    init() {
        container = CKContainer(identifier: Constants.CloudKit.containerIdentifier)
        privateDatabase = container.privateCloudDatabase
        sharedDatabase = container.sharedCloudDatabase
        
        // カスタムゾーンの作成（初回のみ）
        createCustomZoneIfNeeded()
    }
    
    // カスタムゾーンの作成
    private func createCustomZoneIfNeeded() {
        // ペット用ゾーン
        let petZoneID = CKRecordZone.ID(zoneName: Constants.CloudKit.petZoneName, ownerName: CKCurrentUserDefaultName)
        let petZone = CKRecordZone(zoneID: petZoneID)
        
        // ユーザー用ゾーン
        let userZoneID = CKRecordZone.ID(zoneName: Constants.CloudKit.userZoneName, ownerName: CKCurrentUserDefaultName)
        let userZone = CKRecordZone(zoneID: userZoneID)
        
        let operation = CKModifyRecordZonesOperation(recordZonesToSave: [petZone, userZone], recordZoneIDsToDelete: nil)
        operation.qualityOfService = .userInitiated
        
        operation.modifyRecordZonesResultBlock = { result in
            switch result {
            case .success:
                print("Custom zones created or already exist")
            case .failure(let error):
                print("Error creating custom zones: \(error)")
            }
        }
        
        privateDatabase.add(operation)
    }
    
    // MARK: - 現在のユーザー情報関連
    
    // 現在のiCloudユーザーIDを取得
    func fetchCurrentUserID(completion: @escaping (Result<String, Error>) -> Void) {
        container.fetchUserRecordID { recordID, error in
            if let error = error {
                completion(.failure(error))
            } else if let recordID = recordID {
                completion(.success(recordID.recordName))
            } else {
                completion(.failure(NSError(domain: "CloudKitManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Unable to fetch user record ID"])))
            }
        }
    }
    
    // MARK: - ユーザープロファイル関連操作
    
    // ユーザープロファイル保存
    func saveUserProfile(_ profile: UserProfileModel, completion: @escaping (Result<CKRecord.ID, Error>) -> Void) {
        let record = profile.toCloudKitRecord()
        
        privateDatabase.save(record) { (record: CKRecord?, error: Error?) in
            if let error = error {
                completion(.failure(error))
            } else if let record = record {
                completion(.success(record.recordID))
            } else {
                completion(.failure(NSError(domain: "CloudKitManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "プロファイルの保存に失敗しました"])))
            }
        }
    }
    
    // 全ユーザープロファイル取得
    func fetchAllUserProfiles(completion: @escaping (Result<[UserProfileModel], Error>) -> Void) {
        let query = CKQuery(recordType: "UserProfile", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        let zoneID = CKRecordZone.ID(zoneName: Constants.CloudKit.userZoneName, ownerName: CKCurrentUserDefaultName)
        
        // デフォルト値でCKQueryOperationを作成
        let queryOperation = CKQueryOperation(query: query)
        queryOperation.zoneID = zoneID
        
        var records: [CKRecord] = []
        
        // recordMatchedBlockの型を明示的に指定
        queryOperation.recordMatchedBlock = { (recordID: CKRecord.ID, result: Result<CKRecord, Error>) in
            switch result {
            case .success(let record):
                records.append(record)
            case .failure(let error):
                print("Error fetching record: \(error)")
            }
        }
        
        // queryResultBlockの型を明示的に指定
        queryOperation.queryResultBlock = { [weak self] (result: Result<CKQueryOperation.Cursor?, Error>) in
            guard let self = self else { return }
            
            switch result {
            case .success(_):
                if records.isEmpty {
                    DispatchQueue.main.async {
                        completion(.success([]))
                    }
                    return
                }
                
                let group = DispatchGroup()
                var userProfiles: [UserProfileModel] = []
                var fetchErrors: [Error] = []
                
                for record in records {
                    group.enter()
                    self.userProfileModelFromRecord(record) { result in
                        switch result {
                        case .success(let profileModel):
                            if let model = profileModel {
                                userProfiles.append(model)
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
                        completion(.success(userProfiles))
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
        
        privateDatabase.add(queryOperation)
        
        // 共有データベースからも取得
        let sharedQueryOperation = CKQueryOperation(query: query)
        
        sharedQueryOperation.recordMatchedBlock = { (recordID: CKRecord.ID, result: Result<CKRecord, Error>) in
            switch result {
            case .success(let record):
                records.append(record)
            case .failure(let error):
                print("Error fetching shared record: \(error)")
            }
        }
        
        sharedQueryOperation.queryResultBlock = { [weak self] (result: Result<CKQueryOperation.Cursor?, Error>) in
            guard let self = self else { return }
            
            switch result {
            case .success(_):
                if records.isEmpty {
                    return
                }
                
                let group = DispatchGroup()
                var sharedUserProfiles: [UserProfileModel] = []
                var fetchErrors: [Error] = []
                
                for record in records {
                    group.enter()
                    self.userProfileModelFromRecord(record) { result in
                        switch result {
                        case .success(let profileModel):
                            if let model = profileModel {
                                sharedUserProfiles.append(model)
                            }
                        case .failure(let error):
                            fetchErrors.append(error)
                        }
                        group.leave()
                    }
                }
                
                group.notify(queue: .main) {
                    if !fetchErrors.isEmpty {
                        print("Error fetching shared user profiles: \(fetchErrors.first!)")
                    } else {
                        // 重複を避けて統合
                        for sharedProfile in sharedUserProfiles {
                            if !userProfiles.contains(where: { $0.id == sharedProfile.id }) {
                                userProfiles.append(sharedProfile)
                            }
                        }
                        completion(.success(userProfiles))
                    }
                }
            case .failure(let error):
                print("Error fetching shared user profiles: \(error)")
            }
        }
        
        sharedDatabase.add(sharedQueryOperation)
    }
    
    // CKRecordからUserProfileModelへの変換
    private func userProfileModelFromRecord(_ record: CKRecord, completion: @escaping (Result<UserProfileModel?, Error>) -> Void) {
        guard let idString = record["id"] as? String,
              let id = UUID(uuidString: idString),
              let name = record["name"] as? String,
              let iCloudID = record["iCloudID"] as? String,
              let colorHex = record["colorHex"] as? String,
              let isCurrentUser = record["isCurrentUser"] as? Bool,
              let createdAt = record["createdAt"] as? Date,
              let updatedAt = record["updatedAt"] as? Date else {
            completion(.failure(NSError(domain: "CloudKitManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "レコードの変換に失敗しました"])))
            return
        }
        
        // アバター画像の処理
        var avatarImageData: Data? = nil
        if let avatarAsset = record["avatarImageAsset"] as? CKAsset, let url = avatarAsset.fileURL {
            do {
                avatarImageData = try Data(contentsOf: url)
            } catch {
                print("Error loading avatar image data: \(error)")
            }
        }
        
        // CloudKitレコードIDを文字列として保存
        let cloudKitRecordID = "\(Constants.CloudKit.userZoneName):\(record.recordID.recordName)"
        
        var userProfileModel = UserProfileModel(
            name: name,
            iCloudID: iCloudID,
            avatarImageData: avatarImageData,
            colorHex: colorHex,
            isCurrentUser: isCurrentUser
        )
        
        userProfileModel.id = id
        userProfileModel.createdAt = createdAt
        userProfileModel.updatedAt = updatedAt
        userProfileModel.cloudKitRecordID = cloudKitRecordID
        
        completion(.success(userProfileModel))
    }
    
    // MARK: - Pet関連操作
    
    // ペット保存
    func savePet(_ pet: PetModel, completion: @escaping (Result<CKRecord.ID, Error>) -> Void) {
        let record = pet.toCloudKitRecord()
        
        privateDatabase.save(record) { (record: CKRecord?, error: Error?) in
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
        
        // iOS 15.0以降の新しいAPI
        let zoneID = CKRecordZone.ID(zoneName: Constants.CloudKit.petZoneName, ownerName: CKCurrentUserDefaultName)
        
        // デフォルト値でCKQueryOperationを作成
        let queryOperation = CKQueryOperation(query: query)
        queryOperation.zoneID = zoneID
        
        var records: [CKRecord] = []
        
        // recordMatchedBlockの型を明示的に指定
        queryOperation.recordMatchedBlock = { (recordID: CKRecord.ID, result: Result<CKRecord, Error>) in
            switch result {
            case .success(let record):
                records.append(record)
            case .failure(let error):
                print("Error fetching record: \(error)")
            }
        }
        
        // queryResultBlockの型を明示的に指定
        queryOperation.queryResultBlock = { [weak self] (result: Result<CKQueryOperation.Cursor?, Error>) in
            guard let self = self else { return }
            
            switch result {
            case .success(_):
                if let record = records.first {
                    self.petModelFromRecord(record) { result in
                        DispatchQueue.main.async {
                            completion(result)
                        }
                    }
                } else {
                    // プライベートDBにない場合は共有DBを確認
                    self.fetchSharedPet(id: id, completion: completion)
                }
            case .failure(let error):
                // プライベートDBでエラーの場合も共有DBを確認
                print("Private database error: \(error). Checking shared database.")
                self.fetchSharedPet(id: id, completion: completion)
            }
        }
        
        privateDatabase.add(queryOperation)
    }
    
    // 共有データベースからペットを取得
    private func fetchSharedPet(id: UUID, completion: @escaping (Result<PetModel?, Error>) -> Void) {
        let predicate = NSPredicate(format: "id == %@", id.uuidString)
        let query = CKQuery(recordType: "Pet", predicate: predicate)
        
        let queryOperation = CKQueryOperation(query: query)
        
        var records: [CKRecord] = []
        
        // recordMatchedBlockの型を明示的に指定
        queryOperation.recordMatchedBlock = { (recordID: CKRecord.ID, result: Result<CKRecord, Error>) in
            switch result {
            case .success(let record):
                records.append(record)
            case .failure(let error):
                print("Error fetching shared record: \(error)")
            }
        }
        
        // queryResultBlockの型を明示的に指定
        queryOperation.queryResultBlock = { [weak self] (result: Result<CKQueryOperation.Cursor?, Error>) in
            guard let self = self else { return }
            
            switch result {
            case .success(_):
                if let record = records.first {
                    self.petModelFromRecord(record) { result in
                        DispatchQueue.main.async {
                            completion(result)
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.success(nil))
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
        
        sharedDatabase.add(queryOperation)
    }
    
    // 全ペット取得
    func fetchAllPets(completion: @escaping (Result<[PetModel], Error>) -> Void) {
        let query = CKQuery(recordType: "Pet", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        let zoneID = CKRecordZone.ID(zoneName: Constants.CloudKit.petZoneName, ownerName: CKCurrentUserDefaultName)
        
        // デフォルト値でCKQueryOperationを作成
        let queryOperation = CKQueryOperation(query: query)
        queryOperation.zoneID = zoneID
        
        var allRecords: [CKRecord] = []
        
        // recordMatchedBlockの型を明示的に指定
        queryOperation.recordMatchedBlock = { (recordID: CKRecord.ID, result: Result<CKRecord, Error>) in
            switch result {
            case .success(let record):
                allRecords.append(record)
            case .failure(let error):
                print("Error fetching record: \(error)")
            }
        }
        
        // queryResultBlockの型を明示的に指定
        queryOperation.queryResultBlock = { [weak self] (result: Result<CKQueryOperation.Cursor?, Error>) in
            guard let self = self else { return }
            
            switch result {
            case .success(_):
                // プライベートデータベースからの取得が完了したら、共有データベースもチェック
                self.fetchAllSharedPets { result in
                    switch result {
                    case .success(let sharedPets):
                        // プライベートデータベースから取得したレコードを処理
                        self.processPetRecords(allRecords) { privateResult in
                            switch privateResult {
                            case .success(let privatePets):
                                // 重複を避けて統合
                                var combinedPets = privatePets
                                for sharedPet in sharedPets {
                                    if !combinedPets.contains(where: { $0.id == sharedPet.id }) {
                                        combinedPets.append(sharedPet)
                                    }
                                }
                                DispatchQueue.main.async {
                                    completion(.success(combinedPets))
                                }
                            case .failure(let error):
                                DispatchQueue.main.async {
                                    completion(.failure(error))
                                }
                            }
                        }
                    case .failure(let error):
                        // 共有データベースからの取得に失敗した場合も、プライベートデータベースのデータだけでも返す
                        print("Error fetching shared pets: \(error)")
                        self.processPetRecords(allRecords) { privateResult in
                            DispatchQueue.main.async {
                                completion(privateResult)
                            }
                        }
                    }
                }
            case .failure(let error):
                // プライベートデータベースからの取得に失敗した場合は、共有データベースのみをチェック
                print("Error fetching private pets: \(error)")
                self.fetchAllSharedPets(completion: completion)
            }
        }
        
        privateDatabase.add(queryOperation)
    }
    
    // プライベートDBから取得したペットレコードの処理
    private func processPetRecords(_ records: [CKRecord], completion: @escaping (Result<[PetModel], Error>) -> Void) {
        if records.isEmpty {
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
    
    // 共有データベースから全ペットを取得
    private func fetchAllSharedPets(completion: @escaping (Result<[PetModel], Error>) -> Void) {
        let query = CKQuery(recordType: "Pet", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        let queryOperation = CKQueryOperation(query: query)
        
        var records: [CKRecord] = []
        
        // recordMatchedBlockの型を明示的に指定
        queryOperation.recordMatchedBlock = { (recordID: CKRecord.ID, result: Result<CKRecord, Error>) in
            switch result {
            case .success(let record):
                records.append(record)
            case .failure(let error):
                print("Error fetching shared record: \(error)")
            }
        }
        
        // queryResultBlockの型を明示的に指定
        queryOperation.queryResultBlock = { [weak self] (result: Result<CKQueryOperation.Cursor?, Error>) in
            guard let self = self else { return }
            
            switch result {
            case .success(_):
                self.processPetRecords(records, completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
        
        sharedDatabase.add(queryOperation)
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
        
        // 共有ステータスを確認
        let isShared = record.share != nil
        
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
        petModel.isShared = isShared
        
        // 共有情報の設定
        if let share = record.share {
            petModel.shareURL = share.url
            petModel.shareTitle = share[CKShare.SystemFieldKey.title] as? String
        }
        
        // 共有ユーザー情報を取得
        if isShared {
            self.fetchShareParticipants(for: record) { result in
                switch result {
                case .success(let participants):
                    petModel.sharedWithUserIDs = participants
                    completion(.success(petModel))
                case .failure(let error):
                    print("Error fetching share participants: \(error)")
                    completion(.success(petModel)) // エラーでも基本情報は返す
                }
            }
        } else {
            completion(.success(petModel))
        }
    }
    
    // MARK: - 共有関連
    
    // ペットの共有
    func sharePet(_ pet: PetModel, completion: @escaping (Result<URL, Error>) -> Void) {
        // まず対象のレコードを取得
        let recordID = CKRecord.ID(recordName: pet.id.uuidString, zoneID: CKRecordZone.ID(zoneName: Constants.CloudKit.petZoneName, ownerName: CKCurrentUserDefaultName))
        
        privateDatabase.fetch(withRecordID: recordID) { record, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let record = record else {
                completion(.failure(NSError(domain: "CloudKitManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "ペットレコードが見つかりませんでした"])))
                return
            }
            
            // 共有設定を作成
            let share = CKShare(rootRecord: record)
            share[CKShare.SystemFieldKey.title] = "\(pet.name)のケア共有" as CKRecordValue
            
            let modifyOperation = CKModifyRecordsOperation(recordsToSave: [record, share], recordIDsToDelete: nil)
            modifyOperation.perRecordProgressBlock = { _, _ in }
            modifyOperation.perRecordCompletionBlock = { _, _, _ in }
            
            modifyOperation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    // 共有URLを生成
                    if let url = share.url {
                        completion(.success(url))
                    } else {
                        completion(.failure(NSError(domain: "CloudKitManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "共有URLの生成に失敗しました"])))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
            
            self.privateDatabase.add(modifyOperation)
        }
    }
    
    // 共有招待の受け入れ
    func acceptShareInvitation(from url: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        container.acceptShareInvitation(from: url) { _, error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    // レコードの共有参加者を取得
    func fetchShareParticipants(for record: CKRecord, completion: @escaping (Result<[String], Error>) -> Void) {
        guard let share = record.share else {
            completion(.success([]))
            return
        }
        
        let participants = share.participants.compactMap { participant in
            return participant.userIdentity.lookupInfo?.emailAddress
        }
        
        completion(.success(participants))
    }
    
    // 共有レコードの権限変更
    func updateSharePermissions(for pet: PetModel, participantEmail: String, permission: CKShare.ParticipantPermission, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let recordID = CKRecord.ID(recordName: pet.id.uuidString, zoneID: CKRecordZone.ID(zoneName: Constants.CloudKit.petZoneName, ownerName: CKCurrentUserDefaultName)) as? CKRecord.ID else {
            completion(.failure(NSError(domain: "CloudKitManager", code: 4, userInfo: [NSLocalizedDescriptionKey: "無効なレコードIDです"])))
            return
        }
        
        privateDatabase.fetch(withRecordID: recordID) { record, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let record = record, let share = record.share else {
                completion(.failure(NSError(domain: "CloudKitManager", code: 5, userInfo: [NSLocalizedDescriptionKey: "共有レコードが見つかりませんでした"])))
                return
            }
            
            // 参加者を見つけて権限を更新
            for participant in share.participants where participant.userIdentity.lookupInfo?.emailAddress == participantEmail {
                participant.permission = permission
                
                let operation = CKModifyRecordsOperation(recordsToSave: [share], recordIDsToDelete: nil)
                operation.modifyRecordsResultBlock = { result in
                    switch result {
                    case .success:
                        completion(.success(()))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
                
                self.privateDatabase.add(operation)
                return
            }
            
            completion(.failure(NSError(domain: "CloudKitManager", code: 6, userInfo: [NSLocalizedDescriptionKey: "指定された参加者が見つかりませんでした"])))
        }
    }
    
    // 共有の削除（アクセス権の取り消し）
    func removeShare(for pet: PetModel, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let recordID = CKRecord.ID(recordName: pet.id.uuidString, zoneID: CKRecordZone.ID(zoneName: Constants.CloudKit.petZoneName, ownerName: CKCurrentUserDefaultName)) as? CKRecord.ID else {
            completion(.failure(NSError(domain: "CloudKitManager", code: 7, userInfo: [NSLocalizedDescriptionKey: "無効なレコードIDです"])))
            return
        }
        
        privateDatabase.fetch(withRecordID: recordID) { record, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let record = record, let share = record.share else {
                completion(.failure(NSError(domain: "CloudKitManager", code: 8, userInfo: [NSLocalizedDescriptionKey: "共有レコードが見つかりませんでした"])))
                return
            }
            
            // 共有を削除
            let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: [share.recordID])
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
            
            self.privateDatabase.add(operation)
        }
    }
    
    // MARK: - ケアログ関連操作
    
    // ケアログ保存
    func saveCareLog(_ careLog: CareLogModel, completion: @escaping (Result<CKRecord.ID, Error>) -> Void) {
        let record = careLog.toCloudKitRecord()
        
        privateDatabase.save(record) { (record: CKRecord?, error: Error?) in
            if let error = error {
                completion(.failure(error))
            } else if let record = record {
                completion(.success(record.recordID))
            } else {
                completion(.failure(NSError(domain: "CloudKitManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "ケアログの保存に失敗しました"])))
            }
        }
    }
    
    // MARK: - ユーザーフレンドリーな共有UI
    
    // UICloudSharingControllerを使用した共有UI表示
    func presentSharingUI(for pet: PetModel, from viewController: UIViewController, completion: @escaping (Result<Void, Error>) -> Void) {
        // 対象のレコードを取得
        let recordID = CKRecord.ID(recordName: pet.id.uuidString, zoneID: CKRecordZone.ID(zoneName: Constants.CloudKit.petZoneName, ownerName: CKCurrentUserDefaultName))
        
        privateDatabase.fetch(withRecordID: recordID) { record, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let record = record else {
                completion(.failure(NSError(domain: "CloudKitManager", code: 9, userInfo: [NSLocalizedDescriptionKey: "ペットレコードが見つかりませんでした"])))
                return
            }
            
            // 既存の共有を使用するか、新しい共有を作成
            let share: CKShare
            if let existingShare = record.share {
                share = existingShare
            } else {
                share = CKShare(rootRecord: record)
                share[CKShare.SystemFieldKey.title] = "\(pet.name)のケア共有" as CKRecordValue
            }
            
            // 共有UIコントローラーを設定
            let sharingController = UICloudSharingController(share: share, container: self.container)
            sharingController.delegate = viewController as? UICloudSharingControllerDelegate
            sharingController.availablePermissions = [.allowPrivate, .allowReadWrite, .allowReadOnly]
            
            // UIを表示
            DispatchQueue.main.async {
                viewController.present(sharingController, animated: true) {
                    completion(.success(()))
                }
            }
        }
    }
}
