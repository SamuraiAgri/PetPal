// PetPal/ViewModels/FeedingViewModel.swift
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
        request.predicate = NSPredicate(format: "ANY pet.id == %@", petId as CVarArg)
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
            
            // NSSetの追加方法に修正
            feedingLog.addToPet(pet)
            
            try context.save()
            
            // CloudKit 同期 - saveFeedingLogメソッドは未実装なのでコメントアウト
            /*
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
            */
            
            // CloudKit同期を省略してローカル更新のみ
            self.fetchFeedingLogs(for: petId)
            self.isLoading = false
            
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
                // ペットIDの取得方法を修正
                var petId: UUID? = nil
                if let pets = logToDelete.pet?.allObjects as? [Pet], let firstPet = pets.first {
                    petId = firstPet.id
                }
                
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
        request.predicate = NSPredicate(format: "ANY pet.id == %@ AND timestamp >= %@ AND timestamp <= %@",
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
    
    // 一日の給餌合計量を取得（統計用）
    func getDailyFeedingAmount(petId: UUID, date: Date) -> [(foodType: String, amount: Double, unit: String)] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!.addingTimeInterval(-1)
        
        let logs = fetchFeedingLogsForPeriod(petId: petId, from: startOfDay, to: endOfDay)
        
        // 食事タイプとユニットでグループ化
        var groupedLogs: [String: [(amount: Double, unit: String)]] = [:]
        
        for log in logs {
            let key = log.foodType
            if groupedLogs[key] == nil {
                groupedLogs[key] = []
            }
            groupedLogs[key]?.append((log.amount, log.unit))
        }
        
        // 各グループの合計を計算
        var results: [(foodType: String, amount: Double, unit: String)] = []
        
        for (foodType, logs) in groupedLogs {
            // 同じユニットの合計を計算
            var unitTotals: [String: Double] = [:]
            
            for log in logs {
                unitTotals[log.unit, default: 0] += log.amount
            }
            
            // 結果を追加
            for (unit, total) in unitTotals {
                results.append((foodType: foodType, amount: total, unit: unit))
            }
        }
        
        return results
    }
}
