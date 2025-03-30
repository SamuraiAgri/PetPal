// PetPal/Views/Main/PetListView.swift
import SwiftUI
import PhotosUI

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
                            updateSelectedPet(updatedPet)
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
                    PetCardView(pet: pet, isSelected: pet.id == petViewModel.selectedPet?.id)
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

// PetCardView - ペット一覧の各カード
struct PetCardView: View {
    let pet: PetModel
    let isSelected: Bool
    
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
                }
            }
            
            Spacer()
            
            // 選択マークをより目立たせる
            if isSelected {
                VStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.primaryApp)
                        .font(.title3)
                        .shadow(color: Color.primaryApp.opacity(0.3), radius: 2, x: 0, y: 1)
                        .padding(.trailing, 4)
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
