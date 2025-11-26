import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    
    @AppStorage("language") private var language: String = "ja"
    
    @AppStorage("appearanceMode") private var appearanceMode: Int = 0 // 0:Auto, 1:Light, 2:Dark
    @AppStorage("notifyAt8") private var notifyAt8: Bool = false
    @AppStorage("notifyAt12") private var notifyAt12: Bool = false
    @AppStorage("notifyAt17") private var notifyAt17: Bool = false
    
    var body: some View {
        NavigationStack {
            List {
                
                Section(header: Text("言語 / Language")) {
                    Picker("表示言語", selection: $language) {
                        Text("日本語").tag("ja")
                        Text("English").tag("en")
                    }
                    .pickerStyle(.menu)
                }
                // --- 外観設定 ---
                Section(header: Text("外観")) {
                    Picker("テーマ", selection: $appearanceMode) {
                        Text("自動 (システム準拠)").tag(0)
                        Text("ライトモード").tag(1)
                        Text("ダークモード").tag(2)
                    }
                    .pickerStyle(.menu)
                }
                
                // --- 通知設定 ---
                Section(header: Text("通知設定 (今日の残タスク)")) {
                    // iOS 17以降の .onChange 構文に対応 (引数なしでも動作しますが、念のため _ in をつけるか、古い構文の場合はofのみ)
                    Toggle("朝 08:00 に通知", isOn: $notifyAt8)
                        .onChange(of: notifyAt8) { _, _ in requestPermissionIfNeeded() }
                    
                    Toggle("昼 12:00 に通知", isOn: $notifyAt12)
                        .onChange(of: notifyAt12) { _, _ in requestPermissionIfNeeded() }
                    
                    Toggle("夕 17:00 に通知", isOn: $notifyAt17)
                        .onChange(of: notifyAt17) { _, _ in requestPermissionIfNeeded() }
                }
                
                
                
                // 形式: https://apps.apple.com/app/id【あなたのアプリID】?action=write-review　書き換える
                Section(header: Text("アプリについて")) {
                    Link(destination: URL(string: "https://apps.apple.com/jp/app/")!) {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow) // 星を黄色に
                            Text("アプリをレビューして応援")
                                .foregroundColor(.primary)
                        }
                    }
                    // Linkを使うと、Safariブラウザで開きます
                    Link(destination: URL(string: "https://www.google.com")!) {
                        HStack {
                            Image(systemName: "hand.raised.fill")
                                .foregroundStyle(.blue)
                            Text("プライバシーポリシー")
                                .foregroundColor(.primary)
                        }
                    }
                    
                    Link(destination: URL(string: "https://www.google.com")!) {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .foregroundStyle(.blue)
                            Text("利用規約")
                                .foregroundColor(.primary)
                        }
                    }
                }
                Section(header: Text("サポート（バグを報告）")) {
                    Link(destination: URL(string: "https://forms.gle/eMSi5cvLC63epdmv5")!) {
                        Text("Googleフォーム")
                    }
                    // または GoogleフォームのURL
                }
                
                Section(header: Text("その他")) {
                    // アプリのバージョン表示など
                    HStack {
                        Text("バージョン")
                        Spacer()
                        Text("1.0.1")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("設定・情報")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func requestPermissionIfNeeded() {
        // いずれかのスイッチがONになったら許可を求める
        if notifyAt8 || notifyAt12 || notifyAt17 {
            NotificationManager.shared.requestPermission()
        }
    }
}
