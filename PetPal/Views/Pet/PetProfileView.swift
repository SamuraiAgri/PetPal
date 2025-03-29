import SwiftUI

struct PetProfileView: View {
    let pet: PetModel
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    let onDelete: (UUID) -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // ペットアバター
            PetAvatarView(imageData: pet.iconImageData, size: Constants.Layout.largeAvatarSize)
            
            // ペット情報
            VStack(spacing: 12) {
                Text(pet.name)
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(pet.species + (pet.breed.isEmpty ? "" : " / \(pet.breed)"))
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 12) {
                    Badge(text: "年齢: \(pet.age)", icon: "calendar")
                    
                    if !pet.gender.isEmpty {
                        Badge(text: pet.gender, icon: pet.gender == "オス" ? "malecircle" : "femalecircle")
                    }
                }
                
                if !pet.notes.isEmpty {
                    Text(pet.notes)
                        .font(.body)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.top, 8)
                }
            }
            
            // アクションボタン
            HStack(spacing: 16) {
                Button(action: {
                    showingEditSheet = true
                }) {
                    Label("編集", systemImage: "pencil")
                        .frame(maxWidth: .infinity)
                }
                .primaryButtonStyle()
                
                Button(action: {
                    showingDeleteAlert = true
                }) {
                    Label("削除", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .secondaryButtonStyle()
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius)
                .fill(Color.backgroundPrimary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .sheet(isPresented: $showingEditSheet) {
            PetEditView(
                isNewPet: false,
                initialPet: pet,
                onSave: { _ in
                    // 編集後の保存処理は親ビューで行われる想定
                }
            )
        }
        .alert("ペットを削除しますか？", isPresented: $showingDeleteAlert) {
            Button("キャンセル", role: .cancel) {}
            Button("削除", role: .destructive) {
                onDelete(pet.id)
            }
        } message: {
            Text("この操作は取り消せません")
        }
    }
}

// バッジコンポーネント
struct Badge: View {
    let text: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.footnote)
            
            Text(text)
                .font(.footnote)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondaryApp.opacity(0.1))
        )
        .foregroundColor(.secondaryApp)
    }
}
