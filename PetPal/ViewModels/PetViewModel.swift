// PetPal/ViewModels/PetViewModel.swift の続き
import Foundation
import CoreData
import SwiftUI
import CloudKit
import Combine

class PetViewModel: ObservableObject {
    private let context: NSManagedObjectContext
    private let cloudKitManager = CloudKitManager()
    private var cancellables = Set<AnyCancellable>()
    
    // 状態管理
    @Published var pets: [PetModel] = []
    @Published var selectedPet: PetModel?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var syncStatus: SyncStatus = .idle
    
    enum SyncStatus {
        case idle, syncing, completed, failed
    }
    
    init(context: NSManagedObjectContext) {
        self.context = context
        fetchPets()
        
        // 30秒ごとに自動同期
        Timer.publish(every: Constants.CloudKit.syncInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.syncWithCloudKit()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - CRUD 操作
    
    // ペット一覧取得
    func fetchPets() {
        let request: NSFetchRequest<Pet> = Pet.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Pet.name, ascending: true)]
        request.predicate = NSPredicate(format: "isActive == %@", NSNumber(value: true))
        
        do {
            let fetchedPets = try context.fetch(request)
            self.pets = fetchedPets.map { PetModel(entity: $0) }
            
            // 選択中のペットがない場合は最初のペットを選択
            if selectedPet == nil && !pets.isEmpty {
                selectedPet = pets.first
            }
        } catch {
            errorMessage = "ペット情報の取得に失敗しました: \(error.localizedDescription)"
            print("Error fetching pets: \(error)")
        }
    }
    
    // ペット追加
    func addPet(name: String, species: String, breed: String, birthDate: Date, gender: String, iconImageData: Data?, notes: String) {
        let newPet = PetModel(
            name: name,
            species: species,
            breed: breed,
            birthDate: birthDate,
            gender: gender,
            iconImageData: iconImageData,
            notes: notes
        )
        
        savePet(newPet)
    }
    
    // ペット保存（新規または更新）
    func savePet(_ pet: PetModel) {
        isLoading = true
        
        // 既存のペットを検索
        let request: NSFetchRequest<Pet> = Pet.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", pet.id as CVarArg)
        
        do {
            let results = try context.fetch(request)
            let petEntity: Pet
            
            if let existingPet = results.first {
                // 既存のペットを更新
                petEntity = existingPet
            } else {
                // 新規ペットを作成
                petEntity = Pet(context: context)
                petEntity.id = pet.id
                petEntity.createdAt = Date()
            }
            
            // エンティティを更新
            pet.updateEntity(entity: petEntity)
            
            try context.save()
            
            // CloudKit同期 - CloudKitの実装がない場合はコメントアウト
            /*
            cloudKitManager.savePet(pet) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let recordID):
                        // CloudKitレコードIDを保存
                        let recordIDString = "\(Constants.CloudKit.petZoneName):\(recordID.recordName)"
                        petEntity.cloudKitRecordID = recordIDString
                        try? self?.context.save()
                        
                    case .failure(let error):
                        print("CloudKit sync error: \(error)")
                    }
                    
                    self?.fetchPets()
                    self?.isLoading = false
                }
            }
            */
            
            // CloudKit同期を省略してローカル更新のみ
            self.fetchPets()
            self.isLoading = false
            
        } catch {
            errorMessage = "ペット情報の保存に失敗しました: \(error.localizedDescription)"
            print("Error saving pet: \(error)")
            isLoading = false
        }
    }
    
