import SwiftUI

struct HealthLogView: View {
    @ObservedObject var petViewModel: PetViewModel
    @ObservedObject var healthViewModel: HealthViewModel
    
    @State private var showingAddHealthLog = false
    @State private var showingAddWeightLog = false
    @State private var showingAddVaccination = false
    @State private var activeTab = 0
    
    private let tabs = ["健康記録", "体重記録", "ワクチン"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // ペット選択セクション
                if let selectedPet = petViewModel.selectedPet {
                    petSelectorView
                    
                    // タブ選択
                    tabSelectionView
                    
                    // タブコンテンツ
                    tabContentView(for: selectedPet.id)
                } else {
                    noPetSelectedView
                }
            }
            .navigationTitle("健康管理")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if petViewModel.selectedPet != nil {
                        Menu {
                            Button(action: {
                                showingAddHealthLog = true
                            }) {
                                Label("健康記録を追加", systemImage: "heart.text.square")
                            }
                            
                            Button(action: {
                                showingAddWeightLog = true
                            }) {
                                Label("体重記録を追加", systemImage: "scalemass.fill")
                            }
                            
                            Button(action: {
                                showingAddVaccination = true
                            }) {
                                Label("ワクチン記録を追加", systemImage: "syringe.fill")
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddHealthLog) {
                if let pet = petViewModel.selectedPet {
                    HealthLogEntryView(pet: pet, healthViewModel: healthViewModel)
                }
            }
            .sheet(isPresented: $showingAddWeightLog) {
                if let pet = petViewModel.selectedPet {
                    WeightLogEntryView(pet: pet, healthViewModel: healthViewModel)
                }
            }
            .sheet(isPresented: $showingAddVaccination) {
                if let pet = petViewModel.selectedPet {
                    VaccinationEntryView(pet: pet, healthViewModel: healthViewModel)
                }
            }
            .onChange(of: petViewModel.selectedPet) { oldValue, newValue in
                if let petId = newValue?.id {
                    loadHealthData(for: petId)
                }
            }
            .onAppear {
                if let petId = petViewModel.selectedPet?.id {
                    loadHealthData(for: petId)
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
    
    // タブ選択ビュー
    private var tabSelectionView: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { index in
                Button(action: {
                    activeTab = index
                }) {
                    VStack(spacing: 8) {
                        Text(tabs[index])
                            .font(.subheadline)
                            .fontWeight(activeTab == index ? .semibold : .regular)
                        
                        Rectangle()
                            .frame(height: 3)
                            .foregroundColor(activeTab == index ? .primaryApp : .clear)
                    }
                    .foregroundColor(activeTab == index ? .primaryApp : .secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 8)
    }
    
    // タブコンテンツビュー
    private func tabContentView(for petId: UUID) -> some View {
        Group {
            if healthViewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        switch activeTab {
                        case 0:
                            healthLogContent(for: petId)
                        case 1:
                            weightLogContent(for: petId)
                        case 2:
                            vaccinationContent(for: petId)
                        default:
                            EmptyView()
                        }
                    }
                    .padding(.bottom, 30)
                }
            }
        }
    }
    
    // 健康記録コンテンツ
    private func healthLogContent(for petId: UUID) -> some View {
        VStack(spacing: 16) {
            if healthViewModel.healthLogs.isEmpty {
                emptyStateView(
                    icon: "heart.text.square",
                    title: "健康記録がありません",
                    message: "「+」ボタンから健康状態を記録しましょう"
                )
            } else {
                ForEach(healthViewModel.healthLogs) { log in
                    healthLogCard(log: log)
                        .padding(.horizontal)
                }
            }
        }
        .padding(.top, 16)
    }
    
    // 健康記録カード
    private func healthLogCard(log: HealthLogModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // 健康状態インジケーター
                Circle()
                    .fill(healthConditionColor(log.condition))
                    .frame(width: 12, height: 12)
                
                Text(log.condition)
                    .font(.headline)
                    .foregroundColor(healthConditionColor(log.condition))
                
                Spacer()
                
                Text(log.date.formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            if !log.symptoms.isEmpty {
                detailRow(title: "症状", content: log.symptoms)
            }
            
            if !log.medication.isEmpty {
                detailRow(title: "投薬", content: log.medication)
            }
            
            if !log.notes.isEmpty {
                detailRow(title: "メモ", content: log.notes)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius)
                .fill(Color.backgroundPrimary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius)
                .stroke(healthConditionColor(log.condition).opacity(0.3), lineWidth: 1)
        )
        .contextMenu {
            Button(role: .destructive, action: {
                healthViewModel.deleteHealthLog(id: log.id)
            }) {
                Label("削除", systemImage: "trash")
            }
        }
    }
    
    // 体重記録コンテンツ
    private func weightLogContent(for petId: UUID) -> some View {
        VStack(spacing: 16) {
            if healthViewModel.weightLogs.isEmpty {
                emptyStateView(
                    icon: "scalemass.fill",
                    title: "体重記録がありません",
                    message: "「+」ボタンから体重を記録しましょう"
                )
            } else {
                // 体重統計
                weightStatsView(for: petId)
                    .padding(.horizontal)
                
                // 体重履歴
                ForEach(healthViewModel.weightLogs) { log in
                    weightLogCard(log: log)
                        .padding(.horizontal)
                }
            }
        }
        .padding(.top, 16)
    }
    
    // 体重統計ビュー
    private func weightStatsView(for petId: UUID) -> some View {
        let stats = healthViewModel.getWeightStats(for: petId)
        
        return HStack {
            if let latest = stats.latest, let unit = stats.unit {
                StatusCardView(
                    title: "最新",
                    value: "\(String(format: "%.1f", latest)) \(unit)",
                    icon: "scalemass.fill",
                    color: .accentApp
                )
            }
            
            if let average = stats.average, let unit = stats.unit {
                StatusCardView(
                    title: "平均",
                    value: "\(String(format: "%.1f", average)) \(unit)",
                    icon: "number.square.fill",
                    color: .infoApp
                )
            }
        }
    }
    
    // 体重記録カード
    private func weightLogCard(log: WeightLogModel) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(String(format: "%.1f", log.weight)) \(log.unit)")
                    .font(.title3)
                    .fontWeight(.bold)
                
                Text(log.date.formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if !log.notes.isEmpty {
                Text(log.notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.4, alignment: .trailing)
            }
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
        .contextMenu {
            Button(role: .destructive, action: {
                healthViewModel.deleteWeightLog(id: log.id)
            }) {
                Label("削除", systemImage: "trash")
            }
        }
    }
    
    // ワクチン記録コンテンツ
    private func vaccinationContent(for petId: UUID) -> some View {
        VStack(spacing: 16) {
            if healthViewModel.vaccinations.isEmpty {
                emptyStateView(
                    icon: "syringe.fill",
                    title: "ワクチン記録がありません",
                    message: "「+」ボタンからワクチン接種を記録しましょう"
                )
            } else {
                ForEach(healthViewModel.vaccinations) { vaccination in
                    vaccinationCard(vaccination: vaccination)
                        .padding(.horizontal)
                }
            }
        }
        .padding(.top, 16)
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
    
    // 健康状態に応じた色を返す
    private func healthConditionColor(_ condition: String) -> Color {
        switch condition {
        case "良好":
            return .successApp
        case "注意":
            return .warningApp
        case "不調":
            return .errorApp
        default:
            return .textPrimary
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
        .frame(maxWidth: .infinity)
    }
    
    // 健康データの読み込み
    private func loadHealthData(for petId: UUID) {
        healthViewModel.fetchHealthLogs(for: petId)
        healthViewModel.fetchWeightLogs(for: petId)
        healthViewModel.fetchVaccinations(for: petId)
    }
}

// 健康記録入力ビュー
struct HealthLogEntryView: View {
    let pet: PetModel
    @ObservedObject var healthViewModel: HealthViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var condition = "良好"
    @State private var symptoms = ""
    @State private var medication = ""
    @State private var notes = ""
    @State private var date = Date()
    
    private let conditionOptions = ["良好", "注意", "不調"]
    
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
                
                Section(header: Text("健康状態")) {
                    Picker("状態", selection: $condition) {
                        ForEach(conditionOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    TextField("症状（任意）", text: $symptoms)
                    TextField("投薬（任意）", text: $medication)
                }
                
                Section(header: Text("詳細")) {
                    DatePicker("日付", selection: $date, displayedComponents: .date)
                    TextField("メモ（任意）", text: $notes)
                }
            }
            .navigationTitle("健康記録を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        healthViewModel.addHealthLog(
                            petId: pet.id,
                            condition: condition,
                            symptoms: symptoms,
                            medication: medication,
                            notes: notes,
                            date: date
                        )
                        dismiss()
                    }
                }
            }
        }
    }
}
