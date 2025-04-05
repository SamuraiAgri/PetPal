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
    
    // MARK: - カスタムゾーンの作成
    private func createCustomZoneIfNeeded() {
        // ペットゾーン
        let petZoneID = CKRecordZone.ID(zoneName: Constants.CloudKit.petZoneName, ownerName: CKCurrentUserDefaultName)
        let petZone = CKRecordZone(zoneID: petZoneID)
        
        // ユーザーゾーン
        let userZoneID = CKRecordZone.ID(zoneName: Constants.CloudKit.userZoneName, ownerName: CKCurrentUserDefaultName)
        let userZone = CKRecordZone(zoneID: userZoneID)
        
        // ケアゾーン
        let careZoneID = CKRecordZone.ID(zoneName: Constants.CloudKit.careZoneName, ownerName: CKCurrentUserDefaultName)
        let careZone = CKRecordZone(zoneID: careZoneID)
        
        // ゾーンの作成処理
        let operation = CKModifyRecordZonesOperation(recordZonesToSave: [petZone, userZone, careZone], recordZoneIDsToDelete: nil)
        operation.qualityOfService = .userInitiated
        
        operation.modifyRecordZonesResultBlock = { (result: Result<Void, Error>) -> Void in
            switch result {
            case .success:
                print("✅ カスタムゾーンの作成に成功しました")
            case .failure(let error):
                if let ckError = error as? CKError {
                    if ckError.code == .zoneNotFound {
                        print("❌ ゾーンが見つかりません: \(error.localizedDescription)")
                    } else if ckError.code == .serverRejectedRequest {
                        print("❌ サーバーがリクエストを拒否しました: \(error.localizedDescription)")
                    } else {
                        print("❌ ゾーンの作成エラー: \(error.localizedDescription)")
                    }
                } else {
                    print("❌ ゾーンの作成エラー: \(error.localizedDescription)")
                }
            }
        }
        
        privateDatabase.add(operation)
    }
    
    // MARK: - 現在のユーザー情報関連
    func fetchCurrentUserID(completion: @escaping (Result<String, Error>) -> Void) {
        container.fetchUserRecordID { (recordID: CKRecord.ID?, error: Error?) -> Void in
            if let error = error {
                completion(.failure(error))
            } else if let recordID = recordID {
                completion(.success(recordID.recordName))
            } else {
                completion(.failure(NSError(domain: "CloudKitManager", code: 0,
                                            userInfo: [NSLocalizedDescriptionKey: "Unable to fetch user record ID"])))
            }
        }
    }
    
    // MARK: - ユーザープロファイル関連操作
    func saveUserProfile(_ profile: UserProfileModel, completion: @escaping (Result<CKRecord.ID, Error>) -> Void) {
        let record = profile.toCloudKitRecord()
        privateDatabase.save(record) { (record: CKRecord?, error: Error?) -> Void in
            if let error = error {
                completion(.failure(error))
            } else if let record = record {
                completion(.success(record.recordID))
            } else {
                completion(.failure(NSError(domain: "CloudKitManager", code: 0,
                                            userInfo: [NSLocalizedDescriptionKey: "プロファイルの保存に失敗しました"])))
            }
        }
    }
    
    func fetchAllUserProfiles(completion: @escaping (Result<[UserProfileModel], Error>) -> Void) {
        let query = CKQuery(recordType: "UserProfile", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        let zoneID = CKRecordZone.ID(zoneName: Constants.CloudKit.userZoneName, ownerName: CKCurrentUserDefaultName)
        let queryOperation = CKQueryOperation(query: query)
        queryOperation.zoneID = zoneID
        
        var records: [CKRecord] = []
        queryOperation.recordMatchedBlock = { (recordID: CKRecord.ID, result: Result<CKRecord, Error>) -> Void in
            switch result {
            case .success(let record):
                records.append(record)
            case .failure(let error):
                print("Error fetching record: \(error)")
            }
        }
        queryOperation.queryResultBlock = { [weak self] (result: Result<CKQueryOperation.Cursor?, Error>) -> Void in
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
                var localUserProfiles: [UserProfileModel] = []
                var fetchErrors: [Error] = []
                for record in records {
                    group.enter()
                    self.userProfileModelFromRecord(record) { (result: Result<UserProfileModel?, Error>) in
                        switch result {
                        case .success(let profileModel):
                            if let model = profileModel { localUserProfiles.append(model) }
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
                        completion(.success(localUserProfiles))
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
        sharedQueryOperation.recordMatchedBlock = { (recordID: CKRecord.ID, result: Result<CKRecord, Error>) -> Void in
            switch result {
            case .success(let record):
                records.append(record)
            case .failure(let error):
                print("Error fetching shared record: \(error)")
            }
        }
        sharedQueryOperation.queryResultBlock = { [weak self] (result: Result<CKQueryOperation.Cursor?, Error>) -> Void in
            guard let self = self else { return }
            switch result {
            case .success(_):
                if records.isEmpty { return }
                let group = DispatchGroup()
                var sharedUserProfiles: [UserProfileModel] = []
                var fetchErrors: [Error] = []
                for record in records {
                    group.enter()
                    self.userProfileModelFromRecord(record) { (result: Result<UserProfileModel?, Error>) in
                        switch result {
                        case .success(let profileModel):
                            if let model = profileModel { sharedUserProfiles.append(model) }
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
                        var allProfiles: [UserProfileModel] = []
                        for sharedProfile in sharedUserProfiles {
                            if !allProfiles.contains(where: { $0.id == sharedProfile.id }) {
                                allProfiles.append(sharedProfile)
                            }
                        }
                        completion(.success(allProfiles))
                    }
                }
            case .failure(let error):
                print("Error fetching shared user profiles: \(error)")
            }
        }
        sharedDatabase.add(sharedQueryOperation)
    }
    
    private func userProfileModelFromRecord(_ record: CKRecord,
                                              completion: @escaping (Result<UserProfileModel?, Error>) -> Void) {
        guard let idString = record["id"] as? String,
              let id = UUID(uuidString: idString),
              let name = record["name"] as? String,
              let iCloudID = record["iCloudID"] as? String,
              let colorHex = record["colorHex"] as? String,
              let isCurrentUser = record["isCurrentUser"] as? Bool,
              let createdAt = record["createdAt"] as? Date,
              let updatedAt = record["updatedAt"] as? Date else {
            completion(.failure(NSError(domain: "CloudKitManager", code: 1,
                                        userInfo: [NSLocalizedDescriptionKey: "レコードの変換に失敗しました"])))
            return
        }
        
        var avatarImageData: Data? = nil
        if let avatarAsset = record["avatarImageAsset"] as? CKAsset,
           let url = avatarAsset.fileURL {
            do {
                avatarImageData = try Data(contentsOf: url)
            } catch {
                print("Error loading avatar image data: \(error)")
            }
        }
        
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
    func savePet(_ pet: PetModel, completion: @escaping (Result<CKRecord.ID, Error>) -> Void) {
        let record = pet.toCloudKitRecord()
        privateDatabase.save(record) { (record: CKRecord?, error: Error?) -> Void in
            if let error = error {
                completion(.failure(error))
            } else if let record = record {
                completion(.success(record.recordID))
            } else {
                completion(.failure(NSError(domain: "CloudKitManager", code: 0,
                                            userInfo: [NSLocalizedDescriptionKey: "レコードの保存に失敗しました"])))
            }
        }
    }
    
    func fetchPet(id: UUID, completion: @escaping (Result<PetModel?, Error>) -> Void) {
        let predicate = NSPredicate(format: "id == %@", id.uuidString)
        let query = CKQuery(recordType: "Pet", predicate: predicate)
        let zoneID = CKRecordZone.ID(zoneName: Constants.CloudKit.petZoneName, ownerName: CKCurrentUserDefaultName)
        let queryOperation = CKQueryOperation(query: query)
        queryOperation.zoneID = zoneID
        
        var records: [CKRecord] = []
        queryOperation.recordMatchedBlock = { (recordID: CKRecord.ID, result: Result<CKRecord, Error>) -> Void in
            switch result {
            case .success(let record):
                records.append(record)
            case .failure(let error):
                print("Error fetching record: \(error)")
            }
        }
        
        queryOperation.queryResultBlock = { [weak self] (result: Result<CKQueryOperation.Cursor?, Error>) -> Void in
            guard let self = self else { return }
            switch result {
            case .success(_):
                if let record = records.first {
                    self.petModelFromRecord(record) { (result: Result<PetModel?, Error>) in
                        DispatchQueue.main.async { completion(result) }
                    }
                } else {
                    self.fetchSharedPet(id: id, completion: completion)
                }
            case .failure(let error):
                print("Private database error: \(error). Checking shared database.")
                self.fetchSharedPet(id: id, completion: completion)
            }
        }
        
        privateDatabase.add(queryOperation)
    }
    
    private func fetchSharedPet(id: UUID, completion: @escaping (Result<PetModel?, Error>) -> Void) {
        let predicate = NSPredicate(format: "id == %@", id.uuidString)
        let query = CKQuery(recordType: "Pet", predicate: predicate)
        let queryOperation = CKQueryOperation(query: query)
        
        var records: [CKRecord] = []
        queryOperation.recordMatchedBlock = { (recordID: CKRecord.ID, result: Result<CKRecord, Error>) -> Void in
            switch result {
            case .success(let record):
                records.append(record)
            case .failure(let error):
                print("Error fetching shared record: \(error)")
            }
        }
        
        queryOperation.queryResultBlock = { [weak self] (result: Result<CKQueryOperation.Cursor?, Error>) -> Void in
            guard let self = self else { return }
            switch result {
            case .success(_):
                if let record = records.first {
                    self.petModelFromRecord(record) { (result: Result<PetModel?, Error>) in
                        DispatchQueue.main.async { completion(result) }
                    }
                } else {
                    DispatchQueue.main.async { completion(.success(nil)) }
                }
            case .failure(let error):
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
        
        sharedDatabase.add(queryOperation)
    }
    
    func fetchAllPets(completion: @escaping (Result<[PetModel], Error>) -> Void) {
        let query = CKQuery(recordType: "Pet", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        let zoneID = CKRecordZone.ID(zoneName: Constants.CloudKit.petZoneName, ownerName: CKCurrentUserDefaultName)
        let queryOperation = CKQueryOperation(query: query)
        queryOperation.zoneID = zoneID
        
        var allRecords: [CKRecord] = []
        queryOperation.recordMatchedBlock = { (recordID: CKRecord.ID, result: Result<CKRecord, Error>) -> Void in
            switch result {
            case .success(let record):
                allRecords.append(record)
            case .failure(let error):
                print("Error fetching record: \(error)")
            }
        }
        
        queryOperation.queryResultBlock = { [weak self] (result: Result<CKQueryOperation.Cursor?, Error>) -> Void in
            guard let self = self else { return }
            switch result {
            case .success(_):
                self.fetchAllSharedPets { (result: Result<[PetModel], Error>) in
                    switch result {
                    case .success(let sharedPets):
                        self.processPetRecords(allRecords) { (privateResult: Result<[PetModel], Error>) in
                            switch privateResult {
                            case .success(let privatePets):
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
                        print("Error fetching shared pets: \(error)")
                        self.processPetRecords(allRecords) { (privateResult: Result<[PetModel], Error>) in
                            DispatchQueue.main.async {
                                completion(privateResult)
                            }
                        }
                    }
                }
            case .failure(let error):
                print("Error fetching private pets: \(error)")
                self.fetchAllSharedPets(completion: completion)
            }
        }
        
        privateDatabase.add(queryOperation)
    }
    
    private func processPetRecords(_ records: [CKRecord],
                                   completion: @escaping (Result<[PetModel], Error>) -> Void) {
        if records.isEmpty {
            completion(.success([]))
            return
        }
        
        let group = DispatchGroup()
        var petModels: [PetModel] = []
        var fetchErrors: [Error] = []
        for record in records {
            group.enter()
            self.petModelFromRecord(record) { (result: Result<PetModel?, Error>) in
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
    
    private func fetchAllSharedPets(completion: @escaping (Result<[PetModel], Error>) -> Void) {
        let query = CKQuery(recordType: "Pet", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        let queryOperation = CKQueryOperation(query: query)
        
        var records: [CKRecord] = []
        queryOperation.recordMatchedBlock = { (recordID: CKRecord.ID, result: Result<CKRecord, Error>) -> Void in
            switch result {
            case .success(let record):
                records.append(record)
            case .failure(let error):
                print("Error fetching shared record: \(error)")
            }
        }
        queryOperation.queryResultBlock = { [weak self] (result: Result<CKQueryOperation.Cursor?, Error>) -> Void in
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
    
    private func petModelFromRecord(_ record: CKRecord,
                                    completion: @escaping (Result<PetModel?, Error>) -> Void) {
        guard let idString = record["id"] as? String,
              let id = UUID(uuidString: idString),
              let name = record["name"] as? String,
              let species = record["species"] as? String,
              let birthDate = record["birthDate"] as? Date else {
            completion(.failure(NSError(domain: "CloudKitManager", code: 1,
                                        userInfo: [NSLocalizedDescriptionKey: "レコードの変換に失敗しました"])))
            return
        }
        
        let breed = record["breed"] as? String ?? ""
        let gender = record["gender"] as? String ?? ""
        let notes = record["notes"] as? String ?? ""
        let createdAt = record["createdAt"] as? Date ?? Date()
        let updatedAt = record["updatedAt"] as? Date ?? Date()
        let isActive = record["isActive"] as? Bool ?? true
        let isShared = record.share != nil
        
        var iconImageData: Data? = nil
        if let iconAsset = record["iconImageAsset"] as? CKAsset,
           let url = iconAsset.fileURL {
            do {
                iconImageData = try Data(contentsOf: url)
            } catch {
                print("Error loading icon image data: \(error)")
            }
        }
        
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
        
        if isShared, let shareReference = record.share {
            privateDatabase.fetch(withRecordID: shareReference.recordID) { [weak self] (fetchedRecord: CKRecord?, error: Error?) -> Void in
                if let fetchedShare = fetchedRecord as? CKShare {
                    if let shareURL = fetchedShare.url {
                        petModel.shareURL = shareURL
                    }
                    if let title = fetchedShare[CKShare.SystemFieldKey.title] as? String {
                        petModel.shareTitle = title
                    }
                }
                self?.fetchShareParticipants(for: record) { (result: Result<[String], Error>) -> Void in
                    switch result {
                    case .success(let participants):
                        petModel.sharedWithUserIDs = participants
                        completion(.success(petModel))
                    case .failure(let error):
                        print("Error fetching share participants: \(error)")
                        completion(.success(petModel))
                    }
                }
            }
        } else {
            completion(.success(petModel))
        }
    }
    
    // MARK: - 共有関連
    func sharePet(_ pet: PetModel, completion: @escaping (Result<URL, Error>) -> Void) {
        // まず対象のペットレコードを取得
        let recordID = CKRecord.ID(recordName: pet.id.uuidString,
                                   zoneID: CKRecordZone.ID(zoneName: Constants.CloudKit.petZoneName,
                                                           ownerName: CKCurrentUserDefaultName))
        privateDatabase.fetch(withRecordID: recordID) { (record: CKRecord?, error: Error?) -> Void in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let record = record else {
                completion(.failure(NSError(domain: "CloudKitManager", code: 2,
                                            userInfo: [NSLocalizedDescriptionKey: "ペットレコードが見つかりませんでした"])))
                return
            }
            
            // 共有レコードを作成
            let share = CKShare(rootRecord: record)
            
            // 共有設定
            share[CKShare.SystemFieldKey.title] = "\(pet.name)のケア共有" as CKRecordValue
            
            // 権限設定 - デフォルトで読み書き権限に
            share.publicPermission = .readWrite
            
            // 保存操作
            let modifyOperation = CKModifyRecordsOperation(recordsToSave: [record, share], recordIDsToDelete: nil)
            
            modifyOperation.modifyRecordsResultBlock = { (result: Result<Void, Error>) -> Void in
                switch result {
                case .success:
                    if let shareURL = share.url {
                        // 成功した場合、共有URLを返す
                        completion(.success(shareURL))
                    } else {
                        completion(.failure(NSError(domain: "CloudKitManager", code: 3,
                                                    userInfo: [NSLocalizedDescriptionKey: "共有URLの生成に失敗しました"])))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
            
            self.privateDatabase.add(modifyOperation)
        }
    }
    
    func acceptShareInvitation(from url: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        container.fetchShareMetadata(with: url) { (metadata: CKShare.Metadata?, error: Error?) -> Void in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let metadata = metadata else {
                completion(.failure(NSError(domain: "CloudKitManager", code: 0,
                                            userInfo: [NSLocalizedDescriptionKey: "無効な共有URLです"])))
                return
            }
            
            let operation = CKAcceptSharesOperation(shareMetadatas: [metadata])
            
            operation.perShareResultBlock = { (metadata: CKShare.Metadata, result: Result<CKShare, Error>) -> Void in
                switch result {
                case .success(let share):
                    print("共有の受け入れに成功しました: \(share)")
                case .failure(let error):
                    print("共有の受け入れエラー: \(error)")
                }
            }
            
            operation.acceptSharesResultBlock = { (result: Result<Void, Error>) -> Void in
                switch result {
                case .success:
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
            
            self.container.add(operation)
        }
    }
    
    func fetchShareParticipants(for record: CKRecord, completion: @escaping (Result<[String], Error>) -> Void) {
        guard let share = record.share else {
            completion(.success([]))
            return
        }
        
        privateDatabase.fetch(withRecordID: share.recordID) { (fetchedRecord: CKRecord?, error: Error?) -> Void in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let fetchedShare = fetchedRecord as? CKShare else {
                completion(.success([]))
                return
            }
            
            // 参加者IDのリストを作成
            var participantIDs: [String] = []

            for participant in fetchedShare.participants {
                if let userID = participant.userIdentity.userRecordID?.recordName {
                    participantIDs.append(userID)
                }
            }
            
            completion(.success(participantIDs))
        }
    }
    
    func updateSharePermissions(for pet: PetModel, participantEmail: String, permission: CKShare.ParticipantPermission, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let shareURLString = pet.shareURL?.absoluteString else {
            completion(.failure(NSError(domain: "CloudKitManager", code: 4,
                                        userInfo: [NSLocalizedDescriptionKey: "共有URLがありません"])))
            return
        }
        
        let recordID = CKRecord.ID(recordName: pet.id.uuidString,
                                   zoneID: CKRecordZone.ID(zoneName: Constants.CloudKit.petZoneName,
                                                           ownerName: CKCurrentUserDefaultName))
        
        privateDatabase.fetch(withRecordID: recordID) { [weak self] (record: CKRecord?, error: Error?) -> Void in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let self = self,
                  let record = record,
                  let shareReference = record.share else {
                completion(.failure(NSError(domain: "CloudKitManager", code: 5,
                                            userInfo: [NSLocalizedDescriptionKey: "共有レコードが見つかりませんでした"])))
                return
            }
            
            self.privateDatabase.fetch(withRecordID: shareReference.recordID) { (fetchedRecord: CKRecord?, error: Error?) -> Void in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let share = fetchedRecord as? CKShare else {
                    completion(.failure(NSError(domain: "CloudKitManager", code: 5,
                                                userInfo: [NSLocalizedDescriptionKey: "共有レコードの変換に失敗しました"])))
                    return
                }
                
                // ここで参加者の権限を更新
                for participant in share.participants {
                    // メールアドレスの取得方法
                    let email = participant.userIdentity.lookupInfo?.emailAddress
                    
                    if email == participantEmail {
                        participant.permission = permission
                        break
                    }
                }
                
                // 変更を保存
                let operation = CKModifyRecordsOperation(recordsToSave: [share], recordIDsToDelete: nil)
                
                operation.modifyRecordsResultBlock = { (result: Result<Void, Error>) -> Void in
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
    }
    func removeShare(for pet: PetModel, completion: @escaping (Result<Void, Error>) -> Void) {
            let recordID = CKRecord.ID(recordName: pet.id.uuidString,
                                       zoneID: CKRecordZone.ID(zoneName: Constants.CloudKit.petZoneName,
                                                               ownerName: CKCurrentUserDefaultName))
            privateDatabase.fetch(withRecordID: recordID) { [weak self] (record: CKRecord?, error: Error?) -> Void in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                guard let record = record, let shareReference = record.share else {
                    completion(.failure(NSError(domain: "CloudKitManager", code: 8,
                                                userInfo: [NSLocalizedDescriptionKey: "共有レコードが見つかりませんでした"])))
                    return
                }
                self?.privateDatabase.fetch(withRecordID: shareReference.recordID) { (fetchedRecord: CKRecord?, error: Error?) -> Void in
                    if let error = error {
                        completion(.failure(error))
                        return
                    }
                    guard let share = fetchedRecord as? CKShare else {
                        completion(.failure(NSError(domain: "CloudKitManager", code: 8,
                                                    userInfo: [NSLocalizedDescriptionKey: "共有レコードの変換に失敗しました"])))
                        return
                    }
                    
                    // 共有を削除
                    let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: [share.recordID])
                    operation.modifyRecordsResultBlock = { (result: Result<Void, Error>) -> Void in
                        switch result {
                        case .success:
                            completion(.success(()))
                        case .failure(let error):
                            completion(.failure(error))
                        }
                    }
                    self?.privateDatabase.add(operation)
                }
            }
        }
        
        // MARK: - ケアログ関連操作
        func saveCareLog(_ careLog: CareLogModel, completion: @escaping (Result<CKRecord.ID, Error>) -> Void) {
            let record = careLog.toCloudKitRecord()
            privateDatabase.save(record) { (record: CKRecord?, error: Error?) -> Void in
                if let error = error {
                    completion(.failure(error))
                } else if let record = record {
                    completion(.success(record.recordID))
                } else {
                    completion(.failure(NSError(domain: "CloudKitManager", code: 0,
                                                userInfo: [NSLocalizedDescriptionKey: "ケアログの保存に失敗しました"])))
                }
            }
        }
        
        // この関数を追加 - 特定のペットのケア記録を取得
        func fetchCareLogs(for petId: UUID, completion: @escaping (Result<[CareLogModel], Error>) -> Void) {
            let predicate = NSPredicate(format: "petId == %@", petId.uuidString)
            let query = CKQuery(recordType: "CareLog", predicate: predicate)
            query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
            
            let zoneID = CKRecordZone.ID(zoneName: Constants.CloudKit.careZoneName, ownerName: CKCurrentUserDefaultName)
            let queryOperation = CKQueryOperation(query: query)
            queryOperation.zoneID = zoneID
            
            var records: [CKRecord] = []
            queryOperation.recordMatchedBlock = { (recordID: CKRecord.ID, result: Result<CKRecord, Error>) -> Void in
                switch result {
                case .success(let record):
                    records.append(record)
                case .failure(let error):
                    print("Error fetching care log record: \(error)")
                }
            }
            
            queryOperation.queryResultBlock = { [weak self] (result: Result<CKQueryOperation.Cursor?, Error>) -> Void in
                guard let self = self else { return }
                switch result {
                case .success(_):
                    if records.isEmpty {
                        // プライベートDBに記録がない場合、共有DBも確認する
                        self.fetchSharedCareLogs(for: petId, completion: completion)
                        return
                    }
                    
                    let group = DispatchGroup()
                    var careLogs: [CareLogModel] = []
                    var fetchErrors: [Error] = []
                    
                    for record in records {
                        group.enter()
                        self.careLogModelFromRecord(record) { (result: Result<CareLogModel?, Error>) in
                            switch result {
                            case .success(let careLogModel):
                                if let model = careLogModel {
                                    careLogs.append(model)
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
                            // 共有DBからも取得して結合
                            self.fetchSharedCareLogs(for: petId) { (sharedResult: Result<[CareLogModel], Error>) in
                                switch sharedResult {
                                case .success(let sharedLogs):
                                    var combinedLogs = careLogs
                                    for sharedLog in sharedLogs {
                                        if !combinedLogs.contains(where: { $0.id == sharedLog.id }) {
                                            combinedLogs.append(sharedLog)
                                        }
                                    }
                                    // タイムスタンプの降順で並べ替え
                                    combinedLogs.sort { $0.timestamp > $1.timestamp }
                                    completion(.success(combinedLogs))
                                case .failure(_):
                                    // 共有DBからの取得に失敗しても、プライベートDBのログは返す
                                    careLogs.sort { $0.timestamp > $1.timestamp }
                                    completion(.success(careLogs))
                                }
                            }
                        }
                    }
                case .failure(let error):
                    print("Error fetching care logs: \(error)")
                    self.fetchSharedCareLogs(for: petId, completion: completion)
                }
            }
            
            privateDatabase.add(queryOperation)
        }
        
        // 共有データベースからケア記録を取得
        private func fetchSharedCareLogs(for petId: UUID, completion: @escaping (Result<[CareLogModel], Error>) -> Void) {
            let predicate = NSPredicate(format: "petId == %@", petId.uuidString)
            let query = CKQuery(recordType: "CareLog", predicate: predicate)
            query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
            
            let queryOperation = CKQueryOperation(query: query)
            
            var records: [CKRecord] = []
            queryOperation.recordMatchedBlock = { (recordID: CKRecord.ID, result: Result<CKRecord, Error>) -> Void in
                switch result {
                case .success(let record):
                    records.append(record)
                case .failure(let error):
                    print("Error fetching shared care log record: \(error)")
                }
            }
            
            queryOperation.queryResultBlock = { [weak self] (result: Result<CKQueryOperation.Cursor?, Error>) -> Void in
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
                    var careLogs: [CareLogModel] = []
                    var fetchErrors: [Error] = []
                    
                    for record in records {
                        group.enter()
                        self.careLogModelFromRecord(record) { (result: Result<CareLogModel?, Error>) in
                            switch result {
                            case .success(let careLogModel):
                                if let model = careLogModel {
                                    careLogs.append(model)
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
                            // タイムスタンプの降順で並べ替え
                            careLogs.sort { $0.timestamp > $1.timestamp }
                            completion(.success(careLogs))
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
        
        // CKRecordからCareLogModelへの変換
        private func careLogModelFromRecord(_ record: CKRecord, completion: @escaping (Result<CareLogModel?, Error>) -> Void) {
            guard let idString = record["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let type = record["type"] as? String,
                  let timestamp = record["timestamp"] as? Date else {
                completion(.failure(NSError(domain: "CloudKitManager", code: 1,
                                            userInfo: [NSLocalizedDescriptionKey: "ケアログレコードの変換に失敗しました"])))
                return
            }
            
            let notes = record["notes"] as? String ?? ""
            let performedBy = record["performedBy"] as? String ?? ""
            let isCompleted = record["isCompleted"] as? Bool ?? true
            
            var petId: UUID? = nil
            if let petIdString = record["petId"] as? String, let uuid = UUID(uuidString: petIdString) {
                petId = uuid
            }
            
            var userProfileID: UUID? = nil
            if let userProfileIDString = record["userProfileID"] as? String, let uuid = UUID(uuidString: userProfileIDString) {
                userProfileID = uuid
            }
            
            var assignedUserProfileID: UUID? = nil
            if let assignedUserProfileIDString = record["assignedUserProfileID"] as? String, let uuid = UUID(uuidString: assignedUserProfileIDString) {
                assignedUserProfileID = uuid
            }
            
            let scheduledDate = record["scheduledDate"] as? Date
            let isScheduled = record["isScheduled"] as? Bool ?? false
            
            let cloudKitRecordID = "\(Constants.CloudKit.careZoneName):\(record.recordID.recordName)"
            var careLogModel = CareLogModel(
                type: type,
                notes: notes,
                performedBy: performedBy,
                petId: petId,
                userProfileID: userProfileID,
                isScheduled: isScheduled,
                scheduledDate: scheduledDate,
                assignedUserProfileID: assignedUserProfileID
            )
            
            careLogModel.id = id
            careLogModel.timestamp = timestamp
            careLogModel.isCompleted = isCompleted
            careLogModel.cloudKitRecordID = cloudKitRecordID
            
            completion(.success(careLogModel))
        }
        
    func presentSharingUI(for pet: PetModel, from viewController: UIViewController, completion: @escaping (Result<Void, Error>) -> Void) {
        let recordID = CKRecord.ID(recordName: pet.id.uuidString,
                                   zoneID: CKRecordZone.ID(zoneName: Constants.CloudKit.petZoneName,
                                                           ownerName: CKCurrentUserDefaultName))
        privateDatabase.fetch(withRecordID: recordID) { [weak self] (record: CKRecord?, error: Error?) -> Void in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let self = self, let record = record else {
                completion(.failure(NSError(domain: "CloudKitManager", code: 9,
                                            userInfo: [NSLocalizedDescriptionKey: "ペットレコードが見つかりませんでした"])))
                return
            }
            
            if let shareReference = record.share {
                // 既存の共有がある場合
                self.privateDatabase.fetch(withRecordID: shareReference.recordID) { [weak self] (fetchedRecord: CKRecord?, error: Error?) -> Void in
                    guard let self = self else { return }
                    
                    let share: CKShare
                    if let fetchedShare = fetchedRecord as? CKShare {
                        share = fetchedShare
                    } else {
                        // 既存の共有が取得できない場合は新規作成
                        share = CKShare(rootRecord: record)
                        share[CKShare.SystemFieldKey.title] = "\(pet.name)のケア共有" as CKRecordValue
                        share.publicPermission = .readWrite
                    }
                    
                    DispatchQueue.main.async {
                        let sharingController = UICloudSharingController(share: share, container: self.container)
                        sharingController.delegate = viewController as? UICloudSharingControllerDelegate
                        sharingController.availablePermissions = [.allowPrivate, .allowReadWrite, .allowReadOnly]
                        viewController.present(sharingController, animated: true) {
                            completion(.success(()))
                        }
                    }
                }
            } else {
                // 新規共有作成
                let share = CKShare(rootRecord: record)
                share[CKShare.SystemFieldKey.title] = "\(pet.name)のケア共有" as CKRecordValue
                share.publicPermission = .readWrite
                
                DispatchQueue.main.async {
                    let sharingController = UICloudSharingController(share: share, container: self.container)
                    sharingController.delegate = viewController as? UICloudSharingControllerDelegate
                    sharingController.availablePermissions = [.allowPrivate, .allowReadWrite, .allowReadOnly]
                    viewController.present(sharingController, animated: true) {
                        completion(.success(()))
                    }
                }
            }
        }
    }
    }

    // MARK: - CareViewModel 用の拡張
    extension CloudKitManager {
        func saveCareSchedule(_ schedule: CareScheduleModel, completion: @escaping (Result<CKRecord.ID, Error>) -> Void) {
            let record = schedule.toCloudKitRecord()
            privateDatabase.save(record) { (record: CKRecord?, error: Error?) -> Void in
                if let error = error {
                    completion(.failure(error))
                } else if let record = record {
                    completion(.success(record.recordID))
                } else {
                    completion(.failure(NSError(domain: "CloudKitManager", code: 0,
                                                userInfo: [NSLocalizedDescriptionKey: "スケジュールの保存に失敗しました"])))
                }
            }
        }
        
        // ケアスケジュールの取得
        func fetchCareSchedules(for petId: UUID, completion: @escaping (Result<[CareScheduleModel], Error>) -> Void) {
            let predicate = NSPredicate(format: "petId == %@", petId.uuidString)
            let query = CKQuery(recordType: "CareSchedule", predicate: predicate)
            query.sortDescriptors = [NSSortDescriptor(key: "scheduledDate", ascending: true)]
            
            let zoneID = CKRecordZone.ID(zoneName: Constants.CloudKit.careZoneName, ownerName: CKCurrentUserDefaultName)
            let queryOperation = CKQueryOperation(query: query)
            queryOperation.zoneID = zoneID
            
            var records: [CKRecord] = []
            queryOperation.recordMatchedBlock = { (recordID: CKRecord.ID, result: Result<CKRecord, Error>) -> Void in
                switch result {
                case .success(let record):
                    records.append(record)
                case .failure(let error):
                    print("Error fetching care schedule record: \(error)")
                }
            }
            
            queryOperation.queryResultBlock = { [weak self] (result: Result<CKQueryOperation.Cursor?, Error>) -> Void in
                guard let self = self else { return }
                switch result {
                case .success(_):
                    if records.isEmpty {
                        // プライベートDBに記録がない場合、共有DBも確認する
                        self.fetchSharedCareSchedules(for: petId, completion: completion)
                        return
                    }
                    
                    let group = DispatchGroup()
                    var careSchedules: [CareScheduleModel] = []
                    var fetchErrors: [Error] = []
                    
                    for record in records {
                        group.enter()
                        self.careScheduleModelFromRecord(record) { (result: Result<CareScheduleModel?, Error>) in
                            switch result {
                            case .success(let model):
                                if let model = model {
                                    careSchedules.append(model)
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
                            // 共有DBからも取得して結合
                            self.fetchSharedCareSchedules(for: petId) { (sharedResult: Result<[CareScheduleModel], Error>) in
                                switch sharedResult {
                                case .success(let sharedSchedules):
                                    var combinedSchedules = careSchedules
                                    for sharedSchedule in sharedSchedules {
                                        if !combinedSchedules.contains(where: { $0.id == sharedSchedule.id }) {
                                            combinedSchedules.append(sharedSchedule)
                                        }
                                    }
                                    // 日付の昇順で並べ替え
                                    combinedSchedules.sort { $0.scheduledDate < $1.scheduledDate }
                                    completion(.success(combinedSchedules))
                                case .failure(_):
                                    // 共有DBからの取得に失敗しても、プライベートDBのスケジュールは返す
                                    careSchedules.sort { $0.scheduledDate < $1.scheduledDate }
                                    completion(.success(careSchedules))
                                }
                            }
                        }
                    }
                case .failure(let error):
                    print("Error fetching care schedules: \(error)")
                    self.fetchSharedCareSchedules(for: petId, completion: completion)
                }
            }
            
            privateDatabase.add(queryOperation)
        }
        
        // 共有データベースからケアスケジュールを取得
        private func fetchSharedCareSchedules(for petId: UUID, completion: @escaping (Result<[CareScheduleModel], Error>) -> Void) {
            let predicate = NSPredicate(format: "petId == %@", petId.uuidString)
            let query = CKQuery(recordType: "CareSchedule", predicate: predicate)
            query.sortDescriptors = [NSSortDescriptor(key: "scheduledDate", ascending: true)]
            
            let queryOperation = CKQueryOperation(query: query)
            
            var records: [CKRecord] = []
            queryOperation.recordMatchedBlock = { (recordID: CKRecord.ID, result: Result<CKRecord, Error>) -> Void in
                switch result {
                case .success(let record):
                    records.append(record)
                case .failure(let error):
                    print("Error fetching shared care schedule record: \(error)")
                }
            }
            
            queryOperation.queryResultBlock = { [weak self] (result: Result<CKQueryOperation.Cursor?, Error>) -> Void in
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
                    var careSchedules: [CareScheduleModel] = []
                    var fetchErrors: [Error] = []
                    
                    for record in records {
                        group.enter()
                        self.careScheduleModelFromRecord(record) { (result: Result<CareScheduleModel?, Error>) in
                            switch result {
                            case .success(let model):
                                if let model = model {
                                    careSchedules.append(model)
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
                            // 日付の昇順で並べ替え
                            careSchedules.sort { $0.scheduledDate < $1.scheduledDate }
                            completion(.success(careSchedules))
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
        
        // CKRecordからCareScheduleModelへの変換
        private func careScheduleModelFromRecord(_ record: CKRecord, completion: @escaping (Result<CareScheduleModel?, Error>) -> Void) {
            guard let idString = record["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let type = record["type"] as? String,
                  let scheduledDate = record["scheduledDate"] as? Date else {
                completion(.failure(NSError(domain: "CloudKitManager", code: 1,
                                            userInfo: [NSLocalizedDescriptionKey: "ケアスケジュールレコードの変換に失敗しました"])))
                return
            }
            
            let notes = record["notes"] as? String ?? ""
            let isCompleted = record["isCompleted"] as? Bool ?? false
            let createdAt = record["createdAt"] as? Date ?? Date()
            let updatedAt = record["updatedAt"] as? Date ?? Date()
            
            var petId: UUID? = nil
            if let petIdString = record["petId"] as? String, let uuid = UUID(uuidString: petIdString) {
                petId = uuid
            }
            
            var assignedUserProfileID: UUID? = nil
            if let assignedUserProfileIDString = record["assignedUserProfileID"] as? String, let uuid = UUID(uuidString: assignedUserProfileIDString) {
                assignedUserProfileID = uuid
            }
            
            var completedBy: UUID? = nil
            if let completedByString = record["completedBy"] as? String, let uuid = UUID(uuidString: completedByString) {
                completedBy = uuid
            }
            
            var createdBy: UUID? = nil
            if let createdByString = record["createdBy"] as? String, let uuid = UUID(uuidString: createdByString) {
                createdBy = uuid
            }
            
            let completedDate = record["completedDate"] as? Date
            
            let cloudKitRecordID = "\(Constants.CloudKit.careZoneName):\(record.recordID.recordName)"
            var careScheduleModel = CareScheduleModel(
                type: type,
                assignedUserProfileID: assignedUserProfileID,
                scheduledDate: scheduledDate,
                notes: notes,
                createdBy: createdBy,
                petId: petId
            )
            
            careScheduleModel.id = id
            careScheduleModel.isCompleted = isCompleted
            careScheduleModel.completedBy = completedBy
            careScheduleModel.completedDate = completedDate
            careScheduleModel.createdAt = createdAt
            careScheduleModel.updatedAt = updatedAt
            careScheduleModel.cloudKitRecordID = cloudKitRecordID
            
            completion(.success(careScheduleModel))
        }
    }
