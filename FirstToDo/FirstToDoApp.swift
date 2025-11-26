import SwiftUI
import SwiftData
import GoogleMobileAds
import WidgetKit

@main
struct ToDoApp: App {
    // コンテナをカスタマイズして作成
    let sharedModelContainer: ModelContainer = {
        let schema = Schema([ToDoItem.self])
        // ★ここ重要: groupContainerを指定してApp Groupを使う設定にする
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, groupContainer: .identifier("group.com.asai.todoapp"))

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    init() {
        //テスト用
            MobileAds.shared.requestConfiguration.testDeviceIdentifiers = [ "fb78f654788c62d4083939581107a4a0" ]
            MobileAds.shared.start(completionHandler: nil)
        }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer) // カスタマイズしたコンテナを適用
        // ★アプリがバックグラウンドに行った時、ウィジェットを更新する
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }
    
    @Environment(\.scenePhase) private var scenePhase
}
