import SwiftUI
import PhotosUI
import CloudKit

// スタブ実装（最低限の実装） UserProfileEditView
struct UserProfileEditView: View {
    @ObservedObject var userProfileViewModel: UserProfileViewModel
    let userProfile: UserProfileModel?
    
    var body: some View {
        Text("UserProfileEditView")
    }
}

// スタブ実装（最低限の実装） EnhancedPetCardView
struct EnhancedPetCardView: View {
    let pet: PetModel
    let isSelected: Bool
    let onShare: () -> Void
    
    var body: some View {
        Text("EnhancedPetCardView: \(pet.name)")
    }
}

// Color 拡張（SwiftUI 用）
extension Color {
    func toHex() -> String? {
        let uiColor = UIColor(self)
        return uiColor.toHex()
    }
}

struct PetListView: View {
    @ObservedObject var petViewModel: PetViewModel
    @ObservedObject var userProfileViewModel: UserProfileViewModel
    
    @State private var showingAddPet = false
    @State private var showingEditPet = false
    @State private var showingDeleteAlert = false
    @State private var petToDelete: UUID?
    @State private var showingShareUI = false
    @State private var petToShare: PetModel?
    @State private var sharingError: String?
    @State private var showingErrorAlert = false
    @State private var showingUserProfile = false
    
