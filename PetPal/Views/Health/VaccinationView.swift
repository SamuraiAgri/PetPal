import SwiftUI

struct VaccinationView: View {
    @ObservedObject var petViewModel: PetViewModel
    @ObservedObject var healthViewModel: HealthViewModel
    
    @State private var showingAddVaccination = false
    @State private var showingActiveOnly = true
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // ペット選択セクション
                if let selectedPet = petViewModel.selectedPet {
                    petSelectorView
                    
                    // フィルタートグル
                    filterToggleView
                    
                    // ワクチン一覧
                    vaccinationListView
                } else {
                    noPetSelectedView
                }
            }
            .navigationTitle("ワクチン管理")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddVaccination = true
                    }) {
                        Image(systemName: "plus")
                    }
                    .disabled(petViewModel.selectedPet == nil)
                }
            }
            .sheet(isPresented: $showingAddVaccination) {
                if let pet = petViewModel.selectedPet {
                    VaccinationEntryView(pet: pet, healthViewModel: healthViewModel)
                }
            }
            .onChange(of: petViewModel.selectedPet) { _ in
                if let petId = petViewModel.selectedPet?.id {
                    healthViewModel.fetchVaccinations(for: petId)
                }
            }
            .onAppear {
                if let petId = petViewModel.selectedPet?.id {
                    healthViewModel.fetchVaccinations(for: petId)
                }
            }
        }
    }
    
    // ペット選択ビュー
    private var petSelectorView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(petViewModel.pets, id: \.id) { pet in
                    VStack {
                        PetAvatarView(imageData: pet.iconImageData, size: 60)
                            .overlay(
                                Circle()
                                    .stroke(petViewModel.selectedPet?.id == pet.id ? Color.primaryApp : Color.clear, lineWidth: 3)
                            )
                        
                        Text(pet.name)
                            .font(.caption)
                            .fontWeight(petViewModel.selectedPet?.id == pet.id ? .semibold : .regular)
                    }
                    .onTapGesture {
                        petViewModel.selectPet(id: pet.id)
                    }
                }
            }
            .padding()
            .background(Color.backgroundSecondary.opacity(0.5))
        }
    }
    
    // フィルタートグルビュー
    private var filterToggleView: some View {
        Toggle(isOn: $showingActiveOnly) {
            Text("有効なワクチンのみ表示")
                .font(.subheadline)
        }
        .padding()
        .background(Color.backgroundSecondary.opacity(0.2))
    }
    
    // ワクチン一覧ビュー
    private var vaccinationListView: some View {
        Group {
            if healthViewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let filteredVaccinations = showingActiveOnly ?
                    healthViewModel.vaccinations.filter { vaccination in
                        guard let expiryDate = vaccination.expiryDate else { return true }
                        return expiryDate >= Date()
                    } : healthViewModel.vaccinations
                
                if filteredVaccinations.isEmpty {
                    emptyStateView(
                        icon: "syringe.fill",
                        title: healthViewModel.vaccinations.isEmpty ? "ワクチン記録がありません" : "有効なワクチンがありません",
                        message: healthViewModel.vaccinations.isEmpty ? "「+」ボタンからワクチン接種を記録しましょう" : "「+」ボタンで新しいワクチン記録を追加するか、フィルターをオフにして全てのワクチンを表示"
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(filteredVaccinations) { vaccination in
                                vaccinationCard(vaccination: vaccination)
                                    .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
        }
    }
    
    // ワクチン記録カード
    private func vaccinationCard(vaccination: VaccinationModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(vaccination.name)
                    .font(.headline)
                
                Spacer()
                
                // 有効期限切れかどうかを判定
                if let expiryDate = vaccination.expiryDate {
                    HStack {
                        Circle()
                            .fill(expiryDate < Date() ? Color.errorApp : Color.successApp)
                            .frame(width: 8, height: 8)
                        
                        Text(expiryDate < Date() ? "期限切れ" : "有効")
                            .font(.caption)
                            .foregroundColor(expiryDate < Date() ? .errorApp : .successApp)
                    }
                }
            }
            
            Divider()
            
            HStack {
                detailRow(title: "接種日", content: vaccination.date.formattedDate)
                
                if let expiryDate = vaccination.expiryDate {
                    Spacer()
                    detailRow(title: "有効期限", content: expiryDate.formattedDate)
                }
            }
            
            if !vaccination.clinicName.isEmpty {
                detailRow(title: "病院", content: vaccination.clinicName)
            }
            
            if !vaccination.vetName.isEmpty {
                detailRow(title: "獣医師", content: vaccination.vetName)
            }
            
            if !vaccination.notes.isEmpty {
                detailRow(title: "メモ", content: vaccination.notes)
            }
            
            // リマインダーがある場合
            if let reminderDate = vaccination.reminderDate {
                HStack {
                    Image(systemName: "bell.fill")
                        .foregroundColor(.infoApp)
                    
                    Text("次回予定日: \(reminderDate.formattedDate)")
                        .font(.caption)
                        .foregroundColor(.infoApp)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius)
                .fill(Color.backgroundPrimary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius)
                .stroke(
                    vaccination.expiryDate != nil && vaccination.expiryDate! < Date()
                    ? Color.errorApp.opacity(0.3)
                    : Color.gray.opacity(0.2),
                    lineWidth: 1
                )
        )
        .contextMenu {
            Button(role: .destructive, action: {
                healthViewModel.deleteVaccination(id: vaccination.id)
            }) {
                Label("削除", systemImage: "trash")
            }
        }
    }
    
    // 詳細行ヘルパー
    private func detailRow(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(content)
                .font(.subheadline)
        }
    }
    
    // ペット未選択時のビュー
    private var noPetSelectedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "pawprint.circle")
                .font(.system(size: 80))
                .foregroundColor(.secondaryApp)
            
            Text("ペットが選択されていません")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("「ペット」タブでペットを選択してください")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if !petViewModel.pets.isEmpty {
                Button(action: {
                    petViewModel.selectPet(id: petViewModel.pets[0].id)
                }) {
                    Text("最初のペットを選択")
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                }
                .primaryButtonStyle()
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // 空の状態表示
    private func emptyStateView(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundColor(.secondaryApp.opacity(0.7))
            
            Text(title)
                .font(.headline)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
