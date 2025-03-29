import SwiftUI

struct PetListView: View {
    @ObservedObject var petViewModel: PetViewModel
    @State private var showingAddPet = false
    @State private var showingEditPet = false
    @State private var showingDeleteAlert = false
    @State private var petToDelete: UUID?
    
    var body: some View {
        NavigationView {
            VStack {
                // 同期ステータスインジケーター
                if petViewModel.syncStatus != .idle {
                    syncStatusView
                }
                
                if petViewModel.pets.isEmpty {
                    emptyStateView
                } else {
                    petListContent
                }
            }
            .navigationTitle("ペット一覧")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddPet = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        petViewModel.syncWithCloudKit()
                    }) {
                        Image(systemName: "arrow.triangle.2.circlepath")
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
                            petViewModel.updatePet(
                                id: updatedPet.id,
                                name: updatedPet.name,
                                species: updatedPet.species,
                                breed: updatedPet.breed,
                                birthDate: updatedPet.birthDate,
                                gender: updatedPet.gender,
                                iconImageData: updatedPet.iconImageData,
                                notes: updatedPet.notes
                            )
                        }
                    )
                }
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
            .overlay {
                if petViewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.1))
                }
            }
        }
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
                    PetCardView(pet: pet, isSelected: pet.id == petViewModel.selectedPet?.id)
                        .onTapGesture {
                            petViewModel.selectPet(id: pet.id)
                        }
                        .contextMenu {
                            Button(action: {
                                petViewModel.selectPet(id: pet.id)
                                showingEditPet = true
                            }) {
                                Label("編集", systemImage: "pencil")
                            }
                            
                            Button(role: .destructive, action: {
                                petToDelete = pet.id
                                showingDeleteAlert = true
                            }) {
                                Label("削除", systemImage: "trash")
                            }
                        }
                }
            }
            .padding()
        }
    }
    
    // 空の状態表示
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "pawprint.circle")
                .font(.system(size: 80))
                .foregroundColor(.secondaryApp)
            
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
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .primaryButtonStyle()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// PetCardView - ペット一覧の各カード
struct PetCardView: View {
    let pet: PetModel
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // ペットアバター
            PetAvatarView(imageData: pet.iconImageData, size: 60)
            
            // ペット情報
            VStack(alignment: .leading, spacing: 4) {
                Text(pet.name)
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text(pet.species + (pet.breed.isEmpty ? "" : " / \(pet.breed)"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("年齢: \(pet.age)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 選択マーク
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.primaryApp)
                    .font(.title3)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius)
                .fill(isSelected ? Color.primaryApp.opacity(0.1) : Color.backgroundPrimary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius)
                .stroke(isSelected ? Color.primaryApp : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
        )
    }
}