    var body: some View {
        NavigationView {
            VStack {
                if petViewModel.syncStatus != .idle {
                    syncStatusView
                }
                userProfileHeader
                if petViewModel.pets.isEmpty {
                    emptyStateView
                } else {
                    petListContent
                }
            }
            .navigationTitle("ペット一覧")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingAddPet = true }) {
                            Label("ペットを追加", systemImage: "plus")
                        }
                        Button(action: { showingUserProfile = true }) {
                            Label("プロフィール", systemImage: "person.crop.circle")
                        }
                        Button(action: {
                            petViewModel.syncWithCloudKit()
                            userProfileViewModel.syncWithCloudKit()
                        }) {
                            Label("今すぐ同期", systemImage: "arrow.triangle.2.circlepath")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingAddPet) {
                PetEditView(isNewPet: true, onSave: { pet in
                    petViewModel.addPet(
                        name: pet.name,
                        species: pet.species,
                        breed: pet.breed,
                        birthDate: pet.birthDate,
                        gender: pet.gender,
                        iconImageData: pet.iconImageData,
                        notes: pet.notes
                    )
                })
            }
            .sheet(isPresented: $showingEditPet) {
                if let selectedPet = petViewModel.selectedPet {
                    PetEditView(
                        isNewPet: false,
                        initialPet: selectedPet,
                        onSave: { updatedPet in
                            updateSelectedPet(updatedPet)
                        }
                    )
                }
            }
            .sheet(isPresented: $showingUserProfile) {
                UserProfileEditView(
                    userProfileViewModel: userProfileViewModel,
                    userProfile: userProfileViewModel.currentUser
                )
            }
            .alert("ペットを削除しますか？", isPresented: $showingDeleteAlert) {
                Button("キャンセル", role: .cancel) { }
                Button("削除", role: .destructive) {
                    if let id = petToDelete {
                        petViewModel.deletePet(id: id)
                    }
                }
            } message: {
                Text("この操作は取り消せません")
            }
            .alert("共有エラー", isPresented: $showingErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(sharingError ?? "共有中にエラーが発生しました")
            }
            .overlay {
                if petViewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.1))
                }
            }
            .onChange(of: petToShare) { newValue in
                if newValue != nil {
                    showingShareUI = true
                }
            }
        }
        .onAppear {
            userProfileViewModel.checkAndCreateCurrentUser()
        }
    }
    
    // MARK: - 同期ステータス表示
    private var syncStatusView: some View {
        HStack {
            switch petViewModel.syncStatus {
            case .syncing:
                ProgressView().scaleEffect(0.7)
                Text("同期中...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("同期完了")
                    .font(.caption)
                    .foregroundColor(.secondary)
            case .failed:
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.red)
                Text("同期エラー")
                    .font(.caption)
                    .foregroundColor(.red)
            case .idle:
                EmptyView()
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
    
    // MARK: - ユーザープロファイルヘッダー
    @ViewBuilder
    private var userProfileHeader: some View {
        if let currentUser = userProfileViewModel.currentUser {
            HStack {
                if let avatarData = currentUser.avatarImageData, let uiImage = UIImage(data: avatarData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color(hex: currentUser.colorHex) ?? .accentColor, lineWidth: 2)
                        )
                } else {
                    Circle()
                        .fill(Color(hex: currentUser.colorHex) ?? .accentColor)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text(String(currentUser.name.prefix(1)))
                                .font(.headline)
                                .foregroundColor(.white)
                        )
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("こんにちは、\(currentUser.name)さん")
                        .font(.headline)
                    Text("家族で共有するペットケア")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: {
                    showingUserProfile = true
                }) {
                    Image(systemName: "pencil.circle")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                }
            }
            .padding()
            .background(
                Rectangle()
                    .fill(Color(UIColor.secondarySystemBackground).opacity(0.3))
            )
        } else {
            EmptyView()
        }
    }
    
    // MARK: - 選択されたペット更新
    private func updateSelectedPet(_ pet: PetModel) {
        petViewModel.updatePet(
            id: pet.id,
            name: pet.name,
            species: pet.species,
            breed: pet.breed,
            birthDate: pet.birthDate,
            gender: pet.gender,
            iconImageData: pet.iconImageData,
            notes: pet.notes
        )
    }
    
    // EnhancedPetCardViewのonShareアクションで呼び出す処理
    func sharePet(_ pet: PetModel) {
        petToShare = pet
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            CloudKitManager().presentSharingUI(for: pet, from: rootVC) { result in
                switch result {
                case .success:
                    print("共有UIが正常に表示されました")
                case .failure(let error):
                    sharingError = error.localizedDescription
                    showingErrorAlert = true
                }
            }
        }
    }
    }
    
    // MARK: - ペットリストコンテンツ
    private var petListContent: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(petViewModel.pets, id: \.id) { pet in
                    EnhancedPetCardView(
                        pet: pet,
                        isSelected: pet.id == petViewModel.selectedPet?.id,
                        onShare: { petToShare = pet }
                    )
                    .onTapGesture {
                        petViewModel.selectPet(id: pet.id)
                    }
                    .contextMenu {
                        createContextMenu(for: pet)
                    }
                }
            }
            .padding()
        }
        .sheet(isPresented: $showingShareUI) {
            if let petToShare = petToShare,
               let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                SharedPetController(
                    petToShare: petToShare,
                    rootViewController: rootVC,
                    petViewModel: petViewModel,
                    onDismiss: { self.petToShare = nil }
                )
            }
        }
    }
    
    // MARK: - コンテキストメニュー
    private func createContextMenu(for pet: PetModel) -> some View {
        Group {
            Button(action: {
                petViewModel.selectPet(id: pet.id)
                showingEditPet = true
            }) {
                Label("編集", systemImage: "pencil")
            }
            Button(action: { petToShare = pet }) {
                Label("共有", systemImage: "person.2.square.stack")
            }
            Button(role: .destructive, action: {
                petToDelete = pet.id
                showingDeleteAlert = true
            }) {
                Label("削除", systemImage: "trash")
            }
        }
    }
    
    // MARK: - 空の状態表示
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.secondary.opacity(0.2), Color.secondary.opacity(0.1)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 3)
                Image(systemName: "pawprint.circle")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)
            }
            Text("ペットが登録されていません")
                .font(.title2)
                .fontWeight(.medium)
            Text("「+」ボタンを押して、最初のペットを追加しましょう！")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button(action: { showingAddPet = true }) {
                Text("ペットを追加")
                    .font(.headline)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.primaryApp, Color.primaryApp.opacity(0.8)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(Constants.Layout.cornerRadius)
                    .shadow(color: Color.primaryApp.opacity(0.3), radius: 4, x: 0, y: 3)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
