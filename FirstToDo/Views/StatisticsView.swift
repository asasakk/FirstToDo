import SwiftUI
import SwiftData
import Charts

// 統計の期間選択用
enum StatRange: String, CaseIterable, Identifiable {
    case week = "今週"
    case month = "今月"
    case all = "全期間"
    
    var id: String { self.rawValue }
    
    var localizedString: String {
        switch self {
        case .week: return String(localized: "今週")
        case .month: return String(localized: "今月")
        case .all: return String(localized: "全期間")
        }
    }
}

struct StatisticsView: View {
    @Query private var allItems: [ToDoItem]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 1. 今日の進捗カード
                    TodayProgressView(allItems: allItems)
                    
                    // 2. 週間アクティビティカード
                    WeeklyActivityView(allItems: allItems)
                    
                    // 3. カテゴリ別割合カード
                    CategoryBreakdownView(allItems: allItems)
                    
                    Color.clear.frame(height: 50)
                }
                .padding()
            }
            .navigationTitle("統計レポート")
            .background(Color(.systemGroupedBackground))
        }
    }
}

// MARK: - 1. 今日の進捗 View
struct TodayProgressView: View {
    let allItems: [ToDoItem]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("今日の進捗")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            let stats = calculateTodayStats()
            
            HStack {
                Chart {
                    SectorMark(
                        angle: .value("完了", stats.completed),
                        innerRadius: .ratio(0.6), angularInset: 2
                    )
                    .foregroundStyle(Color.blue.gradient)
                    
                    SectorMark(
                        angle: .value("未完了", stats.remaining),
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
                        // 計算を明確に分けることでコンパイラの負担を減らす
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
        let calendar = Calendar.current
        let todayItems = allItems.filter { calendar.isDateInToday($0.date) }
        let total = todayItems.count
        let completed = todayItems.filter { $0.isCompleted }.count
        return (total, completed, total - completed)
    }
}

// MARK: - 2. 週間アクティビティ View
struct WeeklyActivityView: View {
    let allItems: [ToDoItem]
    
    // データ構造
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
            
            Chart(weeklyData, id: \.id) { data in
                BarMark(
                    x: .value("日付", data.date, unit: .day),
                    y: .value("完了数", data.count)
                )
                .foregroundStyle(by: .value("Category", data.category.localizedString))
            }
            .chartForegroundStyleScale([
                Category.work.localizedString: .blue,
                Category.privateLife.localizedString: .green,
                Category.shopping.localizedString: .orange
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
    
    private func calculateWeeklyStackedStats() -> [StackedData] {
        let calendar = Calendar.current
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
                        Text(range.localizedString).tag(range)
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
                        .foregroundStyle(by: .value("Category", data.category.localizedString))
                    }
                    .chartForegroundStyleScale([
                        Category.work.localizedString: .blue,
                        Category.privateLife.localizedString: .green,
                        Category.shopping.localizedString: .orange
                    ])
                    .frame(height: 150)
                    
                    // 凡例
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(categoryData, id: \.category) { data in
                            HStack {
                                Circle()
                                    .fill(categoryColor(data.category))
                                    .frame(width: 8, height: 8)
                                Text(data.category.localizedString)
                                    .font(.caption)
                                Text("\(data.count)件")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
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
    
    private func categoryColor(_ category: Category) -> Color {
        switch category {
        case .work: return .blue
        case .privateLife: return .green
        case .shopping: return .orange
        default: return .gray
        }
    }
    
    private func calculateCategoryStats(range: StatRange) -> [CategoryCount] {
        let calendar = Calendar.current
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
