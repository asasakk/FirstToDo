import SwiftUI
import SwiftData

struct TaskListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ToDoItem.date) private var allItems: [ToDoItem]
    
    // --- 表示コントロール ---
    @State private var showCompletedItems: Bool = false
    @State private var isSearchModalPresented: Bool = false
    
    @State private var showSettings: Bool = false
    
    // ★追加: 未来のタスクを日付ごとに分けるかどうかのフラグ
    @State private var isFutureGroupedByDate: Bool = false
    
    // --- 検索条件 ---
    @State private var searchTitle: String = ""
    @State private var searchCategory: Category? = nil
    @State private var searchPriority: Priority? = nil
    @State private var isOrSearch: Bool = false
    @State private var searchDate: Date? = nil
    
    // --- 削除・編集用State ---
    @State private var editingItem: ToDoItem? = nil
    @State private var itemToDelete: ToDoItem?
    @State private var showDeleteConfirmation = false

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            
            NavigationStack {
                List {
                    // --- 期限切れ ---
                    let past = pastItems
                    if !past.isEmpty {
                        Section(header: Text("期限切れ").foregroundColor(.red)) {
                            ForEach(past) { item in
                                TaskRow(item: item)
                                    .swipeActions(edge: .trailing) {
                                        Button("削除") { requestDelete(item) }.tint(.red)
                                    }
                                    .contextMenu { Button("編集") { editingItem = item } }
                            }
                        }
                    }
                    
                    // --- 今日 ---
                    let today = todayItems
                    if !today.isEmpty {
                        Section(header: Text("今日")) {
                            ForEach(today) { item in
                                TaskRow(item: item)
                                    .swipeActions(edge: .trailing) {
                                        Button("削除") { requestDelete(item) }.tint(.red)
                                    }
                                    .contextMenu { Button("編集") { editingItem = item } }
                            }
                        }
                    } else if past.isEmpty && futureItems.isEmpty {
                        Section {
                            Text("表示するタスクはありません")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // --- 明日以降 (ここを修正) ---
                    let future = futureItems
                    if !future.isEmpty {
                        if isFutureGroupedByDate {
                            // ★モードB: 日付ごとにセクションを分けて表示
                            ForEach(futureGroupedByDate, id: \.date) { group in
                                Section(header: Text(formatHeaderDate(group.date))) {
                                    ForEach(group.items) { item in
                                        TaskRow(item: item)
                                            .swipeActions(edge: .trailing) {
                                                Button("削除") { requestDelete(item) }.tint(.red)
                                            }
                                            .contextMenu { Button("編集") { editingItem = item } }
                                    }
                                }
                            }
                        } else {
                            // ★モードA: 従来の「明日以降」まとめ表示
                            Section(header: Text("明日以降 (今後)")) {
                                ForEach(future) { item in
                                    TaskRow(item: item)
                                        .swipeActions(edge: .trailing) {
                                            Button("削除") { requestDelete(item) }.tint(.red)
                                        }
                                        .contextMenu { Button("編集") { editingItem = item } }
                                }
                            }
                        }
                    }
                }
                .navigationTitle("タスク一覧")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: {
                            showSettings = true
                        }) {
                            Image(systemName: "gearshape.fill") // 歯車アイコン
                                .foregroundStyle(.gray)
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        HStack(spacing: 16) { // ボタンの間隔を少し空ける
                            
                            // ★追加: 未来タスクの表示モード切替ボタン
                            Button(action: {
                                withAnimation { isFutureGroupedByDate.toggle() }
                            }) {
                                // アイコンを切替: リスト(まとめ) vs カレンダー(日付ごと)
                                Image(systemName: isFutureGroupedByDate ? "list.bullet" : "calendar")
                                    .font(.system(size: 14, weight: .bold)) // 少し調整
                            }
                            
                            NavigationLink(destination: PastTasksView()) {
                                Image(systemName: "clock.arrow.circlepath") // 履歴アイコン
                                    .fontWeight(.semibold)
                            }
                            
                            Divider().frame(height: 16)
                            
                            // 完了タスク表示ボタン
                            Button(action: {
                                withAnimation { showCompletedItems.toggle() }
                            }) {
                                Image(systemName: showCompletedItems ? "eye" : "eye.slash")
                                    .foregroundColor(showCompletedItems ? .blue : .gray)
                            }
                            
                            // 検索ボタン
                            Button(action: { isSearchModalPresented = true }) {
                                Image(systemName: "magnifyingglass")
                            }
                        }
                        .padding(.horizontal,8)
                        .padding(.vertical,8)
                    }
                }
                .sheet(isPresented: $showSettings) {
                    SettingsView()
                }
                .sheet(isPresented: $isSearchModalPresented) {
                    SearchModalView(
                        searchTitle: $searchTitle,
                        searchCategory: $searchCategory,
                        searchPriority: $searchPriority,
                        isOrSearch: $isOrSearch,
                        searchDate: $searchDate
                    )
                    .presentationDetents([.medium, .large])
                }
                .sheet(item: $editingItem) { item in
                    EditTaskView(item: item)
                }
                .confirmationDialog("繰り返しタスクの削除", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                    Button("このタスクのみ削除", role: .destructive) {
                        if let item = itemToDelete { deleteOne(item) }
                    }
                    Button("これ以降すべて削除", role: .destructive) {
                        if let item = itemToDelete { deleteAllFuture(item) }
                    }
                    Button("キャンセル", role: .cancel) {
                        itemToDelete = nil
                    }
                } message: {
                    Text("これは繰り返しタスクです。削除方法を選択してください。")
                }
            }
            .padding(.top,20)
        }
    }
    
    // MARK: - フィルタリングとデータ取得ロジック
    
    private func matchesCondition(_ item: ToDoItem) -> Bool {
        let todayStart = Calendar.current.startOfDay(for: Date())
        
        if item.isCompleted {
            if item.date < todayStart { return false }
            if !showCompletedItems { return false }
        }
        
        if let targetDate = searchDate {
            if !Calendar.current.isDate(item.date, inSameDayAs: targetDate) { return false }
        }
        
        let titleEmpty = searchTitle.isEmpty
        let catNil = searchCategory == nil
        let priNil = searchPriority == nil
        
        if titleEmpty && catNil && priNil { return true }
        
        let matchTitle = !titleEmpty && item.title.localizedCaseInsensitiveContains(searchTitle)
        let matchCat = searchCategory != nil && item.category == searchCategory
        let matchPri = searchPriority != nil && item.priority == searchPriority
        
        if isOrSearch {
            var hits = false
            if !titleEmpty && matchTitle { hits = true }
            if searchCategory != nil && matchCat { hits = true }
            if searchPriority != nil && matchPri { hits = true }
            return hits
        } else {
            if !titleEmpty && !matchTitle { return false }
            if searchCategory != nil && !matchCat { return false }
            if searchPriority != nil && !matchPri { return false }
            return true
        }
    }
    
    var pastItems: [ToDoItem] {
        let todayStart = Calendar.current.startOfDay(for: Date())
        return allItems.filter { item in
            matchesCondition(item) && item.date < todayStart
        }.sorted { $0.date < $1.date }
    }
    
    var todayItems: [ToDoItem] {
        return allItems.filter { item in
            matchesCondition(item) && Calendar.current.isDateInToday(item.date)
        }.sorted {
            if $0.priority == $1.priority { return $0.date < $1.date }
            return $0.priority > $1.priority
        }
    }
    
    var futureItems: [ToDoItem] {
        let tomorrowStart = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))!
        return allItems.filter { item in
            matchesCondition(item) && item.date >= tomorrowStart
        }.sorted { $0.date < $1.date }
    }
    
    // ★追加: 未来のタスクを日付ごとにグループ化して返す
    var futureGroupedByDate: [(date: Date, items: [ToDoItem])] {
        let groupedDictionary = Dictionary(grouping: futureItems) { item in
            Calendar.current.startOfDay(for: item.date)
        }
        // 日付が近い順にソートして配列化
        return groupedDictionary.sorted { $0.key < $1.key }
            .map { (date: $0.key, items: $0.value) }
    }
    
    // ★追加: セクションヘッダー用フォーマッター
    private func formatHeaderDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy,MM月dd日 (E)" // (E)は曜日
        return formatter.string(from: date)
    }
    
    // MARK: - 削除処理
    private func requestDelete(_ item: ToDoItem) {
        if item.repeatGroupId != nil {
            itemToDelete = item
            showDeleteConfirmation = true
        } else {
            modelContext.delete(item)
        }
    }
    
    private func deleteOne(_ item: ToDoItem) {
        modelContext.delete(item)
        itemToDelete = nil
    }
    
    private func deleteAllFuture(_ item: ToDoItem) {
        guard let groupId = item.repeatGroupId else { return }
        let targetDate = item.date
        let itemsToDelete = allItems.filter {
            $0.repeatGroupId == groupId && $0.date >= targetDate
        }
        for deleteTarget in itemsToDelete {
            modelContext.delete(deleteTarget)
        }
        itemToDelete = nil
    }
}
