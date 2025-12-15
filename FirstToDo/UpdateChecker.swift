import Foundation
import Combine


@MainActor
class UpdateChecker: ObservableObject {
    @Published var isUpdateAvailable: Bool = false
    @Published var latestVersion: String = ""
    @Published var appStoreURL: URL?

    func checkForUpdate() {
        guard let bundleID = Bundle.main.bundleIdentifier,
              let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
              let url = URL(string: "https://itunes.apple.com/lookup?bundleId=\(bundleID)") else {
            print("UpdateChecker: 必要情報の取得に失敗しました (BundleID または バージョン情報)")
            return
        }

        print("UpdateChecker: 現在のバージョン: \(currentVersion)")
        print("UpdateChecker: チェックURL: \(url.absoluteString)")

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                
                // レスポンスの解析
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let resultCount = json["resultCount"] as? Int, resultCount > 0,
                   let results = json["results"] as? [[String: Any]],
                   let result = results.first,
                   let storeVersion = result["version"] as? String,
                   let trackViewUrlString = result["trackViewUrl"] as? String,
                   let trackViewUrl = URL(string: trackViewUrlString) {
                    
                    print("UpdateChecker: ストアのバージョン: \(storeVersion)")
                    
                    if isNewerVersion(store: storeVersion, current: currentVersion) {
                        self.latestVersion = storeVersion
                        self.appStoreURL = trackViewUrl
                        self.isUpdateAvailable = true
                        print("UpdateChecker: アップデートがあります")
                    } else {
                        print("UpdateChecker: 最新バージョンです")
                    }
                } else {
                    print("UpdateChecker: ストア情報が見つかりません (未公開の可能性あり)")
                }
            } catch {
                print("UpdateChecker: エラー発生: \(error.localizedDescription)")
            }
        }
    }
    
    // バージョン比較ロジック (例: "1.0.1" > "1.0.0")
    private func isNewerVersion(store: String, current: String) -> Bool {
        let storeComponents = store.split(separator: ".").compactMap { Int($0) }
        let currentComponents = current.split(separator: ".").compactMap { Int($0) }
        
        let count = max(storeComponents.count, currentComponents.count)
        
        for i in 0..<count {
            let sVal = i < storeComponents.count ? storeComponents[i] : 0
            let cVal = i < currentComponents.count ? currentComponents[i] : 0
            
            if sVal > cVal { return true }
            if sVal < cVal { return false }
        }
        
        return false
    }
}
