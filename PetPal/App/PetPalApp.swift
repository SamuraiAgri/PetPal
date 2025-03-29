import SwiftUI

@main
struct PetPalApp: App {
    let persistenceController = PersistenceController.shared
    
    var body: some Scene {
        WindowGroup {
            MainTabView(context: persistenceController.container.viewContext)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}

// Core Data の永続化コントローラ
struct PersistenceController {
    static let shared = PersistenceController()
    
    // プレビュー用のインスタンス
    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // サンプルデータの作成
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
            container.persistentStoreDescriptions.first!.url = URL(file
                                                                   init(inMemory: Bool = false) {
                                                                           container = NSPersistentCloudKitContainer(name: "PetPal")
                                                                           
                                                                           if inMemory {
                                                                               container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
                                                                           }
                                                                           
                                                                           // CloudKit同期の設定
                                                                           guard let description = container.persistentStoreDescriptions.first else {
                                                                               fatalError("Failed to retrieve a persistent store description.")
                                                                           }
                                                                           
                                                                           description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                                                                               containerIdentifier: Constants.CloudKit.containerIdentifier
                                                                           )
                                                                           
                                                                           // 自動マージポリシーの設定
                                                                           description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
                                                                           description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
                                                                           
                                                                           container.loadPersistentStores { (_, error) in
                                                                               if let error = error as NSError? {
                                                                                   // CloudKit同期に失敗してもローカルでは動作するように、エラーはログだけ残す
                                                                                   print("Persistent store loading error: \(error), \(error.userInfo)")
                                                                               }
                                                                           }
                                                                           
                                                                           container.viewContext.automaticallyMergesChangesFromParent = true
                                                                           container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
                                                                       }
                                                                   }
