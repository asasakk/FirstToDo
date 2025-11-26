import WidgetKit
import SwiftUI
import SwiftData
import AppIntents

// MARK: - 1. カテゴリ選択などの定義

// ウィジェット編集画面で選ぶカテゴリ一覧
enum WidgetCategory: String, AppEnum {
    case all = "all"
    case work = "work"
    case privateLife = "privateLife"
    case shopping = "shopping"
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "カテゴリ"
    
    static var caseDisplayRepresentations: [WidgetCategory : DisplayRepresentation] {
        [
            .all: "全体",
            .work: "仕事",
            .privateLife: "プライベート",
            .shopping: "買い物"
        ]
    }
    
    var displayName: String {
        switch self {
        case .all: return "全体"
        case .work: return "仕事"
        case .privateLife: return "プライベート"
        case .shopping: return "買い物"
        }
    }
    
    var color: Color {
        switch self {
        case .all: return .primary
        case .work: return .blue
        case .privateLife: return .green
        case .shopping: return .orange
        }
    }
    
    // データモデルのCategory型とのマッピング
    var modelCategory: Category? {
        switch self {
        case .all: return nil
        case .work: return .work
        case .privateLife: return .privateLife
        case .shopping: return .shopping
        }
    }
}

// ウィジェットの設定項目
struct ConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "カテゴリ選択"
    static var description = IntentDescription("表示するタスクのカテゴリを選択します")

    @Parameter(title: "カテゴリ", default: .all)
    var category: WidgetCategory
}

// ウィジェット用の軽量タスクデータ
struct WidgetTask: Identifiable {
    let id: UUID
    let title: String
    let date: Date
}


// MARK: - 2. Provider (データ取得ロジック)

struct Provider: AppIntentTimelineProvider {
    // App Groupを使ったコンテナの設定
    // ★重要: "group.com.yourname.todoapp" をご自身のIDに書き換えてください
    let modelContainer: ModelContainer = {
        let schema = Schema([ToDoItem.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, groupContainer: .identifier("group.com.asai.todoapp"))
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Widget ModelContainer creation failed: \(error)")
        }
    }()

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), category: .all, count: 5, tasks: [
            WidgetTask(id: UUID(), title: "買い物", date: Date()),
            WidgetTask(id: UUID(), title: "メール返信", date: Date()),
            WidgetTask(id: UUID(), title: "資料作成", date: Date()),
            WidgetTask(id: UUID(), title: "掃除", date: Date())
        ])
    }

    func snapshot(for configuration: ConfigurationIntent, in context: Context) async -> SimpleEntry {
        let entry = SimpleEntry(date: Date(), category: .all, count: 3, tasks: [
            WidgetTask(id: UUID(), title: "サンプルタスク", date: Date())
        ])
        return entry
    }

    func timeline(for configuration: ConfigurationIntent, in context: Context) async -> Timeline<SimpleEntry> {
        // 設定されたカテゴリに基づいてデータを取得
        let (count, tasks) = fetchTasks(for: configuration.category)
        
        let entry = SimpleEntry(date: Date(), category: configuration.category, count: count, tasks: tasks)
        
        // 15分おきに更新
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15 * 60)))
        return timeline
    }
    
    // バックグラウンドでデータを取得する関数 (MainActor非依存)
    private func fetchTasks(for widgetCategory: WidgetCategory) -> (Int, [WidgetTask]) {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart)!
        
        // ★修正点: mainContextではなく、この場で作った新しいContextを使う
        let context = ModelContext(modelContainer)
        
        let descriptor = FetchDescriptor<ToDoItem>(
            predicate: #Predicate { item in
                !item.isCompleted && item.date >= todayStart && item.date < tomorrowStart
            },
            sortBy: [SortDescriptor(\.date)]
        )
        
        do {
            let allItems = try context.fetch(descriptor)
            
            // カテゴリフィルタリング
            let filteredItems: [ToDoItem]
            if let targetCategory = widgetCategory.modelCategory {
                filteredItems = allItems.filter { $0.category == targetCategory }
            } else {
                filteredItems = allItems
            }
            
            let count = filteredItems.count
            
            // 最大10件まで変換して渡す
            let widgetTasks = filteredItems.prefix(10).map { item in
                WidgetTask(id: item.id, title: item.title, date: item.date)
            }
            
            return (count, Array(widgetTasks))
        } catch {
            return (0, [])
        }
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let category: WidgetCategory
    let count: Int
    let tasks: [WidgetTask]
}


// MARK: - 3. ウィジェット本体定義

