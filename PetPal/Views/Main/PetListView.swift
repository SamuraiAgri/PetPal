// PetPal/Views/Main/PetListView.swift
import SwiftUI
import PhotosUI
import CloudKit

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
                // 同期ステータスインジケーター
                if petViewModel.syncStatus != .idle {
                    syncStatusView
                }
                
                // ユーザープロファイル表示
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
                        Button(action: {
                            showingAddPet = true
                        }) {
                            Label("ペットを追加", systemImage: "plus")
                        }
                        
                        Button(action: {
                            showingUserProfile = true
                        }) {
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
                Button("キャンセル", role: .cancel) {}
                Button("削除", role: .destructive) {
                    if let id = petToDelete {
                        petViewModel.deletePet(id: id)
                    }
                }
            } message: {
                Text("この操作は取り消せません")
            }
            .alert("共有エラー", isPresented: $showingErrorAlert) {
                Button("OK", role: .cancel) {}
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
            .onChange(of: petToShare) { _, newValue in
                if newValue != nil {
                    showingShareUI = true
                }
            }
        }
        .onAppear {
            // ユーザープロファイルが存在しない場合は作成
            userProfileViewModel.checkAndCreateCurrentUser()
        }
    }
    
    // ユーザープロファイルヘッダー
    private var userProfileHeader: some View {
        if let currentUser = userProfileViewModel.currentUser {
            HStack {
                // ユーザーアバター
                if let avatarData = currentUser.avatarImageData, let uiImage = UIImage(data: avatarData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color(hex: currentUser.colorHex) ?? .accentApp, lineWidth: 2)
                        )
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
                        .foregroundColor(.primaryApp)
                }
            }
            .padding()
            .background(
                Rectangle()
                    .fill(Color.backgroundSecondary.opacity(0.3))
            )
        } else {
            EmptyView()
        }
    }
    
    // 選択されたペットを更新する関数を追加
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
    
    // 同期ステータス表示
    private var syncStatusView: some View {
        HStack {
            switch petViewModel.syncStatus {
            case .syncing:
                ProgressView()
                    .scaleEffect(0.7)
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
                .fill(Color.backgroundSecondary)
        )
    }
    
    // ペットリスト表示
    private var petListContent: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(petViewModel.pets, id: \.id) { pet in
                    EnhancedPetCardView(
                        pet: pet,
                        isSelected: pet.id == petViewModel.selectedPet?.id,
                        onShare: {
                            petToShare = pet
                        }
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
               let rootViewController = UIApplication.shared.windows.first?.rootViewController {
                SharedPetController(petToShare: petToShare, rootViewController: rootViewController, petViewModel: petViewModel, onDismiss: {
                    self.petToShare = nil
                })
            }
        }
    }
    
    // コンテキストメニューを生成するメソッドを分離
    private func createContextMenu(for pet: PetModel) -> some View {
        Group {
            Button(action: {
                petViewModel.selectPet(id: pet.id)
                showingEditPet = true
            }) {
                Label("編集", systemImage: "pencil")
            }
            
            Button(action: {
                petToShare = pet
            }) {
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
    
    // 空の状態表示
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.secondaryApp.opacity(0.2), Color.secondaryApp.opacity(0.1)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 3)
                
                Image(systemName: "pawprint.circle")
                    .font(.system(size: 60))
                    .foregroundColor(.secondaryApp)
            }
            
            Text("ペットが登録されていません")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("「+」ボタンを押して、最初のペットを追加しましょう！")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                        
            Button(action: {
                showingAddPet = true
            }) {
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

// 共有UIコントローラーのラッパー
struct SharedPetController: UIViewControllerRepresentable {
    let petToShare: PetModel
    let rootViewController: UIViewController
    let petViewModel: PetViewModel
    let onDismiss: () -> Void
    
    class Coordinator: NSObject, UICloudSharingControllerDelegate {
        var parent: SharedPetController
        
        init(parent: SharedPetController) {
            self.parent = parent
        }
        
        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            print("Failed to save share: \(error)")
            parent.onDismiss()
        }
        
        func itemTitle(for csc: UICloudSharingController) -> String? {
            return "\(parent.petToShare.name)のケア共有"
        }
        
        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
            // 共有が保存された後の処理
            parent.petViewModel.syncWithCloudKit()
            parent.onDismiss()
        }
        
        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
            // 共有が停止された後の処理
            parent.petViewModel.syncWithCloudKit()
            parent.onDismiss()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }
    
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        
        // CloudKitManagerを使用して共有UIを表示
        let cloudKitManager = CloudKitManager()
        cloudKitManager.presentSharingUI(for: petToShare, from: rootViewController) { result in
            switch result {
            case .success:
                print("Sharing UI presented successfully")
            case .failure(let error):
                print("Error presenting sharing UI: \(error)")
                onDismiss()
            }
        }
        
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // 更新処理は不要
    }
}

// ユーザープロファイル編集ビュー
struct UserProfileEditView: View {
    @ObservedObject var userProfileViewModel: UserProfileViewModel
    let userProfile: UserProfileModel?
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var avatarImage: UIImage?
    @State private var showingImagePicker = false
    @State private var selectedColor: Color = .blue
    
