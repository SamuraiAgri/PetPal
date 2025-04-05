import SwiftUI
import CoreData

struct CareLogView: View {
    @ObservedObject var petViewModel: PetViewModel
    @ObservedObject var careViewModel: CareViewModel
    @ObservedObject var userProfileViewModel: UserProfileViewModel
    
    @State private var showingAddCare = false
    @State private var showingAddSchedule = false
    @State private var selectedDate = Date()
    @State private var showingDatePicker = false
    @State private var activeTab = 0 // 0: 記録, 1: スケジュール
    
    private let calendar = Calendar.current
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // ペット選択セクション
                if let selectedPet = petViewModel.selectedPet {
                    petSelectorView
                    
                    // タブ選択
                    tabSelectionView
                    
                    if activeTab == 0 {
                        // クイックケアボタン
                        quickCareButtonsView
                        
                        // ケア記録リスト
                        careLogListView
                    } else {
                        // ケアスケジュール
                        careScheduleView
                    }
                } else {
                    noPetSelectedView
                }
            }
            .navigationTitle(activeTab == 0 ? "ケア記録" : "ケアスケジュール")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            showingAddCare = true
                        }) {
                            Label("ケア記録を追加", systemImage: "heart.text.square")
                        }
                        
                        Button(action: {
                            showingAddSchedule = true
                        }) {
                            Label("予定を追加", systemImage: "calendar.badge.plus")
                        }
                    } label: {
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
                    CareEntryView(
                        pet: selectedPet,
                        careViewModel: careViewModel,
                        userProfileViewModel: userProfileViewModel
                    )
                }
            }
            .sheet(isPresented: $showingAddSchedule) {
                if let selectedPet = petViewModel.selectedPet {
                    CareScheduleEntryView(
                        pet: selectedPet,
                        careViewModel: careViewModel,
                        userProfileViewModel: userProfileViewModel
                    )
                }
            }
            .sheet(isPresented: $showingDatePicker) {
                DatePickerView(selectedDate: $selectedDate, onSelect: { date in
                    selectedDate = date
                    showingDatePicker = false
                    
                    if let petId = petViewModel.selectedPet?.id {
                        fetchDataForSelectedDate(petId: petId)
                    }
                })
            }
            .onChange(of: petViewModel.selectedPet) { _, newPet in
                if let petId = newPet?.id {
                    fetchDataForSelectedDate(petId: petId)
                }
            }
            .onChange(of: activeTab) { _, newValue in
                if let petId = petViewModel.selectedPet?.id {
                    fetchDataForSelectedDate(petId: petId)
                }
            }
            .onAppear {
                if let petId = petViewModel.selectedPet?.id {
                    fetchDataForSelectedDate(petId: petId)
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
                        
                        // 共有バッジ
                        if pet.isShared {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 10))
                                .padding(4)
                                .background(Circle().fill(Color.infoApp))
                                .foregroundColor(.white)
                                .offset(y: -10)
                        }
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
        HStack {
            Button(action: {
                activeTab = 0
            }) {
                Text("記録")
                    .font(.headline)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(activeTab == 0 ? Color.primaryApp : Color.clear)
                    .foregroundColor(activeTab == 0 ? .white : .primary)
                    .cornerRadius(10)
            }
            
            Button(action: {
                activeTab = 1
            }) {
                Text("スケジュール")
                    .font(.headline)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(activeTab == 1 ? Color.primaryApp : Color.clear)
                    .foregroundColor(activeTab == 1 ? .white : .primary)
                    .cornerRadius(10)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.backgroundSecondary.opacity(0.2))
    }
    
    // クイックケアボタン
    private var quickCareButtonsView: some View {
        VStack(spacing: 8) {
            Text("クイックケア")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, 8)
                
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(Constants.CareTypes.all, id: \.self) { type in
                        Button(action: {
                            if let petId = petViewModel.selectedPet?.id {
                                careViewModel.addCareLog(
                                    petId: petId,
                                    type: type,
                                    notes: ""
                                )
                            }
                        }) {
                            VStack {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [Color.forCareType(type).opacity(0.8), Color.forCareType(type).opacity(0.5)]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 60, height: 60)
                                        .shadow(color: Color.forCareType(type).opacity(0.3), radius: 3, x: 0, y: 2)
                                    
                                    Image(systemName: careTypeIcon(for: type))
                                        .font(.title2)
                                        .foregroundColor(.white)
                                }
                                
                                Text(type)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.textPrimary)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 12)
            }
        }
        .background(Color.backgroundSecondary.opacity(0.5))
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
                        EnhancedCareLogItemView(
                            log: log,
                            currentUserID: userProfileViewModel.currentUser?.id
                        )
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
    
    // ケアスケジュールビュー
    private var careScheduleView: some View {
        Group {
            if careViewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if careViewModel.careSchedules.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "calendar")
                        .font(.system(size: 50))
                        .foregroundColor(.secondaryApp.opacity(0.7))
                    
                    Text("この日のスケジュールがありません")
                        .font(.headline)
                    
                    Text("「+」ボタンから新しいケア予定を追加しましょう")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(careViewModel.careSchedules) { schedule in
                        CareScheduleItemView(
                            schedule: schedule,
                            currentUserID: userProfileViewModel.currentUser?.id,
                            onComplete: {
                                careViewModel.completeCareSchedule(schedule: schedule)
                            }
                        )
                        .swipeActions {
                            Button(role: .destructive) {
                                careViewModel.deleteCareSchedule(id: schedule.id)
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
    
    // 選択日付のデータを取得
    private func fetchDataForSelectedDate(petId: UUID) {
        let startOfDay = calendar.startOfDay(for: selectedDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!.addingTimeInterval(-1)
        
        if activeTab == 0 {
            // ケア記録の取得
            let context = PersistenceController.shared.container.viewContext
            let request = NSFetchRequest<CareLog>(entityName: "CareLog")
            request.predicate = NSPredicate(format: "pet.id == %@ AND timestamp >= %@ AND timestamp <= %@ AND isScheduled == %@",
                                             petId as CVarArg, startOfDay as CVarArg, endOfDay as CVarArg, false as NSNumber)
            request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
            
            do {
                let fetchedLogs = try context.fetch(request)
                careViewModel.careLogs = fetchedLogs.map { CareLogModel(entity: $0) }
                
                // ユーザープロファイル情報を追加
                for i in 0..<careViewModel.careLogs.count {
                    if let userProfileID = careViewModel.careLogs[i].userProfileID {
                        careViewModel.careLogs[i].userProfile = userProfileViewModel.userProfiles.first(where: { $0.id == userProfileID })
                    }
                }
            } catch {
                print("Error fetching care logs for date: \(error)")
                careViewModel.careLogs = []
            }
        } else {
            // ケアスケジュールの取得
            let context = PersistenceController.shared.container.viewContext
            let request = NSFetchRequest<CareSchedule>(entityName: "CareSchedule")
            request.predicate = NSPredicate(format: "pet.id == %@ AND scheduledDate >= %@ AND scheduledDate <= %@",
                                             petId as CVarArg, startOfDay as CVarArg, endOfDay as CVarArg)
            request.sortDescriptors = [NSSortDescriptor(key: "scheduledDate", ascending: true)]
            
            do {
                let fetchedSchedules = try context.fetch(request)
                careViewModel.careSchedules = fetchedSchedules.map { CareScheduleModel(entity: $0) }
                
                // ユーザープロファイル情報を追加
                for i in 0..<careViewModel.careSchedules.count {
                    if let userProfileID = careViewModel.careSchedules[i].assignedUserProfileID {
                        careViewModel.careSchedules[i].assignedUserProfile = userProfileViewModel.userProfiles.first(where: { $0.id == userProfileID })
                    }
                    if let createdByID = careViewModel.careSchedules[i].createdBy {
                        careViewModel.careSchedules[i].createdByProfile = userProfileViewModel.userProfiles.first(where: { $0.id == createdByID })
                    }
                }
            } catch {
                print("Error fetching care schedules for date: \(error)")
                careViewModel.careSchedules = []
            }
        }
    }
}

// ユーザーアバター対応の強化版ケア記録アイテムビュー
struct EnhancedCareLogItemView: View {
    let log: CareLogModel
    let currentUserID: UUID?
    
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
                HStack {
                    Text(log.type)
                        .font(.headline)
                    
                    Spacer()
                    
                    Text(log.timestamp.formattedTime)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // 実施者情報（ユーザーアバター付き）
                HStack {
                    if let profile = log.userProfile {
                        // ユーザーアバターを表示
                        if let avatarData = profile.avatarImageData {
                            Image(uiImage: UIImage(data: avatarData) ?? UIImage())
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 20, height: 20)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color(hex: profile.colorHex) ?? .gray, lineWidth: 1)
                                )
                        } else {
                            // デフォルトアバター
                            Circle()
                                .fill(Color(hex: profile.colorHex) ?? .gray)
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Text(String(profile.name.prefix(1)))
                                        .font(.caption2)
                                        .foregroundColor(.white)
                                )
                        }
                    }
                    
                    Text(log.getPerformerLabel(currentUserID: currentUserID))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                
                if !log.notes.isEmpty {
                    Text(log.notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
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

// ケアスケジュールアイテムビュー
struct CareScheduleItemView: View {
    let schedule: CareScheduleModel
    let currentUserID: UUID?
    let onComplete: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // ケアタイプアイコン
            ZStack {
                Circle()
                    .fill(schedule.getStatusColor().opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: iconForCareType(schedule.type))
                    .foregroundColor(schedule.getStatusColor())
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(schedule.type)
                        .font(.headline)
                    
                    if schedule.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.successApp)
                            .font(.caption)
                    }
                    
                    Spacer()
                    
                    Text(schedule.scheduledDate.formattedTime)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // 担当者情報（ユーザーアバター付き）
                HStack {
                    if let profile = schedule.assignedUserProfile {
                        // ユーザーアバターを表示
                        if let avatarData = profile.avatarImageData {
                            Image(uiImage: UIImage(data: avatarData) ?? UIImage())
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 20, height: 20)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color(hex: profile.colorHex) ?? .gray, lineWidth: 1)
                                )
                        } else {
                            // デフォルトアバター
                            Circle()
                                .fill(Color(hex: profile.colorHex) ?? .gray)
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Text(String(profile.name.prefix(1)))
                                        .font(.caption2)
                                        .foregroundColor(.white)
                                )
                        }
                    }
                    
                    Text(schedule.getAssigneeLabel(currentUserID: currentUserID))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                
                if !schedule.notes.isEmpty {
                    Text(schedule.notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // 完了ボタン（未完了かつ自分の担当の場合のみ表示）
            if !schedule.isCompleted && schedule.assignedUserProfileID == currentUserID {
                Button(action: onComplete) {
                    Image(systemName: "checkmark.circle")
                        .font(.title3)
                        .foregroundColor(.successApp)
                }
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
