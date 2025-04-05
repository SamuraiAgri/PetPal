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
        let petZoneID = CKRecordZone.ID(zoneName: Constants.CloudKit.petZoneName, ownerName: CKCurrentUserDefaultName)
        let petZone = CKRecordZone(zoneID: petZoneID)
        
        let userZoneID = CKRecordZone.ID(zoneName: Constants.CloudKit.userZoneName, ownerName: CKCurrentUserDefaultName)
        let userZone = CKRecordZone(zoneID: userZoneID)
        
        let operation = CKModifyRecordZonesOperation(recordZonesToSave: [petZone, userZone], recordZoneIDsToDelete: nil)
        operation.qualityOfService = .userInitiated
        
        // 明示的な型注釈を追加
        operation.modifyRecordZonesResultBlock = { (result: Result<Void, Error>) -> Void in
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
            let share = CKShare(rootRecord: record)
            share[CKShare.SystemFieldKey.title] = "\(pet.name)のケア共有" as CKRecordValue
            let modifyOperation = CKModifyRecordsOperation(recordsToSave: [record, share], recordIDsToDelete: nil)
            // 修正: perRecordProgressBlock の第一引数を CKRecord に変更
            modifyOperation.perRecordProgressBlock = { (_ record: CKRecord, progress: Double) -> Void in }
            modifyOperation.perRecordCompletionBlock = { (_ recordID: CKRecord.ID, _ record: CKRecord?, _ error: Error?) -> Void in }
            modifyOperation.modifyRecordsResultBlock = { (result: Result<Void, Error>) -> Void in
                switch result {
                case .success:
                    if let shareURL = share.url {
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
        self.container.fetchShareMetadata(with: url) { (metadata: CKShare.Metadata?, error: Error?) -> Void in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let metadata = metadata else {
                completion(.failure(NSError(domain: "CloudKitManager", code: 0,
                                            userInfo: [NSLocalizedDescriptionKey: "無効な共有URLです"])))
                return
            }
            let op = CKAcceptSharesOperation(shareMetadatas: [metadata])
            op.perShareResultBlock = { (metadata: CKShare.Metadata, result: Result<CKShare, Error>) -> Void in
                switch result {
                case .success(let share):
                    print("Share accepted successfully: \(share)")
                case .failure(let error):
                    print("Error accepting share: \(error)")
                }
            }
            op.acceptSharesResultBlock = { (result: Result<Void, Error>) -> Void in
                switch result {
                case .success:
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
            self.container.add(op)
        }
    }
    
    func fetchShareParticipants(for record: CKRecord, completion: @escaping (Result<[String], Error>) -> Void) {
        guard record.share != nil else {
            completion(.success([]))
            return
        }
        // 仮実装：実際は CKShare の API 等を用いて参加者情報を取得する
        let participants: [String] = []
        completion(.success(participants))
    }
    
    func updateSharePermissions(for pet: PetModel, participantEmail: String, permission: CKShare.ParticipantPermission, completion: @escaping (Result<Void, Error>) -> Void) {
        let recordID = CKRecord.ID(recordName: pet.id.uuidString,
                                   zoneID: CKRecordZone.ID(zoneName: Constants.CloudKit.petZoneName,
                                                           ownerName: CKCurrentUserDefaultName))
        privateDatabase.fetch(withRecordID: recordID) { [weak self] (record: CKRecord?, error: Error?) -> Void in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let record = record, let shareReference = record.share else {
                completion(.failure(NSError(domain: "CloudKitManager", code: 5,
                                            userInfo: [NSLocalizedDescriptionKey: "共有レコードが見つかりませんでした"])))
                return
            }
            self?.privateDatabase.fetch(withRecordID: shareReference.recordID) { (fetchedRecord: CKRecord?, error: Error?) -> Void in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                guard let share = fetchedRecord as? CKShare else {
                    completion(.failure(NSError(domain: "CloudKitManager", code: 5,
                                                userInfo: [NSLocalizedDescriptionKey: "共有レコードの変換に失敗しました"])))
                    return
                }
                let operation = CKModifyRecordsOperation(recordsToSave: [share], recordIDsToDelete: nil)
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
    
    // MARK: - ユーザーフレンドリーな共有UI
    
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
                self.privateDatabase.fetch(withRecordID: shareReference.recordID) { [weak self] (fetchedRecord: CKRecord?, error: Error?) -> Void in
                    var share: CKShare
                    if let fetchedShare = fetchedRecord as? CKShare {
                        share = fetchedShare
                    } else {
                        share = CKShare(rootRecord: record)
                        share[CKShare.SystemFieldKey.title] = "\(pet.name)のケア共有" as CKRecordValue
                    }
                    DispatchQueue.main.async {
                        let sharingController = UICloudSharingController(share: share, container: self!.container)
                        sharingController.delegate = viewController as? UICloudSharingControllerDelegate
                        sharingController.availablePermissions = [.allowPrivate, .allowReadWrite, .allowReadOnly]
                        viewController.present(sharingController, animated: true) {
                            completion(.success(()))
                        }
                    }
                }
            } else {
                let share = CKShare(rootRecord: record)
                share[CKShare.SystemFieldKey.title] = "\(pet.name)のケア共有" as CKRecordValue
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
// saveCareSchedule は重複定義とならないよう、こちらのみ定義します
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
}