    // ペット更新
    func updatePet(id: UUID, name: String, species: String, breed: String, birthDate: Date, gender: String, iconImageData: Data?, notes: String) {
        guard let index = pets.firstIndex(where: { $0.id == id }) else {
            errorMessage = "更新するペットが見つかりませんでした"
            return
        }
        
        var updatedPet = pets[index]
        updatedPet.name = name
        updatedPet.species = species
        updatedPet.breed = breed
        updatedPet.birthDate = birthDate
        updatedPet.gender = gender
        
        // アイコン画像が提供された場合のみ更新
        if let iconData = iconImageData {
            updatedPet.iconImageData = iconData
        }
        
        updatedPet.notes = notes
        updatedPet.updatedAt = Date()
        
        savePet(updatedPet)
        
        // 選択中のペットが更新対象の場合、選択ペットも更新
        if selectedPet?.id == id {
            selectedPet = updatedPet
        }
    }
    
    // ペット削除（論理削除）
    func deletePet(id: UUID) {
        let request: NSFetchRequest<Pet> = Pet.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            let results = try context.fetch(request)
            if let petToDelete = results.first {
                // 論理削除（物理削除ではなく、非アクティブにする）
                petToDelete.isActive = false
                petToDelete.updatedAt = Date()
                
                try context.save()
                
                // 選択中のペットが削除対象だった場合、選択を解除
                if selectedPet?.id == id {
                    if let firstActivePet = pets.first(where: { $0.id != id }) {
                        selectedPet = firstActivePet
                    } else {
                        selectedPet = nil
                    }
                }
                
                // リストを更新
                fetchPets()
            }
        } catch {
            errorMessage = "ペットの削除に失敗しました: \(error.localizedDescription)"
            print("Error deleting pet: \(error)")
        }
    }
    
    // ペット選択
    func selectPet(id: UUID) {
        if let pet = pets.first(where: { $0.id == id }) {
            selectedPet = pet
        }
    }
    
    // CloudKitとの同期
    func syncWithCloudKit() {
        syncStatus = .syncing
        
        cloudKitManager.fetchAllPets { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                switch result {
                case .success(let cloudPets):
                    self.mergePetsWithCloud(cloudPets: cloudPets)
                    self.syncStatus = .completed
                    
                    // 5秒後にステータスをリセット
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        if self.syncStatus == .completed {
                            self.syncStatus = .idle
                        }
                    }
                    
                case .failure(let error):
                    print("CloudKit sync error: \(error)")
                    self.syncStatus = .failed
                    
                    // 5秒後にステータスをリセット
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        if self.syncStatus == .failed {
                            self.syncStatus = .idle
                        }
                    }
                }
            }
        }
    }
    
    // ローカルデータとクラウドデータのマージ
    private func mergePetsWithCloud(cloudPets: [PetModel]) {
        // すべてのローカルペットを取得（非アクティブを含む）
        let request: NSFetchRequest<Pet> = Pet.fetchRequest()
        
        do {
            let localPetEntities = try context.fetch(request)
            let localPets = localPetEntities.map { PetModel(entity: $0) }
            
            // クラウドのペットを処理
            for cloudPet in cloudPets {
                if let localPet = localPets.first(where: { $0.id == cloudPet.id }) {
                    // 両方に存在する場合、最新の更新日を持つ方を採用
                    if cloudPet.updatedAt > localPet.updatedAt {
                        if let entity = localPetEntities.first(where: { $0.id == cloudPet.id }) {
                            cloudPet.updateEntity(entity: entity)
                        }
                    }
                } else {
                    // ローカルに存在しない場合は新規作成
                    let newEntity = Pet(context: context)
                    cloudPet.updateEntity(entity: newEntity)
                }
            }
            
            // ローカルのみに存在するペットのうち、CloudKit IDがあるものはクラウドにアップロード
            for localPet in localPets {
                if !cloudPets.contains(where: { $0.id == localPet.id }) && localPet.cloudKitRecordID == nil {
                    // CloudKit同期の部分はコメントアウト
                    /*
                    cloudKitManager.savePet(localPet) { _ in }
                    */
                }
            }
            
            try context.save()
            fetchPets()
            
        } catch {
            print("Error merging pets with cloud: \(error)")
            errorMessage = "クラウド同期中にエラーが発生しました"
        }
    }
}
