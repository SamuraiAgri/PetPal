// PetPal/Views/Settings/NotificationSettingsView.swift

import SwiftUI

struct NotificationSettingsView: View {
    @State private var enableFeedingReminders = true
    @State private var enableCareReminders = true
    @State private var enableVaccinationReminders = true
    @State private var feedingReminderTimes: [Date] = [
        Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date(),
        Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date()) ?? Date()
    ]
    @State private var showingTimePicker = false
    @State private var timePickerIndex: Int? = nil
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                // 通知の有効/無効設定
                Section(header: Text("通知設定")) {
                    Toggle("給餌リマインダー", isOn: $enableFeedingReminders)
                    Toggle("ケアリマインダー", isOn: $enableCareReminders)
                    Toggle("ワクチンリマインダー", isOn: $enableVaccinationReminders)
                }
                
                // 給餌リマインダー時間
                if enableFeedingReminders {
                    Section(header: Text("給餌リマインダー時間")) {
                        ForEach(0..<feedingReminderTimes.count, id: \.self) { index in
                            HStack {
                                Text(timeString(for: feedingReminderTimes[index]))
                                    .font(.headline)
                                
                                Spacer()
                                
                                Button(action: {
                                    timePickerIndex = index
                                    showingTimePicker = true
                                }) {
                                    Text("変更")
                                        .foregroundColor(.accentApp)
                                }
                            }
                        }
                        
                        Button(action: {
                            feedingReminderTimes.append(Date())
                            timePickerIndex = feedingReminderTimes.count - 1
                            showingTimePicker = true
                        }) {
                            Label("時間を追加", systemImage: "plus")
                        }
                        
                        if feedingReminderTimes.count > 1 {
                            Button(action: {
                                feedingReminderTimes.removeLast()
                            }) {
                                Label("最後の時間を削除", systemImage: "minus")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                
                // 通知アクセス許可がない場合のセクション
                Section(footer: Text("システム設定から通知へのアクセスを許可してください")) {
                    Button(action: {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Text("通知設定を開く")
                    }
                }
            }
            .navigationTitle("通知設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("戻る") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveSettings()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingTimePicker) {
                if let index = timePickerIndex {
                    TimePickerView(selectedTime: $feedingReminderTimes[index])
                }
            }
        }
    }
    
    // 時間表示用フォーマッター
    private func timeString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
    
    // 設定を保存
    private func saveSettings() {
        // UserDefaults に設定を保存
        UserDefaults.standard.set(enableFeedingReminders, forKey: "enableFeedingReminders")
        UserDefaults.standard.set(enableCareReminders, forKey: "enableCareReminders")
        UserDefaults.standard.set(enableVaccinationReminders, forKey: "enableVaccinationReminders")
        
        // 時間をミリ秒タイムスタンプとして保存
        let timeIntervals = feedingReminderTimes.map { $0.timeIntervalSince1970 }
        UserDefaults.standard.set(timeIntervals, forKey: "feedingReminderTimes")
        
        // 通知の再設定
        // 実際のアプリでは、NotificationManagerを使って通知をスケジュールし直す
    }
}

// 時間選択ビュー
struct TimePickerView: View {
    @Binding var selectedTime: Date
    @Environment(\.dismiss) private var dismiss
    @State private var tempSelectedTime: Date
    
    init(selectedTime: Binding<Date>) {
        self._selectedTime = selectedTime
        self._tempSelectedTime = State(initialValue: selectedTime.wrappedValue)
    }
    
    var body: some View {
        NavigationView {
            VStack {
                DatePicker("", selection: $tempSelectedTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(WheelDatePickerStyle())
                    .labelsHidden()
            }
            .padding()
            .navigationTitle("時間を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("決定") {
                        selectedTime = tempSelectedTime
                        dismiss()
                    }
                }
            }
        }
    }
}
