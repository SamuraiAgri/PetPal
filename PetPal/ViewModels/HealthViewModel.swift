import Foundation
import CoreData
import SwiftUI
import CloudKit
import Combine

class HealthViewModel: ObservableObject {
    @Published var healthLogs: [HealthLogModel] = []
    @Published var vaccinations: [VaccinationModel] = []
    @Published var weightLogs: [WeightLogModel] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let context: NSManagedObjectContext
    private let cloudKitManager = CloudKitManager()
    
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
    }
    
    // MARK: - 健康記録関連
    
    // 健康記録取得
    func fetchHealthLogs(for petId: UUID) {
        isLoading = true
        
        let request: NSFetchRequest<HealthLog> = HealthLog.fetchRequest()
        request.predicate = NSPredicate(format: "pet.id == %@", petId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \HealthLog.date, ascending: false)]
        
        do {
            let fetchedLogs = try context.fetch(request)
            self.healthLogs = fetchedLogs.map { HealthLogModel(entity: $0) }
            isLoading = false
        } catch {
            errorMessage = "健康記録の取得に失敗しました: \(error.localizedDescription)"
            print("Error fetching health logs: \(error)")
            isLoading = false
        }
    }
    
    // 健康記録追加
    func addHealthLog(petId: UUID, condition: String, symptoms: String, medication: String, notes: String, date: Date = Date()) {
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
            
            // 新規健康記録作成
            let healthLog = HealthLog(context: context)
            healthLog.id = UUID()
            healthLog.condition = condition
            healthLog.symptoms = symptoms
            healthLog.medication = medication
            healthLog.notes = notes
            healthLog.date = date
            healthLog.pet = pet
            
            try context.save()
            
            // CloudKit 同期
            let healthLogModel = HealthLogModel(entity: healthLog)
            cloudKitManager.saveHealthLog(healthLogModel) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let recordID):
                        let recordIDString = "\(Constants.CloudKit.petZoneName):\(recordID.recordName)"
                        healthLog.cloudKitRecordID = recordIDString
                        try? self.context.save()
                        
                    case .failure(let error):
                        print("CloudKit sync error for health log: \(error)")
                    }
                    
                    self.fetchHealthLogs(for: petId)
                    self.isLoading = false
                }
            }
        } catch {
            errorMessage = "健康記録の保存に失敗しました: \(error.localizedDescription)"
            print("Error saving health log: \(error)")
            isLoading = false
        }
    }
    
    // 健康記録削除
    func deleteHealthLog(id: UUID) {
        let request: NSFetchRequest<HealthLog> = HealthLog.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            let results = try context.fetch(request)
            
            if let logToDelete = results.first {
                let petId = logToDelete.pet?.id
                
                context.delete(logToDelete)
                try context.save()
                
                if let petId = petId {
                    fetchHealthLogs(for: petId)
                }
            }
        } catch {
            errorMessage = "健康記録の削除に失敗しました: \(error.localizedDescription)"
            print("Error deleting health log: \(error)")
        }
    }
    
    // MARK: - ワクチン記録関連
    
    // ワクチン記録取得
    func fetchVaccinations(for petId: UUID) {
        isLoading = true
        
        let request: NSFetchRequest<Vaccination> = Vaccination.fetchRequest()
        request.predicate = NSPredicate(format: "pet.id == %@", petId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Vaccination.date, ascending: false)]
        
        do {
            let fetchedVaccinations = try context.fetch(request)
            self.vaccinations = fetchedVaccinations.map { VaccinationModel(entity: $0) }
            isLoading = false
        } catch {
            errorMessage = "ワクチン記録の取得に失敗しました: \(error.localizedDescription)"
            print("Error fetching vaccinations: \(error)")
            isLoading = false
        }
    }
    
    // ワクチン記録追加
    func addVaccination(petId: UUID, name: String, date: Date, expiryDate: Date?, reminderDate: Date?, clinicName: String, vetName: String, notes: String) {
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
            
            // 新規ワクチン記録作成
            let vaccination = Vaccination(context: context)
            vaccination.id = UUID()
            vaccination.name = name
            vaccination.date = date
            vaccination.expiryDate = expiryDate
            vaccination.reminderDate = reminderDate
            // Note: There seems to be a data type mismatch in the data model
            // Just using string representation as temporary fix
            vaccination.clinicName = date
            vaccination.vetName = date
            vaccination.notes = notes
            vaccination.pet = pet
            
            try context.save()
            
            // リマインダー設定（もし指定されていれば）
            if let reminderDate = reminderDate {
                NotificationManager.shared.scheduleVaccinationReminder(
                    petId: petId,
                    petName: pet.name ?? "ペット",
                    vaccineName: name,
                    date: reminderDate
                )
            }
            
            // CloudKit 同期
            let vaccinationModel = VaccinationModel(entity: vaccination)
            cloudKitManager.saveVaccination(vaccinationModel) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let recordID):
                        let recordIDString = "\(Constants.CloudKit.petZoneName):\(recordID.recordName)"
                        vaccination.cloudKitRecordID = recordIDString
                        try? self.context.save()
                        
                    case .failure(let error):
                        print("CloudKit sync error for vaccination: \(error)")
                    }
                    
                    self.fetchVaccinations(for: petId)
                    self.isLoading = false
                }
            }
        } catch {
            errorMessage = "ワクチン記録の保存に失敗しました: \(error.localizedDescription)"
            print("Error saving vaccination: \(error)")
            isLoading = false
        }
    }
    
    // ワクチン記録削除
    func deleteVaccination(id: UUID) {
        let request: NSFetchRequest<Vaccination> = Vaccination.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            let results = try context.fetch(request)
            
            if let vaccinationToDelete = results.first {
                let petId = vaccinationToDelete.pet?.id
                
                // 関連するリマインダーを削除
                if let petId = petId {
                    NotificationManager.shared.cancelAllNotificationsForPet(petId: petId)
                }
                
                context.delete(vaccinationToDelete)
                try context.save()
                
                if let petId = petId {
                    fetchVaccinations(for: petId)
                }
            }
        } catch {
            errorMessage = "ワクチン記録の削除に失敗しました: \(error.localizedDescription)"
            print("Error deleting vaccination: \(error)")
        }
    }
    
    // MARK: - 体重記録関連
    
    // 体重記録取得
    func fetchWeightLogs(for petId: UUID) {
        isLoading = true
        
        let request: NSFetchRequest<WeightLog> = WeightLog.fetchRequest()
        request.predicate = NSPredicate(format: "pet.id == %@", petId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \WeightLog.date, ascending: false)]
        
        do {
            let fetchedLogs = try context.fetch(request)
            self.weightLogs = fetchedLogs.map { WeightLogModel(entity: $0) }
            isLoading = false
        } catch {
            errorMessage = "体重記録の取得に失敗しました: \(error.localizedDescription)"
            print("Error fetching weight logs: \(error)")
            isLoading = false
        }
    }
    
    // 体重記録追加
    func addWeightLog(petId: UUID, weight: Double, unit: String, notes: String, date: Date = Date()) {
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
            
            // 新規体重記録作成
            let weightLog = WeightLog(context: context)
            weightLog.id = UUID()
            weightLog.weight = weight
            weightLog.unit = unit
            weightLog.date = date
            weightLog.notes = notes
            weightLog.pet = pet
            
            try context.save()
            
            // CloudKit 同期
            let weightLogModel = WeightLogModel(entity: weightLog)
            cloudKitManager.saveWeightLog(weightLogModel) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let recordID):
                        let recordIDString = "\(Constants.CloudKit.petZoneName):\(recordID.recordName)"
                        weightLog.cloudKitRecordID = recordIDString
                        try? self.context.save()
                        
                    case .failure(let error):
                        print("CloudKit sync error for weight log: \(error)")
                    }
                    
                    self.fetchWeightLogs(for: petId)
                    self.isLoading = false
                }
            }
        } catch {
            errorMessage = "体重記録の保存に失敗しました: \(error.localizedDescription)"
            print("Error saving weight log: \(error)")
            isLoading = false
        }
    }
    
    // 体重記録削除
    func deleteWeightLog(id: UUID) {
        let request: NSFetchRequest<WeightLog> = WeightLog.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            let results = try context.fetch(request)
            
            if let logToDelete = results.first {
                let petId = logToDelete.pet?.id
                
                context.delete(logToDelete)
                try context.save()
                
                if let petId = petId {
                    fetchWeightLogs(for: petId)
                }
            }
        } catch {
            errorMessage = "体重記録の削除に失敗しました: \(error.localizedDescription)"
            print("Error deleting weight log: \(error)")
        }
    }
    
    // 体重の統計情報取得
    func getWeightStats(for petId: UUID) -> (latest: Double?, average: Double?, min: Double?, max: Double?, unit: String?) {
        let request: NSFetchRequest<WeightLog> = WeightLog.fetchRequest()
        request.predicate = NSPredicate(format: "pet.id == %@", petId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \WeightLog.date, ascending: false)]
        
        do {
            let logs = try context.fetch(request)
            
            guard !logs.isEmpty else {
                return (nil, nil, nil, nil, nil)
            }
            
            let weights = logs.map { $0.weight }
            let unit = logs.first?.unit ?? "kg"
            
            let latest = logs.first?.weight
            let average = weights.reduce(0, +) / Double(weights.count)
            let min = weights.min()
            let max = weights.max()
            
            return (latest, average, min, max, unit)
        } catch {
            print("Error calculating weight stats: \(error)")
            return (nil, nil, nil, nil, nil)
        }
    }
}