    init(userProfileViewModel: UserProfileViewModel, userProfile: UserProfileModel?) {
        self.userProfileViewModel = userProfileViewModel
        self.userProfile = userProfile
        
        if let profile = userProfile {
            _name = State(initialValue: profile.name)
            
            if let avatarData = profile.avatarImageData, let image = UIImage(data: avatarData) {
                _avatarImage = State(initialValue: image)
            }
            
            if let color = Color(hex: profile.colorHex) {
                _selectedColor = State(initialValue: color)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("プロフィール画像")) {
                    HStack {
                        Spacer()
                        
                        // アバター表示
                        if let image = avatarImage {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(selectedColor, lineWidth: 2)
                                )
                        } else {
                            Circle()
                                .fill(selectedColor)
                                .frame(width: 120, height: 120)
                                .overlay(
                                    Text(String(name.prefix(1)))
                                        .font(.system(size: 40))
                                        .foregroundColor(.white)
                                )
                        }
                        
                        Spacer()
                    }
                    .onTapGesture {
                        showingImagePicker = true
                    }
                    
                    Button(action: {
                        showingImagePicker = true
                    }) {
                        HStack {
                            Spacer()
                            Text("写真を変更")
                                .foregroundColor(.accentApp)
                            Spacer()
                        }
                    }
                }
                
                Section(header: Text("基本情報")) {
                    TextField("名前", text: $name)
                    
                    VStack(alignment: .leading) {
                        Text("表示色")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(userColors, id: \.self) { hexColor in
                                    let color = Color(hex: hexColor) ?? .gray
                                    Circle()
                                        .fill(color)
                                        .frame(width: 30, height: 30)
                                        .overlay(
                                            Circle()
                                                .stroke(color == selectedColor ? .white : .clear, lineWidth: 2)
                                                .padding(2)
                                        )
                                        .background(
                                            Circle()
                                                .fill(color == selectedColor ? .black : .clear)
                                                .scaleEffect(1.1)
                                        )
                                        .onTapGesture {
                                            selectedColor = color
                                        }
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
                
                if userProfile?.isCurrentUser == true {
                    Section(header: Text("共有設定")) {
                        Text("あなたはこのデバイスの現在のユーザーです")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("プロフィール編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveProfile()
                    }
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                PHPickerView(image: $avatarImage)
            }
        }
    }
    
    // プロフィール保存
    private func saveProfile() {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        if let profile = userProfile {
            var newProfile = profile
            newProfile.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // アバターデータ
            if let image = avatarImage {
                newProfile.avatarImageData = image.jpegData(compressionQuality: 0.7)
            }
            
            // 色
            if let hexColor = selectedColor.toHex() {
                newProfile.colorHex = hexColor
            }
            
            userProfileViewModel.saveUserProfile(newProfile)
        }
        
        dismiss()
    }
    
    // 定義済みのユーザー色
    private let userColors = [
        "#4285F4", // Google Blue
        "#EA4335", // Google Red
        "#FBBC05", // Google Yellow
        "#34A853", // Google Green
        "#3B5998", // Facebook Blue
        "#55ACEE", // Twitter Blue
        "#007BB5", // LinkedIn Blue
        "#BD081C", // Pinterest Red
        "#00B489", // Vine Green
        "#7289DA", // Discord Blue
        "#FF6B00", // SoundCloud Orange
        "#FF5700", // Reddit Orange
        "#25D366", // WhatsApp Green
        "#128C7E", // WhatsApp Dark Green
        "#075E54", // WhatsApp Darker Green
        "#FF8800", // Aperture Science Orange
        "#0066FF", // Azure Blue
        "#FF007F", // Deep Pink
        "#00B16A", // Emerald Green
        "#FF0000"  // Red
    ]
}

// 共有とユーザー表示対応の強化版ペットカード
struct EnhancedPetCardView: View {
    let pet: PetModel
    let isSelected: Bool
    let onShare: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // ペットアバターを少し大きくし、影を追加
            PetAvatarView(imageData: pet.iconImageData, size: 70)
                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 1, y: 2)
            
            // ペット情報をより魅力的に表示
            VStack(alignment: .leading, spacing: 6) {
                Text(pet.name)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(Color.textPrimary)
                
                HStack {
                    Image(systemName: pet.gender == "オス" ? "mars" : pet.gender == "メス" ? "venus" : "questionmark")
                        .foregroundColor(pet.gender == "オス" ? .blue : pet.gender == "メス" ? .pink : .gray)
                        .font(.footnote)
                    
                    Text(pet.species + (pet.breed.isEmpty ? "" : " / \(pet.breed)"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundColor(.accentApp)
                    
                    Text("年齢: \(pet.age)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if pet.isShared {
                        Spacer()
                        HStack {
                            Image(systemName: "person.2.fill")
                                .font(.caption)
                                .foregroundColor(.infoApp)
                            Text("共有中")
                                .font(.caption)
                                .foregroundColor(.infoApp)
                        }
                    }
                }
            }
            
            Spacer()
            
            // アクションボタン列
            VStack(spacing: 12) {
                // 選択マークをより目立たせる
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.primaryApp)
                        .font(.title3)
                        .shadow(color: Color.primaryApp.opacity(0.3), radius: 2, x: 0, y: 1)
                        .padding(.trailing, 4)
                }
                
                // 共有ボタン
                Button(action: onShare) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.accentApp)
                        .font(.headline)
                }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius)
                .fill(isSelected ? Color.primaryApp.opacity(0.1) : Color.backgroundPrimary)
                .shadow(color: Color.black.opacity(isSelected ? 0.1 : 0.05), radius: 5, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius)
                .stroke(isSelected ? Color.primaryApp : Color.gray.opacity(0.1), lineWidth: isSelected ? 2 : 1)
        )
    }
}
