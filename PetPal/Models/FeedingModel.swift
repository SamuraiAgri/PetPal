import Foundation
import CoreData
import SwiftUI
import CloudKit
import Combine

class FeedingViewModel: ObservableObject {
    @Published var feedingLogs: [FeedingLogModel] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let context: NSManagedObjectContext
    private let cloudKitManager = CloudKitManager()
    
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
    }
    
    // 特定ペットの給餌記録を取得
    func fetchFeedingLogs(for petId: UUID) {
        isLoading = true
        
        let request: NSFetchRequest<FeedingLog> = FeedingLog.fetchRequest()
        request.predicate = NSPredicate(format: "pet.id == %@", petId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FeedingLog.timestamp, ascending: false)]
        
        do {
            let fetchedLogs = try context.fetch(request)
            self.feedingLogs = fetchedLogs.map { FeedingLogModel(entity: $0) }
            isLoading = false
        } catch {
            errorMessage = "給餌記録の取得に失敗しました: \(error.localizedDescription)"
            print("Error fetching feeding logs: \(error)")
            isLoading = false
        }
    }
    
    // 給餌記録を追加
    func addFeedingLog(petId: UUID, foodType: String, amount: Double, unit: String, notes: String, performedBy: String) {
        isLoading = true
        
        // ペットエンティティを取得
        let petRequest: NSFetchRequest<Pet> = Pet.fetchRequest()
        petRequest.predicate = NSPredicate(format: "id == %@", petId as CVarArg)
        
        do {
            let pets = try context.fetch(petRequest)
            
            guard let pet = pets.first else {
                errorMessage = "ペットが見つかりませんでした"
                isLoading = false
                return
            }
            
            // 新規給餌記録作成
            let feedingLog = FeedingLog(context: context)
            feedingLog.id = UUID()
            feedingLog.foodType = foodType
            feedingLog.amount = amount
            feedingLog.unit = unit
            feedingLog.timestamp = Date()
            feedingLog.notes = notes
            feedingLog.performedBy = performedBy
            feedingLog.pet = pet
            
            try context.save()
            
            // CloudKit 同期
            let feedingLogModel = FeedingLogModel(entity: feedingLog)
            cloudKitManager.saveFeedingLog(feedingLogModel) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let recordID):
                        let recordIDString = "\(Constants.CloudKit.petZoneName):\(recordID.recordName)"
                        feedingLog.cloudKitRecordID = recordIDString
                        try? self.context.save()
                        
                    case .failure(let error):
                        print("CloudKit sync error for feeding log: \(error)")
                    }
                    
                    self.fetchFeedingLogs(for: petId)
                    self.isLoading = false
                }
            }
        } catch {
            errorMessage = "給餌記録の保存に失敗しました: \(error.localizedDescription)"
            print("Error saving feeding log: \(error)")
            isLoading = false
        }
    }
    
    // 給餌記録を削除
    func deleteFeedingLog(id: UUID) {
        let request: NSFetchRequest<FeedingLog> = FeedingLog.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            let results = try context.fetch(request)
            
            if let logToDelete = results.first {
                let petId = logToDelete.pet?.id
                
                context.delete(logToDelete)
                try context.save()
                
                if let petId = petId {
                    fetchFeedingLogs(for: petId)
                }
            }
        } catch {
            errorMessage = "給餌記録の削除に失敗しました: \(error.localizedDescription)"
            print("Error deleting feeding log: \(error)")
        }
    }
    
    // 期間指定で給餌記録を取得（統計用）
    func fetchFeedingLogsForPeriod(petId: UUID, from: Date, to: Date) -> [FeedingLogModel] {
        let request: NSFetchRequest<FeedingLog> = FeedingLog.fetchRequest()
        request.predicate = NSPredicate(format: "pet.id == %@ AND timestamp >= %@ AND timestamp <= %@",
                                         petId as CVarArg, from as CVarArg, to as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FeedingLog.timestamp, ascending: true)]
        
        do {
            let fetchedLogs = try context.fetch(request)
            return fetchedLogs.map { FeedingLogModel(entity: $0) }
        } catch {
            print("Error fetching feeding logs for period: \(error)")
            return []
        }
    }
    
    // 食事タイプ別の給餌回数を取得（統計用）
    func getFeedingCountsByType(petId: UUID, from: Date, to: Date) -> [String: Int] {
        let logs = fetchFeedingLogsForPeriod(petId: petId, from: from, to: to)
        var countsByType: [String: Int] = [:]
        
        for log in logs {
            let type = log.foodType
            countsByType[type, default: 0] += 1
        }
        
        return countsByType
    }
}

// FeedingLogModel 構造体
struct FeedingLogModel: Identifiable {
    var id: UUID
    var foodType: String
    var amount: Double
    var unit: String
    var timestamp: Date
    var notes: String
    var performedBy: String
    var cloudKitRecordID: String?
    var petId: UUID?
    
    // CoreDataエンティティからモデルを初期化
    init(entity: FeedingLog) {
        self.id = entity.id ?? UUID()
        self.foodType = entity.foodType ?? ""
        self.amount = entity.amount
        self.unit = entity.unit ?? "g"
        self.timestamp = entity.timestamp ?? Date()
        self.notes = entity.notes ?? ""
        self.performedBy = entity.performedBy ?? ""
        self.cloudKitRecordID = entity.cloudKitRecordID
        self.petId = entity.pet?.id
    }
    
    // 新規作成用の初期化
    init(foodType: String, amount: Double, unit: String = "g", notes: String = "", performedBy: String = "", petId: UUID? = nil) {
        self.id = UUID()
        self.foodType = foodType
        self.amount = amount
        self.unit = unit
        self.timestamp = Date()
        self.notes = notes
        self.performedBy = performedBy
        self.cloudKitRecordID = nil
        self.petId = petId
    }
}
