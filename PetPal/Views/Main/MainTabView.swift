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
        .overlay(
            // 設定ボタンオーバーレイ
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.title2)
                            .foregroundColor(.primaryApp)
                            .padding(12)
                            .background(
                                Circle()
                                    .fill(Color.backgroundPrimary)
                                    .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 2)
                            )
                    }
                    .padding()
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
