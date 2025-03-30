// PetPal/Views/Health/WeightLogEntryView.swift
import SwiftUI

struct WeightLogEntryView: View {
    let pet: PetModel
    @ObservedObject var healthViewModel: HealthViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var weight = ""
    @State private var unit = "kg"
    @State private var notes = ""
    @State private var date = Date()
    
    @State private var showingInvalidInputAlert = false
    @State private var invalidInputMessage = ""
    
    private let unitOptions = ["kg", "g", "lb", "oz"]
    
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
                
                Section(header: Text("体重")) {
                    HStack {
                        TextField("体重", text: $weight)
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
                    DatePicker("日付", selection: $date, displayedComponents: .date)
                    TextField("メモ（任意）", text: $notes)
                }
            }
            .navigationTitle("体重記録を追加")
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
    
    private func saveAction() {
        // 入力バリデーション
        guard let weightValue = Double(weight) else {
            invalidInputMessage = "体重は数値で入力してください"
            showingInvalidInputAlert = true
            return
        }
        
        guard weightValue > 0 else {
            invalidInputMessage = "体重は0より大きい値を入力してください"
            showingInvalidInputAlert = true
            return
        }
        
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        
        healthViewModel.addWeightLog(
            petId: pet.id,
            weight: weightValue,
            unit: unit,
            notes: trimmedNotes,
            date: date
        )
        
        dismiss()
    }
}
