// PetPal/Views/Main/MainTabView.swift

import SwiftUI
import CoreData

struct MainTabView: View {
    @StateObject private var petViewModel: PetViewModel
    @StateObject private var userProfileViewModel: UserProfileViewModel
    @StateObject private var careViewModel: CareViewModel
    @StateObject private var feedingViewModel = FeedingViewModel()
    @StateObject private var healthViewModel = HealthViewModel()
    
    @State private var showingSettings = false
    @State private var showingShareSheet = false
    @State private var shareURL: URL?
    @State private var shareText: String = ""
    
    init(context: NSManagedObjectContext) {
        let userProfileVM = UserProfileViewModel(context: context)
        
        _userProfileViewModel = StateObject(wrappedValue: userProfileVM)
        _petViewModel = StateObject(wrappedValue: PetViewModel(context: context))
        _careViewModel = StateObject(wrappedValue: CareViewModel(
            context: context,
            userProfileViewModel: userProfileVM
        ))
    }
    
    var body: some View {
        TabView {
            PetListView(petViewModel: petViewModel, userProfileViewModel: userProfileViewModel)
                .tabItem {
                    Label("ペット", systemImage: "pawprint.fill")
                }
            
            CareLogView(petViewModel: petViewModel, careViewModel: careViewModel, userProfileViewModel: userProfileViewModel)
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
                .environmentObject(userProfileViewModel)
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = shareURL {
                ShareSheet(items: [url, shareText])
            }
        }
        .environmentObject(petViewModel)
        .environmentObject(userProfileViewModel)
        .environmentObject(careViewModel)
        .onOpenURL { url in
            // 共有リンクからアプリが開かれた場合の処理
            handleIncomingURL(url)
        }
    }
    
    // 共有URLからアプリが開かれた場合の処理
    private func handleIncomingURL(_ url: URL) {
        // URLがCloudKitの共有URLかチェック
        if url.absoluteString.contains("cloudkit.com") {
            // CloudKit共有招待を処理
            userProfileViewModel.acceptSharedInvitation(from: url) { result in
                switch result {
                case .success:
                    // 同期完了後にペット一覧を更新
                    petViewModel.syncWithCloudKit()
                case .failure(let error):
                    print("共有招待の受け入れに失敗: \(error)")
                }
            }
        }
    }
}

// UIActivityViewControllerのラッパー
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        MainTabView(context: context)
    }
}
