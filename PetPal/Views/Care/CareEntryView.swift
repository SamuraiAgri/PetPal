import SwiftUI

struct CareEntryView: View {
    let pet: PetModel
    @ObservedObject var careViewModel: CareViewModel
    @ObservedObject var userProfileViewModel: UserProfileViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedType = Constants.CareTypes.all[0]
    @State private var notes = ""
    @State private var date = Date()
    @State private var showingMultiSelect = false
    @State private var selectedTypes: [String] = []
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("ペット")) {
                    HStack {
                        PetAvatarView(imageData: pet.iconImageData, size: 40)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(pet.name)
                                .font(.headline)
                            
                            // 共有ステータスを表示
                            if pet.isShared {
                                HStack {
                                    Image(systemName: "person.2.fill")
                                        .font(.caption2)
                                    Text("家族と共有中")
                                        .font(.caption)
                                }
                                .foregroundColor(.infoApp)
                            }
                        }
                    }
                }
                
                Section(header: Text("実施者")) {
                    HStack {
                        if let currentUser = userProfileViewModel.currentUser {
                            // ユーザーアバター
                            if let avatarData = currentUser.avatarImageData, let uiImage = UIImage(data: avatarData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color(hex: currentUser.colorHex) ?? .accentApp)
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Text(String(currentUser.name.prefix(1)))
                                            .font(.headline)
                                            .foregroundColor(.white)
                                    )
                            }
                            
                            Text(currentUser.name)
                                .padding(.leading, 8)
                        } else {
                            Text(UIDevice.current.name)
                        }
                    }
                }
                
                Section(header: Text("ケアタイプ")) {
                    if showingMultiSelect {
                        // 複数選択モード
                        ForEach(Constants.CareTypes.all, id: \.self) { type in
                            Button(action: {
                                toggleTypeSelection(type)
                            }) {
                                HStack {
                                    Image(systemName: selectedTypes.contains(type) ? "checkmark.square.fill" : "square")
                                        .foregroundColor(selectedTypes.contains(type) ? .primaryApp : .gray)
                                    
                                    Text(type)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Image(systemName: careTypeIcon(for: type))
                                        .foregroundColor(Color.forCareType(type))
                                }
                            }
                        }
                        
                        Button(action: {
                            showingMultiSelect = false
                            selectedTypes = []
                        }) {
                            Text("単一選択に戻す")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        // 単一選択モード
                        Picker("タイプ", selection: $selectedType) {
                            ForEach(Constants.CareTypes.all, id: \.self) { type in
                                HStack {
                                    Text(type)
                                    Image(systemName: careTypeIcon(for: type))
                                        .foregroundColor(Color.forCareType(type))
                                }
                                .tag(type)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        
                        Button(action: {
                            showingMultiSelect = true
                        }) {
                            Text("複数選択")
                                .foregroundColor(.primaryApp)
                        }
                    }
                }
                
                Section(header: Text("詳細")) {
                    TextField("メモ (任意)", text: $notes)
                    DatePicker("日時", selection: $date)
                }
            }
            .navigationTitle("ケア記録を追加")
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
                    .disabled(showingMultiSelect && selectedTypes.isEmpty)
                }
            }
        }
    }
    
    // ケアタイプに応じたアイコンを返す
    private func careTypeIcon(for type: String) -> String {
        switch type {
        case Constants.CareTypes.walk:
            return "figure.walk"
        case Constants.CareTypes.feeding:
            return "cup.and.saucer.fill"
        case Constants.CareTypes.grooming:
            return "scissors"
        case Constants.CareTypes.medication:
            return "pills.fill"
        case Constants.CareTypes.healthCheck:
            return "stethoscope"
        default:
            return "heart.fill"
        }
    }
    
    // 複数選択時のトグル
    private func toggleTypeSelection(_ type: String) {
        if selectedTypes.contains(type) {
            selectedTypes.removeAll { $0 == type }
        } else {
            selectedTypes.append(type)
        }
    }
    
    // 保存アクション
    private func saveAction() {
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if showingMultiSelect && !selectedTypes.isEmpty {
            // 複数のケアタイプを一度に保存
            careViewModel.addMultipleCare(
                petId: pet.id,
                types: selectedTypes,
                notes: trimmedNotes
            )
        } else {
            // 単一のケアタイプを保存
            careViewModel.addCareLog(
                petId: pet.id,
                type: selectedType,
                notes: trimmedNotes
            )
        }
        
        dismiss()
    }
}
