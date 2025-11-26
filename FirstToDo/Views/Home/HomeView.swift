import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    
    // 入力用State
    @State private var title: String = ""
    @State private var selectedDate: Date = Date()
    @State private var selectedPriority: Priority = .medium
    @State private var selectedCategory: Category = .work
    
    // 繰り返し用State
    @State private var isRepeatEnabled: Bool = false
    @State private var repeatWeekdays: Set<Int> = [] // 1=Sun, 2=Mon...
    @State private var repeatEndDate: Date = Date().addingTimeInterval(60*60*24*30)
    
    // トースト通知用
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""
    
    
    @State private var showSettings: Bool = false
    
    var body: some View {
        
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            
            NavigationStack {
                ZStack {
                    Form {
                        Section(header: Text("タスク情報")) {
                            TextField("タイトルを入力", text: $title)
                            
                            DatePicker("日付と時間", selection: $selectedDate)
                                .environment(\.locale, Locale(identifier: "ja_JP"))
                                .onAppear {
                                    setupDefaultTime()
                                }
                            
                            Picker("重要度", selection: $selectedPriority) {
                                ForEach(Priority.allCases) { priority in
                                    Text(priority.title).tag(priority)
                                }
                            }
                            .pickerStyle(.segmented)
                            
                            Picker("カテゴリ", selection: $selectedCategory) {
                                ForEach(Category.allCases) { category in
                                    Text(category.rawValue).tag(category)
                                }
                            }
                        }
                        
                        Section(header: Text("繰り返し設定")) {
                            Toggle("繰り返す", isOn: $isRepeatEnabled)
                            
                            if isRepeatEnabled {
                                // 曜日の複数選択 (修正版)
                                HStack {
                                    ForEach(1...7, id: \.self) { weekday in
                                        let symbol = Calendar.current.shortWeekdaySymbols[weekday - 1]
                                        let isSelected = repeatWeekdays.contains(weekday)
                                        
                                        Text(symbol)
                                            .font(.caption)
                                            .fontWeight(isSelected ? .bold : .regular)
                                            .frame(width: 35, height: 35)
                                            .background(isSelected ? Color.blue : Color.gray.opacity(0.1))
                                            .foregroundColor(isSelected ? .white : .primary)
                                            .clipShape(Circle())
                                            .onTapGesture {
                                                if isSelected {
                                                    repeatWeekdays.remove(weekday)
                                                } else {
                                                    repeatWeekdays.insert(weekday)
                                                }
                                            }
                                    }
                                }
                                .padding(.vertical, 4)
                                
                                DatePicker("いつまで繰り返すか", selection: $repeatEndDate, displayedComponents: .date).environment(\.locale, Locale(identifier: "ja_JP"))
                            }
                        }
                        
                        Button("登録する") {
                            saveTask()
                        }
                        .disabled(title.isEmpty)
                    }
                    
                    // トースト通知 (ZStackの最前面に表示)
                    if showToast {
                        VStack {
                            Spacer()
                            Text(toastMessage)
                                .padding()
                                .background(.thinMaterial)
                                .cornerRadius(10)
                                .shadow(radius: 5)
                                .padding(.bottom, 50)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        .zIndex(1) // 最前面を保証
                    }
                }
                .navigationTitle("タスク登録")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: {
                            showSettings = true
                        }) {
                            Image(systemName: "gearshape.fill")
                                .foregroundStyle(.gray)
                        }
                    }
                }
                // ★追加: 設定画面シート
                .sheet(isPresented: $showSettings) {
                    SettingsView()
                }
            }
            // ★追加: ここで全体を少し下げます（数値はお好みで調整してください）
            .padding(.top, 20)
        }
    }
    
    private func setupDefaultTime() {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 23
        components.minute = 59
        if let defaultDate = Calendar.current.date(from: components) {
            selectedDate = defaultDate
        }
    }
    
    private func saveTask() {
        // ... (保存ロジックは前回と同じですが、一応記載します) ...
        if isRepeatEnabled && !repeatWeekdays.isEmpty {
            let groupId = UUID()
            let calendar = Calendar.current
            
            // 開始日が指定曜日でなければ、最初の該当日まで進める処理を入れるとより親切ですが
            // ここではシンプルに指定日～終了日の間で該当する曜日をすべて登録します
            
            // 日付のみ比較するために開始時間をリセットしてループさせても良いですが、
            // 今回はユーザー指定の時間(23:59等)を維持するためそのまま回します
            
            let startComponents = calendar.dateComponents([.hour, .minute], from: selectedDate)
            
            var loopDate = calendar.startOfDay(for: selectedDate) // ループ用は0:00基準にする
            let endLoopDate = calendar.startOfDay(for: repeatEndDate)
            
            while loopDate <= endLoopDate {
                let weekday = calendar.component(.weekday, from: loopDate)
                
                if repeatWeekdays.contains(weekday) {
                    // 時間をユーザー指定のものに戻す
                    var targetDate = loopDate
                    if let hour = startComponents.hour, let minute = startComponents.minute {
                        targetDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: loopDate) ?? loopDate
                    }
                    
                    let newItem = ToDoItem(title: title, date: targetDate, priority: selectedPriority, category: selectedCategory, repeatGroupId: groupId)
                    modelContext.insert(newItem)
                }
                
                // 翌日へ
                if let next = calendar.date(byAdding: .day, value: 1, to: loopDate) {
                    loopDate = next
                } else {
                    break
                }
            }
            showToastMessage("繰り返しタスクを登録しました")
        } else {
            // 単発登録
            let newItem = ToDoItem(title: title, date: selectedDate, priority: selectedPriority, category: selectedCategory)
            modelContext.insert(newItem)
            showToastMessage("タスクを登録しました")
        }
        
        // 入力リセット
        title = ""
        // 日付などはリセットせずそのままの方が連続登録しやすい場合もありますが、要件次第でリセットしてください
    }
    
    private func showToastMessage(_ message: String) {
        toastMessage = message
        withAnimation {
            showToast = true
        }
        // 2秒後に消える
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showToast = false
            }
        }
    }
}
