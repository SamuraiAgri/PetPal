import Foundation
import CloudKit
import Combine

class CloudKitSyncViewModel: ObservableObject {
    @Published var syncStatus: SyncStatus = .idle
    @Published var lastSyncDate: Date?
    @Published var errorMessage: String?
    
    private let cloudKitManager = CloudKitManager()
    private var cancellables = Set<AnyCancellable>()
    
    enum SyncStatus {
        case idle, syncing, completed, failed
    }
    
    init() {
        // 自動同期タイマーの設定
        Timer.publish(every: Constants.CloudKit.syncInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.syncAllData()
            }
            .store(in: &cancellables)
    }
    
    // 全データ同期
    func syncAllData() {
        syncStatus = .syncing
        
        // 同期処理（非同期処理の連鎖）
        syncPets()
    }
    
    // ペットデータの同期
    private func syncPets() {
        cloudKitManager.fetchAllPets { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let cloudPets):
                // ペットデータの同期処理は PetViewModel で実装済み
                print("ペットデータ同期: \(cloudPets.count)件取得")
                self.syncCareLogs()
                
            case .failure(let error):
                self.handleSyncError(error)
            }
        }
    }
    
    // ケア記録の同期
    private func syncCareLogs() {
        // 実際には全ペットのケア記録を取得する処理
        // 今回は簡易実装のため省略し、次の同期処理へ
        syncFeedingLogs()
    }
    
    // 給餌記録の同期
    private func syncFeedingLogs() {
        // 実際には全ペットの給餌記録を取得する処理
        // 今回は簡易実装のため省略し、次の同期処理へ
        syncHealthLogs()
    }
    
    // 健康記録の同期
    private func syncHealthLogs() {
        // 実際には全ペットの健康記録を取得する処理
        // 今回は簡易実装のため省略し、次の同期処理へ
        syncVaccinations()
    }
    
    // ワクチン記録の同期
    private func syncVaccinations() {
        // 実際には全ペットのワクチン記録を取得する処理
        // 今回は簡易実装のため省略し、次の同期処理へ
        syncWeightLogs()
    }
    
    // 体重記録の同期
    private func syncWeightLogs() {
        // 実際には全ペットの体重記録を取得する処理
        // 今回は簡易実装のため省略し、同期完了
        syncCompleted()
    }
    
    // 同期完了処理
    private func syncCompleted() {
        DispatchQueue.main.async {
            self.syncStatus = .completed
            self.lastSyncDate = Date()
            
            // 5秒後にステータスをリセット
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                if self.syncStatus == .completed {
                    self.syncStatus = .idle
                }
            }
        }
    }
    
    // 同期エラー処理
    private func handleSyncError(_ error: Error) {
        DispatchQueue.main.async {
            self.syncStatus = .failed
            self.errorMessage = "同期エラー: \(error.localizedDescription)"
            
            // 5秒後にステータスをリセット
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                if self.syncStatus == .failed {
                    self.syncStatus = .idle
                }
            }
        }
    }
}
