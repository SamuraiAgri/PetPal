import SwiftUI

struct PetDetailView: View {
    let pet: PetModel
    @ObservedObject var petViewModel: PetViewModel
    @ObservedObject var careViewModel: CareViewModel
    @ObservedObject var feedingViewModel: FeedingViewModel
    @ObservedObject var healthViewModel: HealthViewModel
    
    @State private var showingEditPet = false
    @State private var showingDeleteAlert = false
    @State private var selectedTab = 0
    @State private var petToShare: PetModel?
    @State private var showingShareUI = false

    private let tabs = ["基本情報", "ケア履歴", "給餌記録", "健康記録"]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                profileHeaderView
                tabSelectionView
                tabContentView
            }
            .padding(.bottom, 30)
        }
        .navigationTitle(pet.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showingEditPet = true }) {
                        Label("編集", systemImage: "pencil")
                    }
                    Button(role: .destructive, action: { showingDeleteAlert = true }) {
                        Label("削除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditPet) {
            PetEditView(
                isNewPet: false,
                initialPet: pet,
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
        .alert("ペットを削除しますか？", isPresented: $showingDeleteAlert) {
            Button("キャンセル", role: .cancel) { }
            Button("削除", role: .destructive) {
                petViewModel.deletePet(id: pet.id)
            }
        } message: {
            Text("この操作は取り消せません")
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
        .onAppear {
            careViewModel.fetchCareLogs(for: pet.id)
            feedingViewModel.fetchFeedingLogs(for: pet.id)
            healthViewModel.fetchHealthLogs(for: pet.id)
            healthViewModel.fetchWeightLogs(for: pet.id)
            healthViewModel.fetchVaccinations(for: pet.id)
        }
    }
    
    // MARK: - プロフィールヘッダー
    private var profileHeaderView: some View {
        VStack(spacing: 24) {
            PetAvatarView(imageData: pet.iconImageData, size: Constants.Layout.largeAvatarSize)
                .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
            VStack(spacing: 12) {
                Text(pet.name)
                    .font(.title)
                    .fontWeight(.bold)
                Text(pet.species + (pet.breed.isEmpty ? "" : " / \(pet.breed)"))
                    .font(.headline)
                    .foregroundColor(.secondary)
                HStack(spacing: 16) {
                    infoRow(label: "年齢", value: pet.age)
                    if !pet.gender.isEmpty {
                        infoRow(label: "性別", value: pet.gender)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.secondarySystemBackground))
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [Color(UIColor.systemBackground), Color(UIColor.systemBackground).opacity(0.95)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
    }
    
    // MARK: - infoRow ヘルパー
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text("\(label):")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(.subheadline)
        }
    }
    
    // MARK: - タブ選択ビュー
    private var tabSelectionView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(0..<tabs.count, id: \.self) { index in
                    Button(action: { selectedTab = index }) {
                        Text(tabs[index])
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(selectedTab == index ? Color.primaryApp : Color(UIColor.secondarySystemBackground))
                            )
                            .foregroundColor(selectedTab == index ? .white : .primary)
                            .fontWeight(selectedTab == index ? .semibold : .regular)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - タブコンテンツビュー
    private var tabContentView: some View {
        VStack {
            switch selectedTab {
            case 0:
                basicInfoTab
            case 1:
                careHistoryTab
            case 2:
                feedingHistoryTab
            case 3:
                healthHistoryTab
            default:
                EmptyView()
            }
        }
        .padding(.top, 12)
    }
    
    // MARK: - 基本情報タブ
    private var basicInfoTab: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 16) {
                Text("ペット情報")
                    .font(.headline)
                HStack {
                    VStack(alignment: .leading, spacing: 12) {
                        infoRow(label: "名前", value: pet.name)
                        infoRow(label: "種類", value: pet.species)
                        infoRow(label: "品種", value: pet.breed.isEmpty ? "指定なし" : pet.breed)
                    }
                    Spacer()
                    VStack(alignment: .leading, spacing: 12) {
                        infoRow(label: "性別", value: pet.gender.isEmpty ? "指定なし" : pet.gender)
                        infoRow(label: "年齢", value: pet.age)
                        infoRow(label: "登録日", value: pet.createdAt.formattedDate)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius)
                    .fill(Color(UIColor.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
            
            VStack(alignment: .leading, spacing: 12) {
                Text("メモ")
                    .font(.headline)
                if pet.notes.isEmpty {
                    Text("メモはありません")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    Text(pet.notes)
                        .font(.body)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius)
                                .fill(Color(UIColor.secondarySystemBackground))
                        )
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius)
                    .fill(Color(UIColor.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .padding(.horizontal)
    }
    
    // MARK: - ケア履歴タブ
    private var careHistoryTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            if careViewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if careViewModel.careLogs.isEmpty {
                emptyStateView(
                    icon: "heart.text.square",
                    title: "ケア記録がありません",
                    message: "「+」ボタンまたはクイックアクションからケア記録を追加しましょう"
                )
            } else {
                Text("最近のケア記録")
                    .font(.headline)
                    .padding(.horizontal, 16)
                ForEach(careViewModel.careLogs.prefix(5)) { log in
                    CareLogItemView(log: log)
                        .padding(.horizontal, 16)
                }
                if careViewModel.careLogs.count > 5 {
                    Button(action: {
                        // 全記録表示の処理
                    }) {
                        Text("すべての記録を表示")
                            .font(.subheadline)
                            .foregroundColor(.primaryApp)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius)
                                    .fill(Color(UIColor.secondarySystemBackground))
                            )
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }
    
    // MARK: - 給餌履歴タブ
    private var feedingHistoryTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            if feedingViewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if feedingViewModel.feedingLogs.isEmpty {
                emptyStateView(
                    icon: "cup.and.saucer.fill",
                    title: "給餌記録がありません",
                    message: "「+」ボタンまたはクイックアクションから給餌記録を追加しましょう"
                )
            } else {
                Text("最近の給餌記録")
                    .font(.headline)
                    .padding(.horizontal, 16)
                ForEach(feedingViewModel.feedingLogs.prefix(5)) { log in
                    FeedingLogItemView(log: log)
                        .padding(.horizontal, 16)
                }
                if feedingViewModel.feedingLogs.count > 5 {
                    Button(action: {
                        // 全記録表示の処理
                    }) {
                        Text("すべての記録を表示")
                            .font(.subheadline)
                            .foregroundColor(.primaryApp)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius)
                                    .fill(Color(UIColor.secondarySystemBackground))
                            )
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }
    
    // MARK: - 健康履歴タブ
    private var healthHistoryTab: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 16) {
                Text("体重履歴")
                    .font(.headline)
                    .padding(.horizontal, 16)
                if healthViewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if healthViewModel.weightLogs.isEmpty {
                    emptyStateView(
                        icon: "scalemass.fill",
                        title: "体重記録がありません",
                        message: "「+」ボタンから体重記録を追加しましょう"
                    )
                } else {
                    HStack(spacing: 20) {
                        let weightStats = healthViewModel.getWeightStats(for: pet.id)
                        if let latest = weightStats.latest, let unit = weightStats.unit {
                            StatusCardView(
                                title: "最新の体重",
                                value: "\(String(format: "%.1f", latest)) \(unit)",
                                icon: "scalemass.fill",
                                color: .accentApp
                            )
                        }
                        if let average = weightStats.average, let unit = weightStats.unit {
                            StatusCardView(
                                title: "平均体重",
                                value: "\(String(format: "%.1f", average)) \(unit)",
                                icon: "number.square.fill",
                                color: .infoApp
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    ForEach(healthViewModel.weightLogs.prefix(3)) { log in
                        HStack {
                            VStack(alignment: .leading) {
                                Text("\(String(format: "%.1f", log.weight)) \(log.unit)")
                                    .font(.headline)
                                Text(log.date.formattedDate)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if !log.notes.isEmpty {
                                Text(log.notes)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius)
                                .fill(Color(UIColor.secondarySystemBackground).opacity(0.5))
                        )
                        .padding(.horizontal, 16)
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 16) {
                Text("ワクチン接種履歴")
                    .font(.headline)
                    .padding(.horizontal, 16)
                if healthViewModel.vaccinations.isEmpty {
                    emptyStateView(
                        icon: "syringe.fill",
                        title: "ワクチン記録がありません",
                        message: "「+」ボタンからワクチン記録を追加しましょう"
                    )
                } else {
                    ForEach(healthViewModel.vaccinations.prefix(3)) { vaccination in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(vaccination.name)
                                .font(.headline)
                            HStack {
                                Text("接種日: \(vaccination.date.formattedDate)")
                                    .font(.subheadline)
                                Spacer()
                                if let expiryDate = vaccination.expiryDate {
                                    Text("有効期限: \(expiryDate.formattedDate)")
                                        .font(.subheadline)
                                        .foregroundColor(expiryDate < Date() ? .red : .primary)
                                }
                            }
                            if !vaccination.notes.isEmpty {
                                Text(vaccination.notes)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius)
                                .fill(Color(UIColor.secondarySystemBackground).opacity(0.5))
                        )
                        .padding(.horizontal, 16)
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 16) {
                Text("健康記録")
                    .font(.headline)
                    .padding(.horizontal, 16)
                if healthViewModel.healthLogs.isEmpty {
                    emptyStateView(
                        icon: "cross.case.fill",
                        title: "健康記録がありません",
                        message: "「+」ボタンから健康状態を記録しましょう"
                    )
                } else {
                    ForEach(healthViewModel.healthLogs.prefix(3)) { log in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("状態: \(log.condition)")
                                    .font(.headline)
                                    .foregroundColor(healthConditionColor(log.condition))
                                Spacer()
                                Text(log.date.formattedDate)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            if !log.symptoms.isEmpty {
                                Text("症状: \(log.symptoms)")
                                    .font(.subheadline)
                            }
                            if !log.medication.isEmpty {
                                Text("投薬: \(log.medication)")
                                    .font(.subheadline)
                            }
                            if !log.notes.isEmpty {
                                Text(log.notes)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius)
                                .fill(Color(UIColor.secondarySystemBackground).opacity(0.5))
                        )
                        .padding(.horizontal, 16)
                    }
                }
            }
        }
    }
    
    // MARK: - 健康状態に応じた色
    private func healthConditionColor(_ condition: String) -> Color {
        switch condition {
        case "良好":
            return .green
        case "注意":
            return .orange
        case "不調":
            return .red
        default:
            return .primary
        }
    }
    
    // MARK: - 空の状態表示
    private func emptyStateView(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundColor(Color.secondary.opacity(0.7))
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}

// MARK: - SharedPetController
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
        
        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
            parent.petViewModel.syncWithCloudKit()
            parent.onDismiss()
        }
        
        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
            parent.petViewModel.syncWithCloudKit()
            parent.onDismiss()
        }
        
        func itemTitle(for csc: UICloudSharingController) -> String? {
            return "\(parent.petToShare.name)のケア共有"
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }
    
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        DispatchQueue.main.async {
            CloudKitManager().presentSharingUI(for: petToShare, from: rootViewController) { result in
                switch result {
                case .success:
                    print("Sharing UI presented successfully")
                case .failure(let error):
                    print("Error presenting sharing UI: \(error)")
                    onDismiss()
                }
            }
        }
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) { }
}

// MARK: - CareLogItemView（最低限の実装）
struct CareLogItemView: View {
    let log: CareLogModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(log.type)
                .font(.headline)
            Text(log.timestamp, style: .date)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
}
