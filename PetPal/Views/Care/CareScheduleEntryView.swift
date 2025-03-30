import SwiftUI

struct CareScheduleEntryView: View {
    let pet: PetModel
    @ObservedObject var careViewModel: CareViewModel
    @ObservedObject var userProfileViewModel: UserProfileViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedType = Constants.CareTypes.all[0]
    @State private var notes = ""
    @State private var scheduledDate = Date().addingTimeInterval(3600) // 1時間後をデフォルトに
    @State private var selectedUserID: UUID?
    @State private var showingUserSelector = false
    
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
                
                Section(header: Text("ケアタイプ")) {
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
                }
                
                Section(header: Text("スケジュール詳細")) {
                    DatePicker("予定日時", selection: $scheduledDate)
                    
                    // 担当者選択
                    Button(action: {
                        showingUserSelector = true
                    }) {
                        HStack {
                            Text("担当者")
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if let userID = selectedUserID, let user = userProfileViewModel.userProfiles.first(where: { $0.id == userID }) {
                                // 選択済みユーザーを表示
                                HStack {
                                    if let avatarData = user.avatarImageData, let uiImage = UIImage(data: avatarData) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 24, height: 24)
                                            .clipShape(Circle())
                                    } else {
                                        Circle()
                                            .fill(Color(hex: user.colorHex) ?? .accentApp)
                                            .frame(width: 24, height: 24)
                                            .overlay(
                                                Text(String(user.name.prefix(1)))
                                                    .font(.caption2)
                                                    .foregroundColor(.white)
                                            )
                                    }
                                    
                                    Text(user.name)
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                Text("選択してください")
                                    .foregroundColor(.secondary)
                            }
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    TextField("メモ (任意)", text: $notes)
                }
                
                Section(header: Text("Quick Assign")) {
                    // 自分自身に割り当てるボタン
                    Button(action: {
                        selectedUserID = userProfileViewModel.currentUser?.id
                    }) {
                        HStack {
                            Image(systemName: "person.fill")
                            Text("自分に割り当てる")
                            
                            if selectedUserID == userProfileViewModel.currentUser?.id {
                                Spacer()
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentApp)
                            }
                        }
                    }
                    
                    // 担当者なしのボタン
                    Button(action: {
                        selectedUserID = nil
                    }) {
                        HStack {
                            Image(systemName: "person.slash")
                            Text("担当者なし")
                            
                            if selectedUserID == nil {
                                Spacer()
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentApp)
                            }
                        }
                    }
                }
            }
            .navigationTitle("ケア予定の追加")
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
            .sheet(isPresented: $showingUserSelector) {
                UserSelectorView(
                    userProfiles: userProfileViewModel.userProfiles,
                    selectedUserID: $selectedUserID
                )
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
    
    // 保存アクション
    private func saveAction() {
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        
        careViewModel.addCareSchedule(
            petId: pet.id,
            type: selectedType,
            scheduledDate: scheduledDate,
            assignedUserProfileID: selectedUserID,
            notes: trimmedNotes
        )
        
        dismiss()
    }
}

// ユーザー選択ビュー
struct UserSelectorView: View {
    let userProfiles: [UserProfileModel]
    @Binding var selectedUserID: UUID?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(userProfiles) { user in
                    Button(action: {
                        selectedUserID = user.id
                        dismiss()
                    }) {
                        HStack {
                            // ユーザーアバター
                            if let avatarData = user.avatarImageData, let uiImage = UIImage(data: avatarData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color(hex: user.colorHex) ?? .accentApp)
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Text(String(user.name.prefix(1)))
                                            .font(.headline)
                                            .foregroundColor(.white)
                                    )
                            }
                            
                            Text(user.name)
                                .padding(.leading, 8)
                            
                            Spacer()
                            
                            if user.id == selectedUserID {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentApp)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            .navigationTitle("担当者を選択")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
        }
    }
}
