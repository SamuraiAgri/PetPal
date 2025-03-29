import SwiftUI

struct WeightLogView: View {
    @ObservedObject var petViewModel: PetViewModel
    @ObservedObject var healthViewModel: HealthViewModel
    
    @State private var showingAddWeight = false
    @State private var selectedTimeRange = 1 // 0: 最近3件, 1: 1ヶ月, 2: 3ヶ月, 3: 6ヶ月, 4: 1年, 5: すべて
    
    private let timeRanges = ["最近3件", "1ヶ月", "3ヶ月", "6ヶ月", "1年", "すべて"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // ペット選択セクション
                if let selectedPet = petViewModel.selectedPet {
                    petSelectorView
                    
                    // 統計情報
                    if !healthViewModel.weightLogs.isEmpty {
                        weightStatsView(for: selectedPet.id)
                    }
                    
                    // 期間選択
                    timeRangeSelectionView
                    
                    // 体重記録リスト
                    weightLogListView
                } else {
                    noPetSelectedView
                }
            }
            .navigationTitle("体重記録")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddWeight = true
                    }) {
                        Image(systemName: "plus")
                    }
                    .disabled(petViewModel.selectedPet == nil)
                }
            }
            .sheet(isPresented: $showingAddWeight) {
                if let pet = petViewModel.selectedPet {
                    WeightLogEntryView(pet: pet, healthViewModel: healthViewModel)
                }
            }
            .onChange(of: petViewModel.selectedPet) { _ in
                if let petId = petViewModel.selectedPet?.id {
                    healthViewModel.fetchWeightLogs(for: petId)
                }
            }
            .onAppear {
                if let petId = petViewModel.selectedPet?.id {
                    healthViewModel.fetchWeightLogs(for: petId)
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
    
    // 体重統計ビュー
    private func weightStatsView(for petId: UUID) -> some View {
        let weightStats = healthViewModel.getWeightStats(for: petId)
        
        return VStack(spacing: 8) {
            Text("体重統計")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, 8)
            
            HStack {
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
            .padding(.horizontal)
            
            HStack {
                if let min = weightStats.min, let unit = weightStats.unit {
                    StatusCardView(
                        title: "最小体重",
                        value: "\(String(format: "%.1f", min)) \(unit)",
                        icon: "arrow.down.circle.fill",
                        color: .successApp
                    )
                }
                
                if let max = weightStats.max, let unit = weightStats.unit {
                    StatusCardView(
                        title: "最大体重",
                        value: "\(String(format: "%.1f", max)) \(unit)",
                        icon: "arrow.up.circle.fill",
                        color: .warningApp
                    )
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .background(Color.backgroundSecondary.opacity(0.2))
    }
    
    // 期間選択ビュー
    private var timeRangeSelectionView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(0..<timeRanges.count, id: \.self) { index in
                    Button(action: {
                        selectedTimeRange = index
                    }) {
                        Text(timeRanges[index])
                            .font(.caption)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(selectedTimeRange == index ? Color.accentApp.opacity(0.2) : Color.backgroundPrimary)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(selectedTimeRange == index ? Color.accentApp : Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .foregroundColor(selectedTimeRange == index ? .accentApp : .primary)
                }
            }
            .padding()
        }
    }
    
    // 体重記録リストビュー
    private var weightLogListView: some View {
        Group {
            if healthViewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if healthViewModel.weightLogs.isEmpty {
                emptyStateView(
                    icon: "scalemass.fill",
                    title: "体重記録がありません",
                    message: "「+」ボタンから体重を記録しましょう"
                )
            } else {
                let filteredLogs = filterLogsByTimeRange(healthViewModel.weightLogs)
                
                if filteredLogs.isEmpty {
                    emptyStateView(
                        icon: "scalemass.fill",
                        title: "選択した期間の記録がありません",
                        message: "別の期間を選択するか、「+」ボタンから新しい記録を追加しましょう"
                    )
                } else {
                    List {
                        ForEach(filteredLogs) { log in
                            weightLogRow(log: log)
                                .swipeActions {
                                    Button(role: .destructive) {
                                        healthViewModel.deleteWeightLog(id: log.id)
                                    } label: {
                                        Label("削除", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
        }
    }
    
    // 体重記録行
    private func weightLogRow(log: WeightLogModel) -> some View {
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
        .padding(.vertical, 8)
    }
    
    // 期間によるフィルタリング
    private func filterLogsByTimeRange(_ logs: [WeightLogModel]) -> [WeightLogModel] {
        switch selectedTimeRange {
        case 0: // 最近3件
            return Array(logs.prefix(3))
        case 1: // 1ヶ月
            return logs.filter { log in
                return log.date >= Calendar.current.date(byAdding: .month, value: -1, to: Date())!
            }
        case 2: // 3ヶ月
            return logs.filter { log in
                return log.date >= Calendar.current.date(byAdding: .month, value: -3, to: Date())!
            }
        case 3: // 6ヶ月
            return logs.filter { log in
                return log.date >= Calendar.current.date(byAdding: .month, value: -6, to: Date())!
            }
        case 4: // 1年
            return logs.filter { log in
                return log.date >= Calendar.current.date(byAdding: .year, value: -1, to: Date())!
            }
        case 5: // すべて
            return logs
        default:
            return logs
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
