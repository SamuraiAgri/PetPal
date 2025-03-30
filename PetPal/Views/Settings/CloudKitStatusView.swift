// PetPal/Views/Settings/CloudKitStatusView.swift

import SwiftUI

struct CloudKitStatusView: View {
    @ObservedObject private var cloudKitViewModel = CloudKitSyncViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("iCloud同期ステータス")) {
                    HStack {
                        Text("同期状態")
                        Spacer()
                        statusView
                    }
                    
                    if let lastSync = cloudKitViewModel.lastSyncDate {
                        HStack {
                            Text("前回の同期")
                            Spacer()
                            Text(formatDate(lastSync))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let errorMessage = cloudKitViewModel.errorMessage {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("エラー")
                                .font(.headline)
                            
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                Section {
                    Button(action: {
                        cloudKitViewModel.syncAllData()
                    }) {
                        HStack {
                            Spacer()
                            if cloudKitViewModel.syncStatus == .syncing {
                                ProgressView()
                                    .padding(.trailing, 8)
                            }
                            Text("今すぐ同期")
                            Spacer()
                        }
                    }
                    .disabled(cloudKitViewModel.syncStatus == .syncing)
                }
                
                Section(header: Text("情報"), footer: Text("iCloudにサインインしていることを確認してください。同期には安定したインターネット接続が必要です。")) {
                    Button(action: {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Text("iCloud設定を開く")
                    }
                }
            }
            .navigationTitle("同期ステータス")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var statusView: some View {
        HStack {
            switch cloudKitViewModel.syncStatus {
            case .idle:
                Circle()
                    .fill(Color.gray)
                    .frame(width: 10, height: 10)
                Text("待機中")
                    .foregroundColor(.gray)
            case .syncing:
                ProgressView()
                    .scaleEffect(0.7)
                    .padding(.trailing, 4)
                Text("同期中...")
                    .foregroundColor(.accentApp)
            case .completed:
                Circle()
                    .fill(Color.green)
                    .frame(width: 10, height: 10)
                Text("完了")
                    .foregroundColor(.green)
            case .failed:
                Circle()
                    .fill(Color.red)
                    .frame(width: 10, height: 10)
                Text("エラー")
                    .foregroundColor(.red)
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
}
