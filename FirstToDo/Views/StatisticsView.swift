import SwiftUI
import SwiftData
import Charts

// 統計の期間選択用
enum StatRange: String, CaseIterable, Identifiable {
    case week = "今週"
    case month = "今月"
    case all = "全期間"
    
    var id: String { self.rawValue }
}

struct StatisticsView: View {
    @Query private var allItems: [ToDoItem]
    
    // カテゴリ割合の期間選択
    @State private var selectedCategoryRange: StatRange = .all
    
    // グラフの配色定義
    // Swift Chartsの色指定用に、Category型をキーにしたマッピングを用意
    let categoryColors: [String: Color] = [
        Category.work.rawValue: .blue,
        Category.privateLife.rawValue: .green,
        Category.shopping.rawValue: .orange
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // 1. 今日の消化率 (変更なし)
                    VStack(alignment: .leading) {
                        Text("今日の進捗")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        let todayStats = calculateTodayStats()
                        HStack {
                            Chart {
                                SectorMark(
                                    angle: .value("完了", todayStats.completed),
                                    innerRadius: .ratio(0.6), angularInset: 2
                                )
                                .foregroundStyle(Color.blue.gradient)
                                SectorMark(
                                    angle: .value("未完了", todayStats.remaining),
                                    innerRadius: .ratio(0.6), angularInset: 2
                                )
                                .foregroundStyle(Color.gray.opacity(0.2))
                            }
                            .frame(height: 150)
                            
                            VStack(alignment: .leading) {
                                Text("\(todayStats.completed)/\(todayStats.total)")
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                Text("タスク完了")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                if todayStats.total > 0 {
                                    let percentage = Int((Double(todayStats.completed) / Double(todayStats.total)) * 100)
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
                    
                    // 2. 週間アクティビティ (積み上げ棒グラフ)
                    VStack(alignment: .leading) {
                        Text("過去7日間の完了数 (内訳)")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        let weeklyData = calculateWeeklyStackedStats()
                        
                        // 積み上げ棒グラフ
                        Chart(weeklyData, id: \.id) { data in
                            BarMark(
                                x: .value("日付", data.date, unit: .day),
                                y: .value("完了数", data.count)
                            )
                            // ★ここがポイント: カテゴリで色を分ける（積み上げ）
                            .foregroundStyle(by: .value("カテゴリ", data.category.rawValue))
                        }
                        // カテゴリごとの色を指定
                        .chartForegroundStyleScale([
                            Category.work.rawValue: .blue,
                            Category.privateLife.rawValue: .green,
                            Category.shopping.rawValue: .orange
                        ])
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day)) { value in
                                AxisValueLabel(format: .dateTime.weekday(), centered: true)
                            }
                        }
                        .frame(height: 250)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    
                    // 3. カテゴリ別割合 (期間切り替え付き)
                    VStack(alignment: .leading) {
                        HStack {
                            Text("カテゴリ別割合")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            // 期間切り替えピッカー
                            Picker("期間", selection: $selectedCategoryRange) {
                                ForEach(StatRange.allCases) { range in
                                    Text(range.rawValue).tag(range)
                                }
                            }
                            .pickerStyle(.menu) // コンパクトなメニュー形式
                        }
                        
                        let categoryData = calculateCategoryStats(range: selectedCategoryRange)
                        
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
                                    .foregroundStyle(by: .value("カテゴリ", data.category.rawValue))
                                }
                                .chartForegroundStyleScale([
                                    Category.work.rawValue: .blue,
                                    Category.privateLife.rawValue: .green,
                                    Category.shopping.rawValue: .orange
                                ])
                                .frame(height: 150)
                                
                                // 凡例
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(categoryData, id: \.category) { data in
                                        HStack {
                                            Circle()
                                                .fill(Color(categoryColors[data.category.rawValue] ?? .gray))
                                                .frame(width: 8, height: 8)
                                            Text(data.category.rawValue)
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
                    
                    Color.clear.frame(height: 50)
                }
                .padding()
            }
            .navigationTitle("統計レポート")
            .background(Color(.systemGroupedBackground))
        }
    }
    
    // --- 計算ロジック ---
    
    // 1. 今日の集計
    private func calculateTodayStats() -> (total: Int, completed: Int, remaining: Int) {
        let calendar = Calendar.current
        let todayItems = allItems.filter { calendar.isDateInToday($0.date) }
        let total = todayItems.count
        let completed = todayItems.filter { $0.isCompleted }.count
        return (total, completed, total - completed)
    }
    
    // 2. 週間集計 (積み上げ用データ構造)
    struct StackedData: Identifiable {
        let id = UUID()
        let date: Date
        let category: Category
        let count: Int
    }
    
    private func calculateWeeklyStackedStats() -> [StackedData] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var stats: [StackedData] = []
        
        // 過去7日間ループ
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: -6 + i, to: today) {
                // その日の完了タスクを取得
                let dailyItems = allItems.filter { item in
                    item.isCompleted && calendar.isDate(item.date, inSameDayAs: date)
                }
                
                // カテゴリごとに集計してデータに追加
                for category in Category.allCases {
                    let count = dailyItems.filter { $0.category == category }.count
                    // 0件でもグラフの整合性のために追加してもいいが、0なら追加しなくてもOK（今回は追加しない）
                    if count > 0 {
                        stats.append(StackedData(date: date, category: category, count: count))
                    }
                }
            }
        }
        return stats
    }
    
    // 3. カテゴリ別集計 (期間フィルタ対応)
    struct CategoryCount {
        let category: Category
        let count: Int
    }
    
    private func calculateCategoryStats(range: StatRange) -> [CategoryCount] {
        let calendar = Calendar.current
        let now = Date()
        
        // 期間でフィルタリング
        let filteredItems = allItems.filter { item in
            // 条件1: そもそもタスクとしてカウントすべきか（完了済みのみにするか、未完了も含めるか？）
            // 統計なので「何件あるか」を見るため全件対象にしますが、
            // 「消化した割合」を見たい場合は `&& item.isCompleted` を追加してください。
            // 今回は「登録されているタスクのカテゴリ内訳」として全件表示します。
            
            switch range {
            case .all:
                return true
            case .week:
                // 今週の定義（日曜始まり等）
                return calendar.isDate(item.date, equalTo: now, toGranularity: .weekOfYear)
            case .month:
                // 今月の定義
                return calendar.isDate(item.date, equalTo: now, toGranularity: .month)
            }
        }
        
        // カテゴリごとにグルーピングしてカウント
        let grouped = Dictionary(grouping: filteredItems, by: { $0.category })
        
        return grouped.map { (key, values) in
            CategoryCount(category: key, count: values.count)
        }.sorted { $0.count > $1.count }
    }
}