@main
struct ToDoWidget: Widget {
    let kind: String = "ToDoWidget"

    var body: some WidgetConfiguration {
        // AppIntentConfigurationで編集可能にする
        AppIntentConfiguration(kind: kind, intent: ConfigurationIntent.self, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                ToDoWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                ToDoWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("タスクリスト")
        .description("カテゴリを選択してタスクリストを表示します。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// サイズに応じたViewの切り替え
struct ToDoWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallCategoryView(entry: entry)
        case .systemMedium:
            MediumListView(entry: entry)
        default:
            Text("未対応")
        }
    }
}


// MARK: - 4. ビュー定義 (小・中・行)

// ★小サイズ：カテゴリ名 + 件数 + 4件リスト (高さ固定版)
struct SmallCategoryView: View {
    var entry: Provider.Entry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ヘッダー
            HStack(alignment: .firstTextBaseline) {
                Text(entry.category.displayName)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(entry.category.color)
                
                Spacer()
                
                Text("\(entry.count)")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)
            }
            .padding(.bottom, 6)
            
            // 区切り線
            Divider()
                .padding(.bottom, 4)
            
            // リスト
            if entry.tasks.isEmpty {
                VStack {
                    Spacer()
                    Text("完了!")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(entry.tasks.prefix(4)) { task in
                        TaskRowView(id: task.id, title: task.title, color: entry.category.color)
                    }
                    
                    // ★修正ポイント: 常にテキストを置いて、件数に応じて透明にする
                    Text(entry.count > 4 ? "+ \(entry.count - 4)" : "+ 0")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 12)
                        .padding(.top, 1)
                        // 4件以下のときは透明にする(高さは確保される)
                        .opacity(entry.count > 4 ? 1 : 0)
                }
            }
            Spacer()
        }
    }
}

// ★中サイズ：5行2列リスト (完了表示対応版)
struct MediumListView: View {
    var entry: Provider.Entry
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            
            // 左側：残り件数 (変更なし)
            VStack(alignment: .center, spacing: -2) {
                Text("残り")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                
                Text("\(entry.count)")
                    .font(.system(size: 42, weight: .heavy, design: .rounded))
                    .foregroundStyle(entry.count == 0 ? .green : entry.category.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                
                Spacer()
                
                if entry.category != .all {
                    Text(entry.category.displayName)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(entry.category.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(width: 50)
            .padding(.top, 4)
            
            // 区切り線
            Rectangle()
                .fill(Color(.separator))
                .frame(width: 1)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
            
            // 右側：リスト または 完了メッセージ
            if entry.tasks.isEmpty {
                // ★追加: タスクがない場合の表示
                VStack {
                    Spacer()
                    Text("完了！🎉")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity) // 右側のスペースいっぱいに広げる
            } else {
                // ★既存のリスト表示ロジック
                GeometryReader { geometry in
                    let columns = 2
                    let columnWidth = geometry.size.width / CGFloat(columns)
                    let tasks = entry.tasks
                    let isOverflow = entry.count > 10
                    
                    HStack(alignment: .top, spacing: 0) {
                        // 1列目
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(tasks.prefix(5))) { task in
                                TaskRowView(id: task.id, title: task.title, color: entry.category.color)
                            }
                        }
                        .frame(width: columnWidth, alignment: .leading)
                        
                        // 2列目
                        VStack(alignment: .leading, spacing: 6) {
                            let limit = isOverflow ? 4 : 5
                            let secondColumnTasks = Array(tasks.dropFirst(5).prefix(limit))
                            
                            ForEach(secondColumnTasks) { task in
                                TaskRowView(id: task.id, title: task.title, color: entry.category.color)
                            }
                            
                            if isOverflow {
                                Text("+ 他 \(entry.count - 9) 件")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 4)
                                    .padding(.top, 2)
                            }
                        }
                        .frame(width: columnWidth, alignment: .leading)
                        .padding(.leading, 4)
                    }
                    .padding(.top, 2)
                }
            }
        }
        .containerBackground(for: .widget) { Color(.systemBackground) }
    }
}

// 共通タスク行 (完了ボタン付き)
struct TaskRowView: View {
    let id: UUID
    let title: String
    let color: Color
    
    var body: some View {
        Button(intent: CompleteTaskIntent(taskId: id.uuidString)) {
            HStack(spacing: 4) {
                // 黄色の枠線、白背景
                Circle()
                    .strokeBorder(Color.yellow, lineWidth: 2)
                    .background(Circle().fill(Color.white))
                    .frame(width: 12, height: 12)
                    .padding(.top, 1)
                
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
