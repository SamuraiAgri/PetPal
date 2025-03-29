import SwiftUI

struct FeedingLogEntryView: View {
    let pet: PetModel
    @ObservedObject var feedingViewModel: FeedingViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var foodType = "ドライフード"
    @State private var amount = ""
    @State private var unit = "g"
    @State private var notes = ""
    @State private var performedBy = UIDevice.current.name
    @State private var date = Date()
    
    // 一般的な食事タイプのオプション
    private let foodTypeOptions = ["ドライフード", "ウェットフード", "おやつ", "水", "サプリメント", "その他"]
    private let unitOptions = ["g", "ml", "個", "杯", "袋", "缶", "その他"]
    
    @State private var showingInvalidInputAlert = false
    @State private var invalidInputMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("ペット")) {
                    HStack {
                        PetAvatarView(imageData: pet.iconImageData, size: 40)
                        Text(pet.name)
                            .font(.headline)
                    }
                }
                
                Section(header: Text("給餌内容")) {
                    Picker("フードタイプ", selection: $foodType) {
                        ForEach(foodTypeOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    HStack {
                        TextField("量", text: $amount)
                            .keyboardType(.decimalPad)
                        
                        Picker("単位", selection: $unit) {
                            ForEach(unitOptions, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(width: 100)
                    }
                }
                
                Section(header: Text("詳細")) {
                    TextField("メモ (任意)", text: $notes)
                    
                    TextField("実施者", text: $performedBy)
                    
                    DatePicker("日時", selection: $date)
                }
                
                Section {
                    // クイックプリセットボタン
                    Button(action: {
                        foodType = "ドライフード"
                        amount = "100"
                        unit = "g"
                    }) {
                        HStack {
                            Image(systemName: "bowl.fill")
                            Text("ドライフード 100g")
                        }
                    }
                    
                    Button(action: {
                        foodType = "ウェットフード"
                        amount = "50"
                        unit = "g"
                    }) {
                        HStack {
                            Image(systemName: "fork.knife")
                            Text("ウェットフード 50g")
                        }
                    }
                    
                    Button(action: {
                        foodType = "おやつ"
                        amount = "10"
                        unit = "g"
                    }) {
                        HStack {
                            Image(systemName: "star.fill")
                            Text("おやつ 10g")
                        }
                    }
                    
                    Button(action: {
                        foodType = "水"
                        amount = "200"
                        unit = "ml"
                    }) {
                        HStack {
                            Image(systemName: "drop.fill")
                            Text("水 200ml")
                        }
                    }
                } header: {
                    Text("クイック設定")
                }
            }
            .navigationTitle("給餌記録を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveAction()
                    }
                }
            }
            .alert("入力エラー", isPresented: $showingInvalidInputAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(invalidInputMessage)
            }
        }
    }
    
    // 保存アクション
    private func saveAction() {
        // 入力バリデーション
        guard !foodType.isEmpty else {
            invalidInputMessage = "フードタイプを選択してください"
            showingInvalidInputAlert = true
            return
        }
        
        guard let amountValue = Double(amount) else {
            invalidInputMessage = "量は数値で入力してください"
            showingInvalidInputAlert = true
            return
        }
        
        guard amountValue > 0 else {
            invalidInputMessage = "量は0より大きい値を入力してください"
            showingInvalidInputAlert = true
            return
        }
        
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPerformedBy = performedBy.isEmpty ? UIDevice.current.name : performedBy.trimmingCharacters(in: .whitespacesAndNewlines)
        
        feedingViewModel.addFeedingLog(
            petId: pet.id,
            foodType: foodType,
            amount: amountValue,
            unit: unit,
            notes: trimmedNotes,
            performedBy: trimmedPerformedBy
        )
        
        dismiss()
    }
}
