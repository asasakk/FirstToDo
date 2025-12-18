import SwiftUI
import SwiftData
import GoogleMobileAds
import WidgetKit

@main
struct ToDoApp: App {
    // ★追加: 設定画面で保存した値を読み込む
    @AppStorage("language") private var language: String = "ja" // デフォルトは日本語
    @AppStorage("appearanceMode") private var appearanceMode: Int = 0 // 0:自動, 1:ライト, 2:ダーク

    // ★追加: App Group IDを定数で管理 (Widgetと合わせるため)
    private let appGroupID = "group.com.asai.todoapp"

    // コンテナをカスタマイズして作成
    var sharedModelContainer: ModelContainer {
        let schema = Schema([ToDoItem.self])
        // ★修正: 定数を使用
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, groupContainer: .identifier(appGroupID))

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
    
    init() {
        //テスト用
            MobileAds.shared.requestConfiguration.testDeviceIdentifiers = [ "fb78f654788c62d4083939581107a4a0" ]
            MobileAds.shared.start(completionHandler: nil)
        }

    var body: some Scene {
        WindowGroup {
            ContentView()
                // ★追加: アプリ全体の言語を強制的に上書き
                .environment(\.locale, Locale(identifier: language))
                // ★追加: アプリ全体の外観モードを強制的に上書き
                .preferredColorScheme(appearanceMode == 0 ? nil : (appearanceMode == 1 ? .light : .dark))
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
