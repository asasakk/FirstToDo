import SwiftUI
import SwiftData

struct PastTasksView: View {
    @Query(sort: \ToDoItem.date, order: .reverse) private var allItems: [ToDoItem]
    @Environment(\.modelContext) private var modelContext
    
    // 削除用
    @State private var itemToDelete: ToDoItem?
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        List {
            if groupedPastTasks.isEmpty {
                ContentUnavailableView(
                    "履歴はありません",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("過去のタスクはここに表示されます")
                )
            } else {
                ForEach(groupedPastTasks, id: \.date) { group in
                    Section(header: Text(formatHeaderDate(group.date))) {
                        ForEach(group.items) { item in
                            // 既存のTaskRowを再利用（チェック操作などはそのまま可能）
                            TaskRow(item: item)
                                .swipeActions(edge: .trailing) {
                                    Button("削除") { requestDelete(item) }.tint(.red)
                                }
                        }
                    }
                }
            }
        }
        .navigationTitle("過去のタスク")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("繰り返しタスクの削除", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("このタスクのみ削除", role: .destructive) {
                if let item = itemToDelete { modelContext.delete(item) }
            }
            Button("これ以降すべて削除", role: .destructive) {
                if let item = itemToDelete { deleteAllFuture(item) }
            }
            Button("キャンセル", role: .cancel) { itemToDelete = nil }
        } message: {
            Text("これは繰り返しタスクです。削除方法を選択してください。")
        }
    }
    
    // --- データ整形ロジック ---
    
    // 過去のタスクのみを抽出し、日付ごとにグループ化
    var groupedPastTasks: [(date: Date, items: [ToDoItem])] {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        
        // 昨日以前のデータのみフィルタリング
        let pastItems = allItems.filter { $0.date < todayStart }
        
        // 日付(0:00)でグルーピング
        let grouped = Dictionary(grouping: pastItems) { item in
            calendar.startOfDay(for: item.date)
        }
        
        // 日付が新しい順（降順）にソートして返す
        return grouped.map { (key, value) in
            (date: key, items: value.sorted { $0.date > $1.date })
        }.sorted { $0.date > $1.date }
    }
    
    // 日付フォーマット
    private func formatHeaderDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy,MM月dd日 (E)"
        return formatter.string(from: date)
    }
    
    // --- 削除ロジック (TaskListViewと同じ) ---
    private func requestDelete(_ item: ToDoItem) {
        if item.repeatGroupId != nil {
            itemToDelete = item
            showDeleteConfirmation = true
        } else {
            modelContext.delete(item)
        }
    }
    
    private func deleteAllFuture(_ item: ToDoItem) {
        guard let groupId = item.repeatGroupId else { return }
        let targetDate = item.date
        let itemsToDelete = allItems.filter {
            $0.repeatGroupId == groupId && $0.date >= targetDate
        }
        itemsToDelete.forEach { modelContext.delete($0) }
    }
}
