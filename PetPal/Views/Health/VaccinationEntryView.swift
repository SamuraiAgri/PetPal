// PetPal/Views/Health/VaccinationEntryView.swift
import SwiftUI

struct VaccinationEntryView: View {
    let pet: PetModel
    @ObservedObject var healthViewModel: HealthViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var date = Date()
    @State private var expiryDate: Date?
    @State private var reminderDate: Date?
    @State private var clinicName = ""
    @State private var vetName = ""
    @State private var notes = ""
    
    @State private var showExpiryDate = false
    @State private var showReminderDate = false
    
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
                
                Section(header: Text("ワクチン情報")) {
                    TextField("ワクチン名", text: $name)
                    
                    DatePicker("接種日", selection: $date, displayedComponents: .date)
                    
                    Toggle("有効期限", isOn: $showExpiryDate)
                    
                    if showExpiryDate {
                        DatePicker("有効期限日", selection: Binding(
                            get: { expiryDate ?? Calendar.current.date(byAdding: .year, value: 1, to: date)! },
                            set: { expiryDate = $0 }
                        ), displayedComponents: .date)
                    }
                    
                    Toggle("リマインダー", isOn: $showReminderDate)
                    
                    if showReminderDate {
                        DatePicker("リマインダー日", selection: Binding(
                            get: { reminderDate ?? Calendar.current.date(byAdding: .month, value: -1, to: expiryDate ?? Calendar.current.date(byAdding: .year, value: 1, to: date)!)! },
                            set: { reminderDate = $0 }
                        ), displayedComponents: .date)
                    }
                }
                
                Section(header: Text("詳細情報")) {
                    TextField("病院名", text: $clinicName)
                    TextField("獣医師名", text: $vetName)
                    TextField("メモ（任意）", text: $notes)
                }
            }
            .navigationTitle("ワクチン記録を追加")
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
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            invalidInputMessage = "ワクチン名を入力してください"
            showingInvalidInputAlert = true
            return
        }
        
        let finalExpiryDate = showExpiryDate ? expiryDate : nil
        let finalReminderDate = showReminderDate ? reminderDate : nil
        
        healthViewModel.addVaccination(
            petId: pet.id,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            date: date,
            expiryDate: finalExpiryDate,
            reminderDate: finalReminderDate,
            clinicName: clinicName.trimmingCharacters(in: .whitespacesAndNewlines),
            vetName: vetName.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        
        dismiss()
    }
}
