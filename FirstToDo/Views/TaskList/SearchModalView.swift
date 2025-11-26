import SwiftUI

struct SearchModalView: View {
    @Environment(\.dismiss) var dismiss
    
    @Binding var searchTitle: String
    @Binding var searchCategory: Category?
    @Binding var searchPriority: Priority?
    @Binding var isOrSearch: Bool
    @Binding var searchDate: Date?
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("検索モード")) {
                    Picker("モード", selection: $isOrSearch) {
                        Text("AND (すべて満たす)").tag(false)
                        Text("OR (どれか一つ)").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: isOrSearch) { _, isOr in
                        if isOr {
                            // 必要ならここでリセット処理などを入れる
                        }
                    }
                }
                
                Section(header: Text("検索条件")) {
                    TextField("タイトル検索", text: $searchTitle)
                        .onChange(of: searchTitle) { _, _ in
                            if isOrSearch && !searchTitle.isEmpty {
                                searchCategory = nil
                                searchPriority = nil
                            }
                        }
                    
                    Picker("カテゴリ", selection: $searchCategory) {
                        Text("指定なし").tag(Category?.none)
                        ForEach(Category.allCases) { cat in
                            Text(cat.rawValue).tag(Optional(cat))
                        }
                    }
                    .onChange(of: searchCategory) { _, val in
                        if isOrSearch && val != nil {
                            searchTitle = ""
                            searchPriority = nil
                        }
                    }
                    
                    Picker("重要度", selection: $searchPriority) {
                        Text("指定なし").tag(Priority?.none)
                        ForEach(Priority.allCases) { pri in
                            Text(pri.title).tag(Optional(pri))
                        }
                    }
                    .onChange(of: searchPriority) { _, val in
                        if isOrSearch && val != nil {
                            searchTitle = ""
                            searchCategory = nil
                        }
                    }
                }
                
                // 日付指定がある場合のみ表示されるセクション
                if searchDate != nil {
                    Section {
                        HStack {
                            Text("日付指定中")
                            Spacer()
                            Button("解除") {
                                searchDate = nil
                            }
                            .foregroundColor(.red)
                        }
                    }
                }
                
                Button("検索する") {
                    dismiss()
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .navigationTitle("検索条件")
            .toolbar {
                // 左上にリセットボタン
                ToolbarItem(placement: .topBarLeading) {
                    Button("リセット") {
                        resetSearch()
                    }
                    .foregroundColor(.red)
                }
                
                // 右上に閉じるボタン
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
    
    // 全ての条件をクリアする関数
    private func resetSearch() {
        searchTitle = ""
        searchCategory = nil
        searchPriority = nil
        searchDate = nil
        isOrSearch = false
        // リセットしたことをわかりやすくするために、そのまま画面を閉じたい場合は
        // dismiss() をここに追加してもOKです
    }
}
