import SwiftUI
import CoreData

struct CareLogView: View {
    @ObservedObject var petViewModel: PetViewModel
    @ObservedObject var careViewModel: CareViewModel
    
    @State private var showingAddCare = false
    @State private var selectedDate = Date()
    @State private var showingDatePicker = false
    
    private let calendar = Calendar.current
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // ペット選択セクション
                if let selectedPet = petViewModel.selectedPet {
                    petSelectorView
                    
                    // クイックケアボタン
                    quickCareButtonsView
                    
                    // ケア記録リスト
                    careLogListView
                } else {
                    noPetSelectedView
                }
            }
            .navigationTitle("ケア記録")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddCare = true
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
            .sheet(isPresented: $showingAddCare) {
                if let selectedPet = petViewModel.selectedPet {
                    CareEntryView(pet: selectedPet, careViewModel: careViewModel)
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
            .onChange(of: petViewModel.selectedPet) { newPet in
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
    
    // クイックケアボタン
    private var quickCareButtonsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Constants.CareTypes.all, id: \.self) { type in
                    Button(action: {
                        if let petId = petViewModel.selectedPet?.id {
                            careViewModel.addCareLog(
                                petId: petId,
                                type: type,
                                notes: "",
                                performedBy: UIDevice.current.name
                            )
                        }
                    }) {
                        VStack {
                            ZStack {
                                Circle()
                                    .fill(Color.forCareType(type).opacity(0.2))
                                    .frame(width: 50, height: 50)
                                
                                Image(systemName: careTypeIcon(for: type))
                                    .font(.title3)
                                    .foregroundColor(Color.forCareType(type))
                            }
                            
                            Text(type)
                                .font(.caption)
                                .foregroundColor(.textPrimary)
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    // ケア記録リストビュー
    private var careLogListView: some View {
        Group {
            if careViewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if careViewModel.careLogs.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "heart.text.square")
                        .font(.system(size: 50))
                        .foregroundColor(.secondaryApp.opacity(0.7))
                    
                    Text("この日のケア記録がありません")
                        .font(.headline)
                    
                    Text("上のクイックケアボタンを使って記録を追加しましょう")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(careViewModel.careLogs) { log in
                        CareLogItemView(log: log)
                            .swipeActions {
                                Button(role: .destructive) {
                                    careViewModel.deleteCareLog(id: log.id)
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
    
    // ケアタイプに応じたアイコンを返す
    private func careTypeIcon(for type: String) -> String {
        switch type {
        case Constants.CareTypes.walk:
            return "figure.walk"
        case Constants.CareTypes.feeding:
            return "cup.and.saucer.fill"
        case Constants.CareTypes.grooming:
            return "scissors"
        case Constants.CareTypes.medication:
            return "pills.fill"
        case Constants.CareTypes.healthCheck:
            return "stethoscope"
        default:
            return "heart.fill"
        }
    }
    
    // 選択日付のログを取得
    private func fetchLogsForSelectedDate(petId: UUID) {
        let startOfDay = calendar.startOfDay(for: selectedDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!.addingTimeInterval(-1)
        
        let context = PersistenceController.shared.container.viewContext
        let request = NSFetchRequest<CareLog>(entityName: "CareLog")
        request.predicate = NSPredicate(format: "pet.id == %@ AND timestamp >= %@ AND timestamp <= %@",
                                         petId as CVarArg, startOfDay as CVarArg, endOfDay as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        
        do {
            let fetchedLogs = try context.fetch(request)
            careViewModel.careLogs = fetchedLogs.map { CareLogModel(entity: $0) }
        } catch {
            print("Error fetching care logs for date: \(error)")
            careViewModel.careLogs = []
        }
    }
}

// 各ケア記録アイテムのビュー
struct CareLogItemView: View {
    let log: CareLogModel
    
    var body: some View {
        HStack(spacing: 16) {
            // ケアタイプアイコン
            ZStack {
                Circle()
                    .fill(Color.forCareType(log.type).opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: iconForCareType(log.type))
                    .foregroundColor(Color.forCareType(log.type))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(log.type)
                    .font(.headline)
                
                Text(log.timestamp.formattedTime)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
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
    
    // ケアタイプに応じたアイコンを返す
    private func iconForCareType(_ type: String) -> String {
        switch type {
        case Constants.CareTypes.walk:
            return "figure.walk"
        case Constants.CareTypes.feeding:
            return "cup.and.saucer.fill"
        case Constants.CareTypes.grooming:
            return "scissors"
        case Constants.CareTypes.medication:
            return "pills.fill"
        case Constants.CareTypes.healthCheck:
            return "stethoscope"
        default:
            return "heart.fill"
        }
    }
}

// 日付選択ビュー
struct DatePickerView: View {
    @Binding var selectedDate: Date
    let onSelect: (Date) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var internalDate: Date
    
    init(selectedDate: Binding<Date>, onSelect: @escaping (Date) -> Void) {
        self._selectedDate = selectedDate
        self.onSelect = onSelect
        self._internalDate = State(initialValue: selectedDate.wrappedValue)
    }
    
    var body: some View {
        NavigationView {
            VStack {
                DatePicker("日付を選択", selection: $internalDate, displayedComponents: .date)
                    .datePickerStyle(GraphicalDatePickerStyle())
                    .padding()
            }
            .navigationTitle("日付選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("決定") {
                        onSelect(internalDate)
                    }
                }
            }
        }
    }
}
