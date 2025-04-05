// PetPal/Models/CoreData/Persistence.swift
import CoreData
import CloudKit

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // プレビューデータの作成
        let samplePet = Pet(context: viewContext)
        samplePet.id = UUID()
        samplePet.name = "ポチ"
        samplePet.species = "犬"
        samplePet.breed = "柴犬"
        samplePet.birthDate = Calendar.current.date(byAdding: .year, value: -2, to: Date())!
        samplePet.gender = "オス"
        samplePet.notes = "元気いっぱいの柴犬です"
        samplePet.createdAt = Date()
        samplePet.updatedAt = Date()
        samplePet.isActive = true
        samplePet.isShared = false
        
        // サンプルユーザープロファイル
        let sampleUser = UserProfile(context: viewContext)
        sampleUser.id = UUID()
        sampleUser.name = "テストユーザー"
        sampleUser.iCloudID = "local_test_user"
        sampleUser.colorHex = "#4285F4"
        sampleUser.isCurrentUser = true
        sampleUser.createdAt = Date()
        sampleUser.updatedAt = Date()
        
        // サンプルケア記録
        let sampleCare = CareLog(context: viewContext)
        sampleCare.id = UUID()
        sampleCare.type = Constants.CareTypes.walk
        sampleCare.timestamp = Date()
        sampleCare.notes = "元気に散歩しました"
        sampleCare.performedBy = "テストユーザー"
        sampleCare.isCompleted = true
        sampleCare.pet = samplePet
        sampleCare.userProfileID = sampleUser.id
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        
        return result
    }()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "PetPal")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        // CoreDataスキーマの移行処理の設定
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Failed to retrieve a persistent store description.")
        }
        
        // 自動スキーマ移行の有効化
        let options = [
            NSMigratePersistentStoresAutomaticallyOption: true,
            NSInferMappingModelAutomaticallyOption: true
        ]
        
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        
        // setOptionsメソッドの代わりにオプションを直接設定
        for (key, value) in options {
            description.setOption(value as NSObject, forKey: key)
        }
        
        // CloudKit同期の設定
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: Constants.CloudKit.containerIdentifier
        )
        
        // 自動マージポリシーの設定
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        container.loadPersistentStores { (_, error) in
            if let error = error as NSError? {
                // CloudKit同期に失敗してもローカルでは動作するように、エラーはログだけ残す
                print("Persistent store loading error: \(error), \(error.userInfo)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // CoreData全体に対するクエリ生成の最適化
        container.viewContext.stalenessInterval = 0
        
        // クラウド同期の詳細設定
        setupCloudKitSync()
    }
    
    // CloudKit同期に関する詳細設定
    private func setupCloudKitSync() {
        // リモート変更通知の監視
        NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: nil,
            queue: .main
        ) { notification in
            print("Remote change notification received")
            // 必要に応じて、UIの更新や再読み込みをトリガー
            self.container.viewContext.performAndWait {
                // 何か特定のオブジェクトの変更を監視する場合は、ここで処理
            }
        }
        
        // 衝突解決ポリシーの設定
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // iCloudアカウント変更監視
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name.CKAccountChanged,
            object: nil,
            queue: .main
        ) { _ in
            print("iCloud account changed")
            // アカウント変更時の処理
            // 例：ユーザープロファイルの更新など
        }
    }
}
