import SwiftUI
import SwiftData
import Charts

// 統計の期間選択用
enum StatRange: String, CaseIterable, Identifiable {
    case week = "week"
    case month = "month"
    case all = "all"
    
    var id: String { self.rawValue }
    
    // View内で翻訳するためのキーを返す
    var localizedKey: LocalizedStringKey {
        switch self {
        case .week: return "今週"
        case .month: return "今月"
        case .all: return "全期間"
        }
    }
}

struct StatisticsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allItems: [ToDoItem]
    
    // アプリの言語設定
    @AppStorage("language") private var language: String = "ja"
    
    // 現在の言語設定に基づいたロケール
    private var targetLocale: Locale {
        Locale(identifier: language)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 1. 今日の進捗カード
                    TodayProgressView(allItems: allItems, locale: targetLocale)
                    
                    // 2. 週間アクティビティカード
                    WeeklyActivityView(allItems: allItems, locale: targetLocale)
                    
                    // 3. カテゴリ別割合カード
                    CategoryBreakdownView(allItems: allItems, locale: targetLocale)
                    
                    Color.clear.frame(height: 50)
                }
                .padding()
            }
            .navigationTitle(Text("統計レポート"))
            .background(Color(.systemGroupedBackground))
        }
        // アプリ全体のロケールを強制適用
        .environment(\.locale, targetLocale)
        // 言語変更時にViewを再構築させるID
        .id(language)
    }
}

// MARK: - 1. 今日の進捗 View
struct TodayProgressView: View {
    let allItems: [ToDoItem]
    let locale: Locale
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("今日の進捗")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            let stats = calculateTodayStats()
            
            HStack {
                Chart {
                    SectorMark(
                        angle: .value(Text("完了"), stats.completed),
                        innerRadius: .ratio(0.6), angularInset: 2
                    )
                    .foregroundStyle(Color.blue.gradient)
                    
                    SectorMark(
                        angle: .value(Text("未完了"), stats.remaining),
                        innerRadius: .ratio(0.6), angularInset: 2
                    )
                    .foregroundStyle(Color.gray.opacity(0.2))
                }
                .frame(height: 150)
                
                VStack(alignment: .leading) {
                    Text("\(stats.completed)/\(stats.total)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    Text("タスク完了")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if stats.total > 0 {
                        let progress = Double(stats.completed) / Double(stats.total)
                        let percentage = Int(progress * 100)
                        
                        Text("消化率 \(percentage)%")
                            .font(.subheadline)
                            .foregroundStyle(percentage == 100 ? .green : .primary)
                            .padding(.top, 4)
                    }
                }
                .padding(.leading)
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    private func calculateTodayStats() -> (total: Int, completed: Int, remaining: Int) {
        var calendar = Calendar.current
        calendar.locale = locale
        
        let todayItems = allItems.filter { calendar.isDateInToday($0.date) }
        let total = todayItems.count
        let completed = todayItems.filter { $0.isCompleted }.count
        return (total, completed, total - completed)
    }
}

// MARK: - 2. 週間アクティビティ View
struct WeeklyActivityView: View {
    let allItems: [ToDoItem]
    let locale: Locale
    
    @AppStorage("language") private var language: String = "ja"
    
    struct StackedData: Identifiable {
        let id = UUID()
        let date: Date
        let category: Category
        let count: Int
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("過去7日間の完了数 (内訳)")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            let weeklyData = calculateWeeklyStackedStats()
            
            Chart {
                ForEach(weeklyData) { data in
                    BarMark(
                        x: .value("日付", data.date, unit: .day),
                        y: .value("完了数", data.count)
                    )
                    .foregroundStyle(by: .value("Category", categoryString(data.category)))
                }
            }
            .chartForegroundStyleScale([
                categoryString(.work): .blue,
                categoryString(.privateLife): .green,
                categoryString(.shopping): .orange
            ])
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(), centered: true)
                }
            }
            .frame(height: 250)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    private func categoryString(_ category: Category) -> String {
        switch category {
        case .work: return language == "en" ? "Work" : "仕事"
        case .privateLife: return language == "en" ? "Personal" : "プライベート"
        case .shopping: return language == "en" ? "Shopping" : "買い物"
        }
    }
    
    private func calculateWeeklyStackedStats() -> [StackedData] {
        var calendar = Calendar.current
        calendar.locale = locale
        let today = calendar.startOfDay(for: Date())
        var stats: [StackedData] = []
        
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: -6 + i, to: today) {
                let dailyItems = allItems.filter { item in
                    item.isCompleted && calendar.isDate(item.date, inSameDayAs: date)
                }
                for category in Category.allCases {
                    let count = dailyItems.filter { $0.category == category }.count
                    if count > 0 {
                        stats.append(StackedData(date: date, category: category, count: count))
                    }
                }
            }
        }
        return stats
    }
}

