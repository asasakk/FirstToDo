import SwiftUI
import SwiftData
import AppTrackingTransparency // ★追加
import AdSupport               // ★追加

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var allItems: [ToDoItem]
    
    @AppStorage("appearanceMode") private var appearanceMode: Int = 0
    @AppStorage("notifyAt8") private var notifyAt8: Bool = false
    @AppStorage("notifyAt12") private var notifyAt12: Bool = false
    @AppStorage("notifyAt17") private var notifyAt17: Bool = false
    
    var body: some View {
        VStack(spacing: 0){
            TabView {
                HomeView()
                    .tabItem { Label("ホーム", systemImage: "house") }
                
                TaskListView()
                    .tabItem { Label("一覧", systemImage: "list.bullet") }
                
                StatisticsView()
                    .tabItem { Label("統計", systemImage: "chart.pie.fill") }
            }
            .preferredColorScheme(selectedScheme)
            
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .background {
                    updateNotifications()
                }
            }
            
            AdBannerView()
                .frame(width: 320, height: 50)
        }

        .onAppear {
            requestIDFA()
        }
    }
    
    var selectedScheme: ColorScheme? {
        switch appearanceMode {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }
    
    private func updateNotifications() {
        let calendar = Calendar.current
        let todayRemainingCount = allItems.filter {
            calendar.isDateInToday($0.date) && !$0.isCompleted
        }.count
        
        NotificationManager.shared.scheduleNotifications(
            taskCount: todayRemainingCount,
            notifyAt8: notifyAt8,
            notifyAt12: notifyAt12,
            notifyAt17: notifyAt17
        )
    }
    
    // ★追加: ポップアップ表示ロジック
    func requestIDFA() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            ATTrackingManager.requestTrackingAuthorization { status in
                switch status {
                case .authorized:
                    print("トラッキング: 許可されました")
                case .denied:
                    print("トラッキング: 拒否されました")
                case .notDetermined:
                    print("トラッキング: 未選択")
                case .restricted:
                    print("トラッキング: 制限されています")
                @unknown default:
                    break
                }
            }
        }
    }
}
