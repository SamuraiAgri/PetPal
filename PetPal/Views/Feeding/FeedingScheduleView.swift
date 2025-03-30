// PetPal/Views/Feeding/FeedingScheduleView.swift
import SwiftUI
import CoreData

struct FeedingScheduleView: View {
    @ObservedObject var petViewModel: PetViewModel
    @ObservedObject var feedingViewModel: FeedingViewModel
    
    @State private var showingAddFeeding = false
    @State private var selectedDate = Date()
    @State private var showingDatePicker = false
    
    private let calendar = Calendar.current
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // ペット選択セクション
                if petViewModel.selectedPet != nil {
                    petSelectorView
                    
                    // クイック給餌ボタン
                    quickFeedingView
                    
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
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingDatePicker.toggle()
                    }) {
                        HStack {
                            Image(systemName: "calendar")
                            Text(selectedDate.formattedDate)
                                .font(.subheadline)
                        }
                    }
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
                        // 選択した日付の記録を表示
                        fetchLogsForSelectedDate(petId: petId)
                    }
                })
            }
            .onChange(of: petViewModel.selectedPet) { _, newPet in
                if let petId = newPet?.id {
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
    
    // クイック給餌ビュー
    private var quickFeedingView: some View {
        VStack(spacing: 12) {
            Text("クイック給餌")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, 12)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    Button(action: {
                        if let petId = petViewModel.selectedPet?.id {
                            feedingViewModel.addFeedingLog(
                                petId: petId,
                                foodType: "ドライフード",
                                amount: 100,
                                unit: "g",
                                notes: "朝の給餌",
                                performedBy: UIDevice.current.name
                            )
                        }
                    }) {
                        quickFeedingButton(title: "ドライフード", amount: "100g", icon: "bowl.fill")
                    }
                    
                    Button(action: {
                        if let petId = petViewModel.selectedPet?.id {
                            feedingViewModel.addFeedingLog(
                                petId: petId,
                                foodType: "ウェットフード",
                                amount: 50,
                                unit: "g",
                                notes: "夕方の給餌",
                                performedBy: UIDevice.current.name
                            )
                        }
                    }) {
                        quickFeedingButton(title: "ウェットフード", amount: "50g", icon: "fork.knife")
                    }
                    
                    Button(action: {
                        if let petId = petViewModel.selectedPet?.id {
                            feedingViewModel.addFeedingLog(
                                petId: petId,
                                foodType: "おやつ",
                                amount: 10,
                                unit: "g",
                                notes: "ご褒美",
                                performedBy: UIDevice.current.name
                            )
                        }
                    }) {
                        quickFeedingButton(title: "おやつ", amount: "10g", icon: "star.fill")
                    }
                    
                    Button(action: {
                        if let petId = petViewModel.selectedPet?.id {
                            feedingViewModel.addFeedingLog(
                                petId: petId,
                                foodType: "水",
                                amount: 200,
                                unit: "ml",
                                notes: "水の交換",
                                performedBy: UIDevice.current.name
                            )
                        }
                    }) {
                        quickFeedingButton(title: "水", amount: "水交換", icon: "drop.fill")
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 12)
            }
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.feedingApp.opacity(0.15), Color.backgroundSecondary.opacity(0.3)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .padding(.horizontal, 12)
    }

    private func quickFeedingButton(title: String, amount: String, icon: String) -> some View {
        VStack {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.feedingApp.opacity(0.3), Color.feedingApp.opacity(0.1)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 110, height: 90)
                    .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                
                VStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(.feedingApp)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(Color.white)
                                .shadow(color: Color.feedingApp.opacity(0.3), radius: 2, x: 0, y: 1)
                        )
                    
                    Text(title)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.textPrimary)
                    
                    Text(amount)
                        .font(.caption2)
                        .foregroundColor(.textSecondary)
                }
                .padding(8)
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
                    
                    Text("上のクイック給餌ボタンを使って記録を追加しましょう")
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
        VStack(spacing: 24) {
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
                    .foregroundColor(Color.secondaryApp)
            }
            
            Text("ペットが選択されていません")
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
            Text("「ペット」タブでペットを選択してください")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            if !petViewModel.pets.isEmpty {
                Button(action: {
                    petViewModel.selectPet(id: petViewModel.pets[0].id)
                }) {
                    Text("最初のペットを選択")
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
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.backgroundPrimary)
    }
    
    private func fetchLogsForSelectedDate(petId: UUID) {
        let startOfDay = calendar.startOfDay(for: selectedDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!.addingTimeInterval(-1)
        
        let context = PersistenceController.shared.container.viewContext
        let request = NSFetchRequest<FeedingLog>(entityName: "FeedingLog")
        request.predicate = NSPredicate(format: "ANY pet.id == %@ AND timestamp >= %@ AND timestamp <= %@",
                                         petId as CVarArg, startOfDay as CVarArg, endOfDay as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FeedingLog.timestamp, ascending: false)]
        
        do {
            let fetchedLogs = try context.fetch(request)
            feedingViewModel.feedingLogs = fetchedLogs.map { FeedingLogModel(entity: $0) }
        } catch {
            print("Error fetching feeding logs for date: \(error)")
            feedingViewModel.feedingLogs = []
        }
    }
}

// 各給餌記録アイテムのビュー
struct FeedingLogItemView: View {
    let log: FeedingLogModel
    
    var body: some View {
        HStack(spacing: 16) {
            // 給餌タイプアイコン
            ZStack {
                Circle()
                    .fill(Color.feedingApp.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: iconForFoodType(log.foodType))
                    .foregroundColor(.feedingApp)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(log.foodType)
                    .font(.headline)
                
                HStack {
                    Text("\(String(format: "%.1f", log.amount)) \(log.unit)")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    Text(log.timestamp.formattedTime)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if !log.notes.isEmpty {
                    Text(log.notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("実施者:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(log.performedBy)
                    .font(.footnote)
            }
        }
        .padding(.vertical, 8)
    }
    
    // 食事タイプに応じたアイコンを返す
    private func iconForFoodType(_ type: String) -> String {
        switch type.lowercased() {
        case "ドライフード", "dry", "dry food":
            return "bowl.fill"
        case "ウェットフード", "wet", "wet food", "缶詰":
            return "fork.knife"
        case "おやつ", "snack", "treat":
            return "star.fill"
        case "水", "water":
            return "drop.fill"
        case "サプリメント", "supplement":
            return "pill.fill"
        default:
            return "cup.and.saucer.fill"
        }
    }
}