// MARK: - 3. カテゴリ別割合 View
struct CategoryBreakdownView: View {
    let allItems: [ToDoItem]
    let locale: Locale
    
    @AppStorage("language") private var language: String = "ja"
    
    @State private var selectedRange: StatRange = .all
    
    struct CategoryCount {
        let category: Category
        let count: Int
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("カテゴリ別割合")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("期間", selection: $selectedRange) {
                    ForEach(StatRange.allCases) { range in
                        Text(range.localizedKey).tag(range)
                    }
                }
                .pickerStyle(.menu)
            }
            
            let categoryData = calculateCategoryStats(range: selectedRange)
            
            if categoryData.isEmpty {
                VStack {
                    Spacer()
                    Text("データがありません")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(height: 150)
                .frame(maxWidth: .infinity)
            } else {
                HStack {
                    Chart(categoryData, id: \.category) { data in
                        SectorMark(
                            angle: .value("件数", data.count),
                            innerRadius: .ratio(0.0),
                            angularInset: 1
                        )
                        .foregroundStyle(by: .value("Category", categoryString(data.category)))
                    }
                    .chartForegroundStyleScale([
                        categoryString(.work): .blue,
                        categoryString(.privateLife): .green,
                        categoryString(.shopping): .orange
                    ])
                    .frame(height: 150)
                    
                    // リスト形式の凡例
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Category.allCases) { category in
                            HStack {
                                Circle()
                                    .fill(categoryColor(category))
                                    .frame(width: 8, height: 8)
                                
                                Text(categoryString(category))
                                    .font(.caption)
                                    // ★修正: ここで型エラーが出ていたため、Color.primary と Color.gray を使用
                                    .foregroundStyle(isCategoryActive(category, in: categoryData) ? Color.primary : Color.gray.opacity(0.5))
                                
                                // 件数表示
                                if let match = categoryData.first(where: { $0.category == category }) {
                                    Text("\(match.count)件")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("0件")
                                        .font(.caption)
                                        // ★修正: ここも Color.gray を使用
                                        .foregroundStyle(Color.gray.opacity(0.5))
                                }
                            }
                        }
                    }
                    .padding(.leading)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    private func isCategoryActive(_ category: Category, in data: [CategoryCount]) -> Bool {
        return data.contains(where: { $0.category == category })
    }
    
    private func categoryString(_ category: Category) -> String {
        switch category {
        case .work: return language == "en" ? "Work" : "仕事"
        case .privateLife: return language == "en" ? "Personal" : "プライベート"
        case .shopping: return language == "en" ? "Shopping" : "買い物"
        }
    }
    
    private func categoryColor(_ category: Category) -> Color {
        switch category {
        case .work: return .blue
        case .privateLife: return .green
        case .shopping: return .orange
        }
    }
    
    private func calculateCategoryStats(range: StatRange) -> [CategoryCount] {
        var calendar = Calendar.current
        calendar.locale = locale
        let now = Date()
        
        let filteredItems = allItems.filter { item in
            switch range {
            case .all: return true
            case .week: return calendar.isDate(item.date, equalTo: now, toGranularity: .weekOfYear)
            case .month: return calendar.isDate(item.date, equalTo: now, toGranularity: .month)
            }
        }
        
        let grouped = Dictionary(grouping: filteredItems, by: { $0.category })
        return grouped.map { (key, values) in
            CategoryCount(category: key, count: values.count)
        }.sorted { $0.count > $1.count }
    }
}
