// PetPal/ViewModels/UserProfileViewModel.swift
import Foundation
import CoreData
import SwiftUI
import CloudKit
import Combine

class UserProfileViewModel: ObservableObject {
    private let context: NSManagedObjectContext
    private let cloudKitManager = CloudKitManager()
    private var cancellables = Set<AnyCancellable>()
    
    // 状態管理
    @Published var userProfiles: [UserProfileModel] = []
    @Published var currentUser: UserProfileModel?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    init(context: NSManagedObjectContext) {
        self.context = context
        fetchUserProfiles()
        checkAndCreateCurrentUser()
    }
    
    // MARK: - CRUD 操作
    
    // ユーザープロファイル一覧の取得
    func fetchUserProfiles() {
        let request: NSFetchRequest<UserProfile> = UserProfile.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \UserProfile.name, ascending: true)]
        
        do {
            let fetchedProfiles = try context.fetch(request)
            self.userProfiles = fetchedProfiles.map { UserProfileModel(entity: $0) }
            
            // 現在のユーザーを設定
            if let currentUserProfile = userProfiles.first(where: { $0.isCurrentUser }) {
                self.currentUser = currentUserProfile
            }
        } catch {
            errorMessage = "ユーザー情報の取得に失敗しました: \(error.localizedDescription)"
            print("Error fetching user profiles: \(error)")
        }
    }
    
    // 現在のユーザーのチェックと作成
    func checkAndCreateCurrentUser() {
        if currentUser == nil {
            isLoading = true
            
            // iCloudユーザーIDの取得
            cloudKitManager.fetchCurrentUserID { [weak self] result in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    switch result {
                    case .success(let iCloudID):
                        if let existingUser = self.userProfiles.first(where: { $0.iCloudID == iCloudID }) {
                            // 既存ユーザーを現在のユーザーとして設定
                            self.setCurrentUser(existingUser.id)
                        } else {
                            // 新規ユーザーを作成
                            let deviceName = UIDevice.current.name
                            let randomColor = self.generateRandomColor()
                            
                            let newUser = UserProfileModel(
                                name: deviceName,
                                iCloudID: iCloudID,
                                colorHex: randomColor,
                                isCurrentUser: true
                            )
                            
                            self.saveUserProfile(newUser)
                        }
                    case .failure(let error):
                        // iCloudへのアクセスエラー時はデバイス名でユーザーを作成
                        print("Error fetching iCloud user ID: \(error)")
                        let deviceName = UIDevice.current.name
                        let randomColor = self.generateRandomColor()
                        
                        let newUser = UserProfileModel(
                            name: deviceName,
                            iCloudID: "local_\(UUID().uuidString)",
                            colorHex: randomColor,
                            isCurrentUser: true
                        )
                        
                        self.saveUserProfile(newUser)
                    }
                    
                    self.isLoading = false
                }
            }
        }
    }
    
    // ユーザープロファイルの保存（新規または更新）
    func saveUserProfile(_ profile: UserProfileModel) {
        isLoading = true
        
        // 既存のユーザーを検索
        let request: NSFetchRequest<UserProfile> = UserProfile.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", profile.id as CVarArg)
        
        do {
            let results = try context.fetch(request)
            let userEntity: UserProfile
            
            if let existingUser = results.first {
                // 既存のユーザーを更新
                userEntity = existingUser
            } else {
                // 新規ユーザーを作成
                userEntity = UserProfile(context: context)
                userEntity.id = profile.id
                userEntity.createdAt = Date()
            }
            
            // エンティティを更新
            profile.updateEntity(entity: userEntity)
            
            try context.save()
            
            // CloudKit同期
            cloudKitManager.saveUserProfile(profile) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let recordID):
                        // CloudKitレコードIDを保存
                        let recordIDString = "\(Constants.CloudKit.userZoneName):\(recordID.recordName)"
                        userEntity.cloudKitRecordID = recordIDString
                        try? self?.context.save()
                        
                    case .failure(let error):
                        print("CloudKit sync error: \(error)")
                    }
                    
                    self?.fetchUserProfiles()
                    self?.isLoading = false
                }
            }
        } catch {
            errorMessage = "ユーザー情報の保存に失敗しました: \(error.localizedDescription)"
            print("Error saving user profile: \(error)")
            isLoading = false
        }
    }
    
    // ユーザープロファイルの更新
    func updateUserProfile(id: UUID, name: String, avatarImageData: Data?) {
        guard let index = userProfiles.firstIndex(where: { $0.id == id }) else {
            errorMessage = "更新するユーザーが見つかりませんでした"
            return
        }
        
        var updatedProfile = userProfiles[index]
        updatedProfile.name = name
        
        // アバター画像が提供された場合のみ更新
        if let avatarData = avatarImageData {
            updatedProfile.avatarImageData = avatarData
        }
        
        updatedProfile.updatedAt = Date()
        
        saveUserProfile(updatedProfile)
        
        // 現在のユーザーが更新対象の場合、現在のユーザーも更新
        if currentUser?.id == id {
            currentUser = updatedProfile
        }
    }
    
    // 現在のユーザーを設定
    func setCurrentUser(_ userId: UUID) {
        // すべてのユーザーを現在のユーザーでないとマーク
        for var profile in userProfiles {
            if profile.isCurrentUser {
                profile.isCurrentUser = false
                saveUserProfile(profile)
            }
        }
        
        // 指定されたユーザーを現在のユーザーとしてマーク
        if let index = userProfiles.firstIndex(where: { $0.id == userId }) {
            var updatedProfile = userProfiles[index]
            updatedProfile.isCurrentUser = true
            saveUserProfile(updatedProfile)
            currentUser = updatedProfile
        }
    }
    
    // 他デバイスからの共有招待受け入れ処理
    func acceptSharedInvitation(from url: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        cloudKitManager.acceptShareInvitation(from: url) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    // 共有されたデータを同期
                    self?.syncWithCloudKit()
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    // CloudKitとの同期
    func syncWithCloudKit() {
        cloudKitManager.fetchAllUserProfiles { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                switch result {
                case .success(let cloudProfiles):
                    self.mergeUserProfilesWithCloud(cloudProfiles: cloudProfiles)
                case .failure(let error):
                    print("CloudKit sync error: \(error)")
                }
            }
        }
    }
    
    // ローカルデータとクラウドデータのマージ
    private func mergeUserProfilesWithCloud(cloudProfiles: [UserProfileModel]) {
        let request: NSFetchRequest<UserProfile> = UserProfile.fetchRequest()
        
        do {
            let localProfileEntities = try context.fetch(request)
            let localProfiles = localProfileEntities.map { UserProfileModel(entity: $0) }
            
            // クラウドのプロファイルを処理
            for cloudProfile in cloudProfiles {
                if let localProfile = localProfiles.first(where: { $0.id == cloudProfile.id }) {
                    // 両方に存在する場合、最新の更新日を持つ方を採用
                    if cloudProfile.updatedAt > localProfile.updatedAt {
                        if let entity = localProfileEntities.first(where: { $0.id == cloudProfile.id }) {
                            var updatedProfile = cloudProfile
                            // 現在のユーザーフラグは維持
                            if localProfile.isCurrentUser {
                                updatedProfile.isCurrentUser = true
                            }
                            updatedProfile.updateEntity(entity: entity)
                            try context.save()
                        }
                    }
                } else {
                    // ローカルに存在しない場合は新規作成
                    let newEntity = UserProfile(context: context)
                    // 別デバイスのユーザーなので、現在のユーザーフラグはfalse
                    var newProfile = cloudProfile
                    newProfile.isCurrentUser = false
                    newProfile.updateEntity(entity: newEntity)
                    try context.save()
                }
            }
            
            // ローカルのみに存在するプロファイルのうち、CloudKit IDがあるものはクラウドにアップロード
            for localProfile in localProfiles {
                if !cloudProfiles.contains(where: { $0.id == localProfile.id }) && localProfile.cloudKitRecordID == nil {
                    cloudKitManager.saveUserProfile(localProfile) { _ in }
                }
            }
            
            fetchUserProfiles()
            
        } catch {
            print("Error merging profiles with cloud: \(error)")
            errorMessage = "クラウド同期中にエラーが発生しました"
        }
    }
    
    // ランダムな識別色を生成
    private func generateRandomColor() -> String {
        let predefinedColors = [
            "#4285F4", // Google Blue
            "#EA4335", // Google Red
            "#FBBC05", // Google Yellow
            "#34A853", // Google Green
            "#3B5998", // Facebook Blue
            "#55ACEE", // Twitter Blue
            "#007BB5", // LinkedIn Blue
            "#BD081C", // Pinterest Red
            "#00B489", // Vine Green
            "#7289DA", // Discord Blue
            "#FF6B00", // SoundCloud Orange
            "#FF5700", // Reddit Orange
            "#25D366", // WhatsApp Green
            "#128C7E", // WhatsApp Dark Green
            "#075E54", // WhatsApp Darker Green
            "#FF8800", // Aperture Science Orange
            "#0066FF", // Azure Blue
            "#FF007F", // Deep Pink
            "#00B16A", // Emerald Green
            "#FF0000"  // Red
        ]
        
        return predefinedColors[Int.random(in: 0..<predefinedColors.count)]
    }
}
