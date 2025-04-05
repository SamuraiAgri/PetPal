import SwiftUI
import CloudKit

@main
struct PetPalApp: App {
    let persistenceController = PersistenceController.shared
    
    init() {
        // アプリ起動時にゾーンを作成
        createCloudKitZones()
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView(context: persistenceController.container.viewContext)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
    
    // CloudKitゾーン作成関数
    private func createCloudKitZones() {
        print("CloudKitゾーンの作成を開始...")
        
        let container = CKContainer(identifier: Constants.CloudKit.containerIdentifier)
        let database = container.privateCloudDatabase
        
        // 作成するゾーン
        let zones = [
            CKRecordZone(zoneName: Constants.CloudKit.petZoneName),
            CKRecordZone(zoneName: Constants.CloudKit.userZoneName),
            CKRecordZone(zoneName: Constants.CloudKit.careZoneName)
        ]
        
        // 個別にゾーンを作成（エラー処理のため）
        for zone in zones {
            database.save(zone) { savedZone, error in
                if let error = error {
                    if let ckError = error as? CKError {
                        if ckError.code == .zoneNotFound {
                            print("❌ ゾーン '\(zone.zoneID.zoneName)' が見つかりません: \(error.localizedDescription)")
                        } else if ckError.code == .serverRejectedRequest {
                            print("❌ サーバーがリクエストを拒否しました: \(error.localizedDescription)")
                        } else {
                            print("❌ ゾーン '\(zone.zoneID.zoneName)' の作成エラー: \(error.localizedDescription)")
                        }
                    } else {
                        print("❌ ゾーン '\(zone.zoneID.zoneName)' の作成エラー: \(error.localizedDescription)")
                    }
                } else {
                    print("✅ ゾーン '\(zone.zoneID.zoneName)' を作成しました")
                }
            }
        }
        
        // テストレコードを作成
        let testRecord = CKRecord(recordType: "TestRecord", zoneID: CKRecordZone.ID(zoneName: Constants.CloudKit.petZoneName, ownerName: CKCurrentUserDefaultName))
        testRecord["testField"] = "テストデータ" as CKRecordValue
        
        database.save(testRecord) { savedRecord, error in
            if let error = error {
                print("❌ テストレコードの保存に失敗: \(error.localizedDescription)")
            } else {
                print("✅ テストレコードを保存しました")
            }
        }
    }
}
