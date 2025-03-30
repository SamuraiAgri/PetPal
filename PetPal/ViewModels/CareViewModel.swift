// PetPal/ViewModels/CareViewModel.swift
import Foundation
import CoreData
import SwiftUI
import CloudKit
import Combine

class CareViewModel: ObservableObject {
    @Published var careLogs: [CareLogModel] = []
    @Published var careSchedules: [CareScheduleModel] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let context: NSManagedObjectContext
    private let cloudKitManager = CloudKitManager()
    
    // UserProfileViewModelへの参照
    private let userProfileViewModel: UserProfileViewModel
    
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext,
         userProfileViewModel: UserProfileViewModel) {
        self.context = context
        self.userProfileViewModel = userProfileViewModel
    }
    
    // 特定ペットのケア記録を取得
    func fetchCareLogs(for petId: UUID) {
        isLoading = true
        
        let request: NSFetchRequest<CareLog> = CareLog.fetchRequest()
        request.predicate = NSPredicate(format: "pet.id == %@", petId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CareLog.timestamp, ascending: false)]
        
        do {
            let fetchedLogs = try context.fetch(request)
            var logs = fetchedLogs.map { CareLogModel(entity: $0) }
            
            // ユーザープロファイル情報を追加
            for i in 0..<logs.count {
                if let userProfileID = logs[i].userProfileID {
                    logs[i].userProfile = userProfileViewModel.userProfiles.first(where: { $0.id == userProfileID })
                }
                if let assignedUserProfileID = logs[i].assignedUserProfileID {
                    logs[i].assignedUserProfile = userProfileViewModel.userProfiles.first(where: { $0.id == assignedUserProfileID })
                }
            }
            
            self.careLogs = logs
            isLoading = false
        } catch {
            errorMessage = "ケア記録の取得に失敗しました: \(error.localizedDescription)"
            print("Error fetching care logs: \(error)")
            isLoading = false
        }
    }
    
    // 特定ペットのケアスケジュールを取得
    func fetchCareSchedules(for petId: UUID) {
        isLoading = true
        
        let request: NSFetchRequest<CareSchedule> = CareSchedule.fetchRequest()
        request.predicate = NSPredicate(format: "pet.id == %@", petId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CareSchedule.scheduledDate, ascending: true)]
        
        do {
            let fetchedSchedules = try context.fetch(request)
            var schedules = fetchedSchedules.map { CareScheduleModel(entity: $0) }
            
            // ユーザープロファイル情報を追加
            for i in 0..<schedules.count {
                if let userProfileID = schedules[i].assignedUserProfileID {
                    schedules[i].assignedUserProfile = userProfileViewModel.userProfiles.first(where: { $0.id == userProfileID })
                }
                if let createdByID = schedules[i].createdBy {
                    schedules[i].createdByProfile = userProfileViewModel.userProfiles.first(where: { $0.id == createdByID })
                }
            }
            
            self.careSchedules = schedules
            isLoading = false
        } catch {
            errorMessage = "ケアスケジュールの取得に失敗しました: \(error.localizedDescription)"
            print("Error fetching care schedules: \(error)")
            isLoading = false
        }
    }
    
    // ケア記録を追加
    func addCareLog(petId: UUID, type: String, notes: String, performedBy: String = "") {
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
            
            // 現在のユーザープロファイルを使用
            let currentUserID = userProfileViewModel.currentUser?.id
            
            // 新規ケア記録作成
            let careLog = CareLog(context: context)
            careLog.id = UUID()
            careLog.type = type
            careLog.notes = notes
            careLog.timestamp = Date()
            careLog.performedBy = performedBy.isEmpty ? (userProfileViewModel.currentUser?.name ?? UIDevice.current.name) : performedBy
            careLog.isCompleted = true
            careLog.isScheduled = false
            careLog.pet = pet
            careLog.userProfileID = currentUserID
            
            try context.save()
            
            // CloudKit 同期
            let careLogModel = CareLogModel(entity: careLog)
            cloudKitManager.saveCareLog(careLogModel) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let recordID):
                        let recordIDString = "\(Constants.CloudKit.careZoneName):\(recordID.recordName)"
                        careLog.cloudKitRecordID = recordIDString
                        try? self.context.save()
                        
                    case .failure(let error):
                        print("CloudKit sync error for care log: \(error)")
                    }
                    
                    self.fetchCareLogs(for: petId)
                    self.isLoading = false
                }
            }
        } catch {
            errorMessage = "ケア記録の保存に失敗しました: \(error.localizedDescription)"
            print("Error saving care log: \(error)")
            isLoading = false
        }
    }
    
    // スケジュールからケア記録を追加（スケジュール完了時）
    func completeCareSchedule(schedule: CareScheduleModel) {
        isLoading = true
        
        // ペットエンティティを取得
        let petRequest: NSFetchRequest<Pet> = Pet.fetchRequest()
        petRequest.predicate = NSPredicate(format: "id == %@", schedule.petId as CVarArg ?? "")
        
        do {
            let pets = try context.fetch(petRequest)
            
            guard let pet = pets.first else {
                errorMessage = "ペットが見つかりませんでした"
                isLoading = false
                return
            }
            
            // 現在のユーザープロファイルを使用
            let currentUserID = userProfileViewModel.currentUser?.id
            
            // スケジュールを完了に更新
            let scheduleRequest: NSFetchRequest<CareSchedule> = CareSchedule.fetchRequest()
            scheduleRequest.predicate = NSPredicate(format: "id == %@", schedule.id as CVarArg)
            
            if let careSchedule = try context.fetch(scheduleRequest).first {
                careSchedule.isCompleted = true
                careSchedule.completedBy = currentUserID
                careSchedule.completedDate = Date()
                careSchedule.updatedAt = Date()
                
                // 新規ケア記録作成（完了履歴として）
                let careLog = CareLog(context: context)
                careLog.id = UUID()
                careLog.type = schedule.type
                careLog.notes = schedule.notes
                careLog.timestamp = Date()
                careLog.performedBy = userProfileViewModel.currentUser?.name ?? UIDevice.current.name
                careLog.isCompleted = true
                careLog.isScheduled = false
                careLog.pet = pet
                careLog.userProfileID = currentUserID
                careLog.assignedUserProfileID = schedule.assignedUserProfileID
                
                try context.save()
                
                // CloudKit 同期（スケジュールの更新）
                var updatedSchedule = schedule
                updatedSchedule.markAsCompleted(byUserID: currentUserID ?? UUID())
                
                cloudKitManager.updateCareSchedule(updatedSchedule) { _ in
                    // ログも同期
                    let careLogModel = CareLogModel(entity: careLog)
                    self.cloudKitManager.saveCareLog(careLogModel) { _ in
                        DispatchQueue.main.async {
                            self.fetchCareLogs(for: pet.id ?? UUID())
                            self.fetchCareSchedules(for: pet.id ?? UUID())
                            self.isLoading = false
                        }
                    }
                }
            } else {
                errorMessage = "スケジュールが見つかりませんでした"
                isLoading = false
            }
        } catch {
            errorMessage = "スケジュール完了の処理に失敗しました: \(error.localizedDescription)"
            print("Error completing care schedule: \(error)")
            isLoading = false
        }
    }
    
    // ケアスケジュールを追加
    func addCareSchedule(petId: UUID, type: String, scheduledDate: Date, assignedUserProfileID: UUID? = nil, notes: String = "") {
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
            
            // 現在のユーザープロファイルを使用
            let currentUserID = userProfileViewModel.currentUser?.id
            
            // 新規ケアスケジュール作成
            let careSchedule = CareSchedule(context: context)
            careSchedule.id = UUID()
            careSchedule.type = type
            careSchedule.scheduledDate = scheduledDate
            careSchedule.assignedUserProfileID = assignedUserProfileID
            careSchedule.notes = notes
            careSchedule.isCompleted = false
            careSchedule.createdBy = currentUserID
            careSchedule.createdAt = Date()
            careSchedule.updatedAt = Date()
            careSchedule.pet = pet
            
            try context.save()
            
            // CloudKit 同期
            let scheduleModel = CareScheduleModel(entity: careSchedule)
            cloudKitManager.saveCareSchedule(scheduleModel) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let recordID):
                        let recordIDString = "\(Constants.CloudKit.careZoneName):\(recordID.recordName)"
                        careSchedule.cloudKitRecordID = recordIDString
                        try? self.context.save()
                        
                    case .failure(let error):
                        print("CloudKit sync error for care schedule: \(error)")
                    }
                    
                    self.fetchCareSchedules(for: petId)
                    self.isLoading = false
                }
            }
            
            // 関連するユーザーに通知
            if let assignedUserID = assignedUserProfileID, assignedUserID != currentUserID {
                self.notifyUserAboutSchedule(petID: petId, userID: assignedUserID, scheduledDate: scheduledDate, type: type)
            }
        } catch {
            errorMessage = "ケアスケジュールの保存に失敗しました: \(error.localizedDescription)"
            print("Error saving care schedule: \(error)")
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
    
    // ケアスケジュールを削除
    func deleteCareSchedule(id: UUID) {
        let request: NSFetchRequest<CareSchedule> = CareSchedule.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            let results = try context.fetch(request)
            
            if let scheduleToDelete = results.first {
                let petId = scheduleToDelete.pet?.id
                
                context.delete(scheduleToDelete)
                try context.save()
                
                if let petId = petId {
                    fetchCareSchedules(for: petId)
                }
            }
        } catch {
            errorMessage = "ケアスケジュールの削除に失敗しました: \(error.localizedDescription)"
            print("Error deleting care schedule: \(error)")
        }
    }
    
    // 複数タイプのケア記録をまとめて追加（一括登録用）
    func addMultipleCare(petId: UUID, types: [String], notes: String, performedBy: String = "") {
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
            
            // 現在のユーザープロファイルを使用
            let currentUserID = userProfileViewModel.currentUser?.id
            let currentUserName = userProfileViewModel.currentUser?.name ?? UIDevice.current.name
            
            for type in types {
                let careLog = CareLog(context: context)
                careLog.id = UUID()
                careLog.type = type
                careLog.notes = notes
                careLog.timestamp = Date()
                careLog.performedBy = performedBy.isEmpty ? currentUserName : performedBy
                careLog.isCompleted = true
                careLog.isScheduled = false
                careLog.pet = pet
                careLog.userProfileID = currentUserID
            }
            
            try context.save()
            
            // CloudKit同期は個別に実行する代わりに、バッチ処理を実装すると効率的
            
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
        request.predicate = NSPredicate(format: "pet.id == %@ AND timestamp >= %@ AND timestamp <= %@ AND isScheduled == %@",
                                         petId as CVarArg, from as CVarArg, to as CVarArg, false as NSNumber)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CareLog.timestamp, ascending: true)]
        
        do {
            let fetchedLogs = try context.fetch(request)
            var logs = fetchedLogs.map { CareLogModel(entity: $0) }
            
            // ユーザープロファイル情報を追加
            for i in 0..<logs.count {
                if let userProfileID = logs[i].userProfileID {
                    logs[i].userProfile = userProfileViewModel.userProfiles.first(where: { $0.id == userProfileID })
                }
            }
            
            return logs
        } catch {
            print("Error fetching care logs for period: \(error)")
            return []
        }
    }
    
    // 今日のケアスケジュールを取得
    func fetchTodaySchedules(petId: UUID) -> [CareScheduleModel] {
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!.addingTimeInterval(-1)
        
        let request: NSFetchRequest<CareSchedule> = CareSchedule.fetchRequest()
        request.predicate = NSPredicate(format: "pet.id == %@ AND scheduledDate >= %@ AND scheduledDate <= %@ AND isCompleted == %@",
                                         petId as CVarArg, startOfDay as CVarArg, endOfDay as CVarArg, false as NSNumber)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CareSchedule.scheduledDate, ascending: true)]
        
        do {
            let fetchedSchedules = try context.fetch(request)
            var schedules = fetchedSchedules.map { CareScheduleModel(entity: $0) }
            
            // ユーザープロファイル情報を追加
            for i in 0..<schedules.count {
                if let userProfileID = schedules[i].assignedUserProfileID {
                    schedules[i].assignedUserProfile = userProfileViewModel.userProfiles.first(where: { $0.id == userProfileID })
                }
            }
            
            return schedules
        } catch {
            print("Error fetching today's schedules: \(error)")
            return []
        }
    }
    
    // 特定ユーザーのケアスケジュールを取得
    func fetchUserSchedules(userProfileId: UUID, petId: UUID? = nil) -> [CareScheduleModel] {
        let request: NSFetchRequest<CareSchedule> = CareSchedule.fetchRequest()
        
        var predicates = [NSPredicate(format: "assignedUserProfileID == %@ AND isCompleted == %@", userProfileId as CVarArg, false as NSNumber)]
        
        if let petId = petId {
            predicates.append(NSPredicate(format: "pet.id == %@", petId as CVarArg))
        }
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CareSchedule.scheduledDate, ascending: true)]
        
        do {
            let fetchedSchedules = try context.fetch(request)
            var schedules = fetchedSchedules.map { CareScheduleModel(entity: $0) }
            
            // ユーザープロファイル情報を追加
            for i in 0..<schedules.count {
                if let userProfileID = schedules[i].assignedUserProfileID {
                    schedules[i].assignedUserProfile = userProfileViewModel.userProfiles.first(where: { $0.id == userProfileID })
                }
                if let createdByID = schedules[i].createdBy {
                    schedules[i].createdByProfile = userProfileViewModel.userProfiles.first(where: { $0.id == createdByID })
                }
            }
            
            return schedules
        } catch {
            print("Error fetching user schedules: \(error)")
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
    
    // ユーザー別のケア回数を取得（統計用）
    func getCareCountsByUser(petId: UUID, from: Date, to: Date) -> [(userID: UUID, name: String, count: Int, color: String)] {
        let logs = fetchCareLogsForPeriod(petId: petId, from: from, to: to)
        var countsByUser: [UUID: (name: String, count: Int, color: String)] = [:]
        
        for log in logs {
            if let userID = log.userProfileID, let userProfile = log.userProfile {
                let userName = userProfile.name
                let userColor = userProfile.colorHex
                
                if let existingData = countsByUser[userID] {
                    countsByUser[userID] = (existingData.name, existingData.count + 1, existingData.color)
                } else {
                    countsByUser[userID] = (userName, 1, userColor)
                }
            }
        }
        
        return countsByUser.map { (userID: $0.key, name: $0.value.name, count: $0.value.count, color: $0.value.color) }
            .sorted { $0.count > $1.count }
    }
    
    // 担当ユーザーに通知
    private func notifyUserAboutSchedule(petID: UUID, userID: UUID, scheduledDate: Date, type: String) {
        // ローカル通知の設定
        if let userProfile = userProfileViewModel.userProfiles.first(where: { $0.id == userID }) {
            let petRequest: NSFetchRequest<Pet> = Pet.fetchRequest()
            petRequest.predicate = NSPredicate(format: "id == %@", petID as CVarArg)
            
            do {
                if let pet = try context.fetch(petRequest).first {
                    let petName = pet.name ?? "ペット"
                    
                    // 通知リクエストを作成
                    let content = UNMutableNotificationContent()
                    content.title = "\(type)の担当になりました"
                    content.body = "\(petName)の\(type)担当に設定されました。予定: \(scheduledDate.formattedDateTime)"
                    content.sound = .default
                    content.categoryIdentifier = Constants.Notification.careAssignmentCategory
                    content.userInfo = ["petId": petID.uuidString, "scheduleDate": scheduledDate]
                    
                    // 通知のタイミング設定（即時と予定時刻の10分前）
                    // 即時通知
                    let immediateRequest = UNNotificationRequest(
                        identifier: UUID().uuidString,
                        content: content,
                        trigger: nil // 即時通知
                    )
                    
                    // 予定時刻の通知（設定されてから30分以上先の場合）
                    let timeInterval = scheduledDate.timeIntervalSince(Date())
                    if timeInterval > (30 * 60) { // 30分以上先なら
                        let reminderDate = scheduledDate.addingTimeInterval(-1 * Double(Constants.CareSchedule.reminderTimeBeforeCare * 60))
                        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
                        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                        
                        let reminderRequest = UNNotificationRequest(
                            identifier: UUID().uuidString,
                            content: content,
                            trigger: trigger
                        )
                        
                        UNUserNotificationCenter.current().add(reminderRequest) { error in
                            if let error = error {
                                print("リマインダー通知の設定に失敗: \(error)")
                            }
                        }
                    }
                    
                    UNUserNotificationCenter.current().add(immediateRequest) { error in
                        if let error = error {
                            print("即時通知の設定に失敗: \(error)")
                        }
                    }
                }
            } catch {
                print("ペット情報の取得に失敗: \(error)")
            }
        }
    }
}

// CloudKitManagerの拡張（CareSchedule関連）
extension CloudKitManager {
    // ケアスケジュール保存
    func saveCareSchedule(_ schedule: CareScheduleModel, completion: @escaping (Result<CKRecord.ID, Error>) -> Void) {
        let record = schedule.toCloudKitRecord()
        
        privateDatabase.save(record) { (record: CKRecord?, error: Error?) in
            if let error = error {
                completion(.failure(error))
            } else if let record = record {
                completion(.success(record.recordID))
            } else {
                completion(.failure(NSError(domain: "CloudKitManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "スケジュールの保存に失敗しました"])))
            }
        }
    }
    
    // ケアスケジュール更新
    func updateCareSchedule(_ schedule: CareScheduleModel, completion: @escaping (Result<CKRecord.ID, Error>) -> Void) {
        // 基本的にsaveCareScheduleと同じ処理だが、将来的な拡張性のために別メソッドとして定義
        saveCareSchedule(schedule, completion: completion)
    }
}
