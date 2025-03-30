// PetPal/Views/Main/MainTabView.swift

import SwiftUI
import CoreData

struct MainTabView: View {
    @StateObject private var petViewModel: PetViewModel
    @StateObject private var careViewModel = CareViewModel()
    @StateObject private var feedingViewModel = FeedingViewModel()
    @StateObject private var healthViewModel = HealthViewModel()
    
    @State private var showingSettings = false
    
    init(context: NSManagedObjectContext) {
        _petViewModel = StateObject(wrappedValue: PetViewModel(context: context))
    }
    
    var body: some View {
        TabView {
            PetListView(petViewModel: petViewModel)
                .tabItem {
                    Label("ペット", systemImage: "pawprint.fill")
                }
            
            CareLogView(petViewModel: petViewModel, careViewModel: careViewModel)
                .tabItem {
                    Label("ケア記録", systemImage: "heart.fill")
                }
            
            FeedingScheduleView(petViewModel: petViewModel, feedingViewModel: feedingViewModel)
                .tabItem {
                    Label("給餌", systemImage: "cup.and.saucer.fill")
                }
            
            HealthLogView(petViewModel: petViewModel, healthViewModel: healthViewModel)
                .tabItem {
                    Label("健康", systemImage: "cross.case.fill")
                }
            
            PetGuideView()
                .tabItem {
                    Label("ガイド", systemImage: "book.fill")
                }
        }
        .tint(Color.primaryApp)
        .accentColor(Color.primaryApp)  // タブバーの色を鮮やかに
        .overlay(
            // 設定ボタンオーバーレイをより魅力的に - 位置調整
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(
                                Circle()
                                    .fill(Color.primaryApp.opacity(0.9))
                                    .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 3)
                            )
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 45)  // 上部に余白を追加して他のボタンとの重なりを防ぐ
                }
                Spacer()
            }
        )
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(petViewModel)
        }
        .environmentObject(petViewModel)
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        MainTabView(context: context)
    }
}
