// PetPal/Views/Settings/SettingsView.swift

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var petViewModel: PetViewModel
    @StateObject private var appSettings = AppSettingsManager.shared
    
    @State private var showingNotificationSettings = false
    @State private var showingCloudKitStatus = false
    @State private var showingResetConfirmation = false
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                // ユーザー情報セクション
                Section(header: Text("ユーザー")) {
                    HStack {
                        Text("デバイス名")
                        Spacer()
                        Text(UIDevice.current.name)
                            .foregroundColor(.secondary)
                    }
                }
                
                // 通知設定セクション
                Section(header: Text("通知設定")) {
                    Button(action: {
                        showingNotificationSettings = true
                    }) {
                        HStack {
                            Text("通知管理")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Toggle("給餌リマインダー", isOn: $appSettings.enableFeedingReminders)
                    Toggle("ケアリマインダー", isOn: $appSettings.enableCareReminders)
                    Toggle("ワクチンリマインダー", isOn: $appSettings.enableVaccinationReminders)
                }
                
                // データ同期セクション
                Section(header: Text("データ同期"), footer: Text("家族間でペット情報を共有するには、同期設定を有効にしてください")) {
                    Button(action: {
                        showingCloudKitStatus = true
                    }) {
                        HStack {
                            Text("同期ステータス")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button(action: {
                        petViewModel.syncWithCloudKit()
                    }) {
                        HStack {
                            Text("今すぐ同期")
                            Spacer()
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(.accentApp)
                        }
                    }
                }
                
                // アプリ情報セクション
                Section(header: Text("アプリ情報")) {
                    HStack {
                        Text("バージョン")
                        Spacer()
                        Text("\(Constants.App.version) (\(Constants.App.build))")
                            .foregroundColor(.secondary)
                    }
                }
                
                // 危険操作セクション
                Section(header: Text("上級操作"), footer: Text("これらの操作は元に戻せません。慎重に行ってください。")) {
                    Button(action: {
                        showingResetConfirmation = true
                    }) {
                        HStack {
                            Text("設定をリセット")
                                .foregroundColor(.red)
                            Spacer()
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingNotificationSettings) {
                NotificationSettingsView()
            }
            .sheet(isPresented: $showingCloudKitStatus) {
                CloudKitStatusView()
            }
            .alert("設定をリセット", isPresented: $showingResetConfirmation) {
                Button("キャンセル", role: .cancel) {}
                Button("リセット", role: .destructive) {
                    appSettings.resetToDefaults()
                }
            } message: {
                Text("すべての設定を初期状態に戻します。この操作は元に戻せません。")
            }
        }
    }
}
