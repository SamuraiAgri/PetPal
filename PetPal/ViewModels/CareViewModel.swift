// PetPal/ViewModels/CareViewModel.swift
import Foundation
import CoreData
import SwiftUI
import CloudKit
import Combine

class CareViewModel: ObservableObject {
    @Published var careLogs: [CareLogModel] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let context: NSManagedObjectContext
    private let cloudKitManager = CloudKitManager()
    
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
    }
    
    // 特定ペットのケア記録を取得
    func fetchCareLogs(for petId: UUID) {
        isLoading = true
        
        let request: NSFetchRequest<CareLog> = CareLog.fetchRequest()
        request.predicate = NSPredicate(format: "pet.id == %@", petId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CareLog.timestamp, ascending: false)]
        
        do {
            let fetchedLogs = try context.fetch(request)
            self.careLogs = fetchedLogs.map { CareLogModel(entity: $0) }
            isLoading = false
        } catch {
            errorMessage = "ケア記録の取得に失敗しました: \(error.localizedDescription)"
            print("Error fetching care logs: \(error)")
            isLoading = false
        }
    }
    
    // ケア記録を追加
    func addCareLog(petId: UUID, type: String, notes: String, performedBy: String) {
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
            
            // 新規ケア記録作成
            let careLog = CareLog(context: context)
            careLog.id = UUID()
            careLog.type = type
            careLog.notes = notes
            careLog.timestamp = Date()
            careLog.performedBy = performedBy
            careLog.isCompleted = true
            careLog.pet = pet
            
            try context.save()
            
            // CloudKit 同期 - saveCareLogメソッドは未実装なのでコメントアウト
            /*
            let careLogModel = CareLogModel(entity: careLog)
            cloudKitManager.saveCareLog(careLogModel) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let recordID):
                        let recordIDString = "\(Constants.CloudKit.petZoneName):\(recordID.recordName)"
                        careLog.cloudKitRecordID = recordIDString
                        try? self.context.save()
                        
                    case .failure(let error):
                        print("CloudKit sync error for care log: \(error)")
                    }
                    
                    self.fetchCareLogs(for: petId)
                    self.isLoading = false
                }
            }
            */
            
            // CloudKit同期を省略してローカル更新のみ
            self.fetchCareLogs(for: petId)
            self.isLoading = false
            
        } catch {
            errorMessage = "ケア記録の保存に失敗しました: \(error.localizedDescription)"
            print("Error saving care log: \(error)")
            isLoading = false
        }
    }
    
    // ケア記録を削除
    func deleteCareLog(id: UUID) {
        let request: NSFetchRequest<CareLog> = CareLog.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            let results = try context.fetch(request)
            
            if let logToDelete = results.first {
                let petId = logToDelete.pet?.id
                
                context.delete(logToDelete)
                try context.save()
                
                if let petId = petId {
                    fetchCareLogs(for: petId)
                }
            }
        } catch {
            errorMessage = "ケア記録の削除に失敗しました: \(error.localizedDescription)"
            print("Error deleting care log: \(error)")
        }
    }
    
    // 複数タイプのケア記録をまとめて追加（一括登録用）
    func addMultipleCare(petId: UUID, types: [String], notes: String, performedBy: String) {
        isLoading = true
        
        let petRequest: NSFetchRequest<Pet> = Pet.fetchRequest()
        petRequest.predicate = NSPredicate(format: "id == %@", petId as CVarArg)
        
        do {
            let pets = try context.fetch(petRequest)
            
            guard let pet = pets.first else {
                errorMessage = "ペットが見つかりませんでした"
                isLoading = false
                return
            }
            
            for type in types {
                let careLog = CareLog(context: context)
                careLog.id = UUID()
                careLog.type = type
                careLog.notes = notes
                careLog.timestamp = Date()
                careLog.performedBy = performedBy
                careLog.isCompleted = true
                careLog.pet = pet
            }
            
            try context.save()
            
            // CloudKit同期は省略（実際には個別に同期処理を実行）
            
            fetchCareLogs(for: petId)
            isLoading = false
        } catch {
            errorMessage = "ケア記録の保存に失敗しました: \(error.localizedDescription)"
            print("Error saving multiple care logs: \(error)")
            isLoading = false
        }
    }
    
    // 期間指定でケア記録を取得（統計用）
    func fetchCareLogsForPeriod(petId: UUID, from: Date, to: Date) -> [CareLogModel] {
        let request: NSFetchRequest<CareLog> = CareLog.fetchRequest()
        request.predicate = NSPredicate(format: "pet.id == %@ AND timestamp >= %@ AND timestamp <= %@",
                                         petId as CVarArg, from as CVarArg, to as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CareLog.timestamp, ascending: true)]
        
        do {
            let fetchedLogs = try context.fetch(request)
            return fetchedLogs.map { CareLogModel(entity: $0) }
        } catch {
            print("Error fetching care logs for period: \(error)")
            return []
        }
    }
    
    // タイプ別のケア回数を取得（統計用）
    func getCareCountsByType(petId: UUID, from: Date, to: Date) -> [String: Int] {
        let logs = fetchCareLogsForPeriod(petId: petId, from: from, to: to)
        var countsByType: [String: Int] = [:]
        
        for log in logs {
            let type = log.type
            countsByType[type, default: 0] += 1
        }
        
        return countsByType
    }
}
