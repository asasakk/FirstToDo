import SwiftUI
import SwiftData


struct EditTaskView: View {
    @Bindable var item: ToDoItem
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("タイトル", text: $item.title)
                DatePicker("日時", selection: $item.date)
                Picker("カテゴリ", selection: $item.category) {
                    ForEach(Category.allCases) { cat in Text(cat.rawValue).tag(cat) }
                }
                Picker("重要度", selection: $item.priority) {
                    ForEach(Priority.allCases) { pri in Text(pri.title).tag(pri) }
                }
            }
            .navigationTitle("タスク編集")
            .toolbar {
                Button("完了") { dismiss() }
            }
        }
    }
}
