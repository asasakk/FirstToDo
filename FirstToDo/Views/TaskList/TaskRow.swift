import SwiftUI
import SwiftData

struct TaskRow: View {
    let item: ToDoItem
    
    var body: some View {
        HStack {
            Button(action: {
                
                HapticManager.shared.notification(type: .success)
                
                withAnimation {
                    item.isCompleted.toggle()
                }
            }) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(item.isCompleted ? .green : .gray)
            }
            
            VStack(alignment: .leading) {
                Text(item.title)
                    .strikethrough(item.isCompleted)
                    .font(.headline)
                
                // --- ここを変更しました ---
                HStack {
                    // 指定のフォーマットで日付を表示
                    Text(formatDate(item.date))
                    // 時間を表示
                    Text(formatTime(item.date))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                // ---------------------
            }
            Spacer()
            
            // 重要度とカテゴリのバッジ
            VStack(alignment: .trailing) {
                Text(item.category.rawValue)
                    .font(.caption2)
                    .padding(4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
                
                Text("重要: \(item.priority.title)")
                    .font(.caption2)
                    .foregroundColor(item.priority == .high ? .red : .primary)
            }
        }
    }
    
    // --- 日付フォーマット用の関数 ---
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP") // 日本語ロケール
        formatter.dateFormat = "yyyy,MM月dd日"        // ご希望の形式 (MMは月、mmは分)
        return formatter.string(from: date)
    }
    
    // --- 時間フォーマット用の関数 ---
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "HH:mm"               // 24時間表記 (例 14:30)
        return formatter.string(from: date)
    }
}
