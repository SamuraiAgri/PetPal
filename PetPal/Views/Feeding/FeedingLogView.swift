import SwiftUI

struct FeedingLogView: View {
    @ObservedObject var petViewModel: PetViewModel
    @ObservedObject var feedingViewModel: FeedingViewModel
    
    @State private var showingAddFeeding = false
    @State private var selectedDate = Date()
    @State private var showingDatePicker = false
    @State private var showingFilterOptions = false
    @State private var selectedFoodType: String? = nil
    
    private let calendar = Calendar.current
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // ペット選択セクション
                if let selectedPet = petViewModel.selectedPet {
                    petSelectorView
                    
                    // 日付選択とフィルターエリア
                    dateAndFilterView
                    
                    // 給餌統計サマリー
                    feedingSummaryView(for: selectedPet.id)
                    
                    // 給餌記録リスト
                    feedingLogListView
                } else {
                    noPetSelectedView
                }
            }
            .navigationTitle("給餌記録")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddFeeding = true
                    }) {
                        Image(systemName: "plus")
                    }
                    .disabled(petViewModel.selectedPet == nil)
                }
            }
            .sheet(isPresented: $showingAddFeeding) {
                if let selectedPet = petViewModel.selectedPet {
                    FeedingLogEntryView(pet: selectedPet, feedingViewModel: feedingViewModel)
                }
            }
            .sheet(isPresented: $showingDatePicker) {
                DatePickerView(selectedDate: $selectedDate, onSelect: { date in
                    selectedDate = date
                    showingDatePicker = false
                    
                    if let petId = petViewModel.selectedPet?.id {
                        fetchLogsForSelectedDate(petId: petId)
                    }
                })
            }
            .onChange(of: petViewModel.selectedPet) { _ in
                if let petId = petViewModel.selectedPet?.id {
                    fetchLogsForSelectedDate(petId: petId)
                }
            }
            .onAppear {
                if let petId = petViewModel.selectedPet?.id {
                    fetchLogsForSelectedDate(petId: petId)
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
    
    // 日付とフィルターセレクタ
    private var dateAndFilterView: some View {
        HStack {
            // 日付選択ボタン
            Button(action: {
                showingDatePicker.toggle()
            }) {
                HStack {
                    Image(systemName: "calendar")
                    Text(selectedDate.formattedDate)
                        .font(.subheadline)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.backgroundSecondary)
                )
            }
            .foregroundColor(.primary)
            
            Spacer()
            
            // フィルターボタン
            Button(action: {
                showingFilterOptions.toggle()
            }) {
                HStack {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                    Text(selectedFoodType ?? "すべて")
                        .font(.subheadline)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.backgroundSecondary)
                )
            }
            .foregroundColor(.primary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        
        // フィルターオプション
        if showingFilterOptions {
            VStack(alignment: .leading, spacing: 8) {
                Text("フードタイプでフィルター")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // すべて表示オプション
                        filterChip(title: "すべて", isSelected: selectedFoodType == nil) {
                            selectedFoodType = nil
                            if let petId = petViewModel.selectedPet?.id {
                                fetchLogsForSelectedDate(petId: petId)
                            }
                        }
                        
                        // 一般的なフードタイプオプション
                        let commonTypes = ["ドライフード", "ウェットフード", "おやつ", "水"]
                        ForEach(commonTypes, id: \.self) { type in
                            filterChip(title: type, isSelected: selectedFoodType == type) {
                                selectedFoodType = type
                                if let petId = petViewModel.selectedPet?.id {
                                    fetchLogsForSelectedDate(petId: petId, foodType: type)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
            .padding(.horizontal)
            .background(Color.backgroundSecondary.opacity(0.3))
        }
    }
    
    // フィルターチップ
    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? Color.feedingApp.opacity(0.2) : Color.backgroundPrimary)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? Color.feedingApp : Color.gray.opacity(0.3), lineWidth: 1)
                )
        }
        .foregroundColor(isSelected ? .feedingApp : .primary)
    }
    
    // 給餌サマリー
    private func feedingSummaryView(for petId: UUID) -> some View {
        let dailyStats = feedingViewModel.getDailyFeedingAmount(petId: petId, date: selectedDate)
        
        return VStack(alignment: .leading, spacing: 8) {
            if !dailyStats.isEmpty {
                Text("本日の給餌サマリー")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(dailyStats, id: \.foodType) { stat in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(stat.foodType)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                HStack(alignment: .firstTextBaseline) {
                                    Text("\(String(format: "%.1f", stat.amount))")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                    
                                    Text(stat.unit)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .frame(minWidth: 120)
                            .background(
                                RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius)
                                    .fill(Color.feedingApp.opacity(0.1))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius)
                                    .stroke(Color.feedingApp.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 8)
            }
        }
    }
    
    // 給餌記録リストビュー
    private var feedingLogListView: some View {
        Group {
            if feedingViewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if feedingViewModel.feedingLogs.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.feedingApp.opacity(0.7))
                    
                    Text("この日の給餌記録がありません")
                        .font(.headline)
                    
                    Text("「+」ボタンを押して記録を追加しましょう")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(feedingViewModel.feedingLogs) { log in
                        FeedingLogItemView(log: log)
                            .swipeActions {
                                Button(role: .destructive) {
                                    feedingViewModel.deleteFeedingLog(id: log.id)
                                } label: {
                                    Label("削除", systemImage: "trash")
                                }
                            }
                    }
                }
            }
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
    
    // 選択日付のログを取得
    private func fetchLogsForSelectedDate(petId: UUID, foodType: String? = nil) {
        let startOfDay = calendar.startOfDay(for: selectedDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!.addingTimeInterval(-1)
        
        let request: NSFetchRequest<FeedingLog> = FeedingLog.fetchRequest()
        
        var predicates: [NSPredicate] = [
            NSPredicate(format: "pet.id == %@", petId as CVarArg),
            NSPredicate(format: "timestamp >= %@ AND timestamp <= %@", startOfDay as CVarArg, endOfDay as CVarArg)
        ]
        
        if let foodType = foodType {
            predicates.append(NSPredicate(format: "foodType == %@", foodType))
        }
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FeedingLog.timestamp, ascending: false)]
        
        do {
            let context = PersistenceController.shared.container.viewContext
            let fetchedLogs = try context.fetch(request)
            feedingViewModel.feedingLogs = fetchedLogs.map { FeedingLogModel(entity: $0) }
        } catch {
            print("Error fetching feeding logs for date: \(error)")
            feedingViewModel.feedingLogs = []
        }
    }
}
