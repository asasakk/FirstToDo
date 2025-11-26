import AppIntents
import SwiftData
import WidgetKit

struct CompleteTaskIntent: AppIntent {
    // ショートカットアプリなどで表示されるタイトル
    static var title: LocalizedStringResource = "タスクを完了"
    static var description = IntentDescription("ウィジェットからタスクを完了にします")

    // どのタスクを完了するか、IDを受け取る
    @Parameter(title: "Task ID")
    var taskId: String

    init() {}
    
    init(taskId: String) {
        self.taskId = taskId
    }

    func perform() async throws -> some IntentResult {
        // 1. App Groupを使ってデータベースを開く
        // ★ご自身のApp Group IDに書き換えてください
        let schema = Schema([ToDoItem.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, groupContainer: .identifier("group.com.asai.todoapp"))
        
        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            let context = ModelContext(container)
            
            // 2. IDからタスクを探す
            // (UUID型に変換)
            guard let uuid = UUID(uuidString: taskId) else { return .result() }
            
            let descriptor = FetchDescriptor<ToDoItem>(
                predicate: #Predicate { $0.id == uuid }
            )
            
            if let item = try context.fetch(descriptor).first {
                // 3. 完了状態にして保存
                item.isCompleted = true
                try context.save()
            }
            
            // 4. ウィジェットを更新してね、と伝える
            // (これをしないと完了しても表示が変わらない)
            return .result()
            
        } catch {
            return .result()
        }
    }
}
