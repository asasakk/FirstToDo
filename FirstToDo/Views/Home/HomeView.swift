import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    
    @AppStorage("language") private var language: String = "ja"
    
    // ロケール定義
    private var targetLocale: Locale {
        Locale(identifier: language)
    }
    
    private var targetCalendar: Calendar {
        var calendar = Calendar.current
        calendar.locale = targetLocale
        return calendar
    }
    
    // State定義
    @State private var title: String = ""
    @State private var selectedDate: Date = Date()
    @State private var selectedPriority: Priority = .medium
    @State private var selectedCategory: Category = .work
    @State private var isRepeatEnabled: Bool = false
    @State private var repeatWeekdays: Set<Int> = []
    @State private var repeatEndDate: Date = Date().addingTimeInterval(60*60*24*30)
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""
    @State private var showSettings: Bool = false
    
    var body: some View {
        ZStack {
            // ★修正1: キーボードを閉じる判定を、この「背景色」だけに限定する
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
                .onTapGesture {
                    UIApplication.shared.endEditing()
                }
            
            NavigationStack {
                ZStack {
                    Form {
                        Section(header: Text("タスク情報")) {
                            TextField("タイトルを入力", text: $title)
                            
                            DatePicker("日付と時間", selection: $selectedDate)
                                .onAppear { setupDefaultTime() }
                            
                            Picker("重要度", selection: $selectedPriority) {
                                ForEach(Priority.allCases) { priority in
                                    Text(priority.title).tag(priority)
                                }
                            }
                            .pickerStyle(.segmented)
                            
                            Picker("カテゴリ", selection: $selectedCategory) {
                                ForEach(Category.allCases) { category in
                                    Text(category.localizedName).tag(category)
                                }
                            }
                        }
                        
                        Section(header: Text("繰り返し設定")) {
                            Toggle("繰り返す", isOn: $isRepeatEnabled)
                            
                            if isRepeatEnabled {
                                HStack {
                                    ForEach(1...7, id: \.self) { weekday in
                                        let symbol = targetCalendar.shortWeekdaySymbols[weekday - 1]
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
                                
                                DatePicker("いつまで繰り返すか", selection: $repeatEndDate, displayedComponents: .date)
                            }
                        }
                        
                        Button("登録する") {
                            saveTask()
                        }
                        // タイトルが空だと押せない仕様です（グレーアウトしているはず）
                        .disabled(title.isEmpty)
                    }
                    .scrollDismissesKeyboard(.immediately)
                    
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
                        .zIndex(1)
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
                .sheet(isPresented: $showSettings) {
                    SettingsView()
                }
            }
            .environment(\.locale, targetLocale)
            .id(language)
            
            .padding(.top, 20)
        }
        // ★修正2: ここにあった全体への .onTapGesture を削除しました
    }
    
    // --- 以下ロジックは変更なし ---
    private func setupDefaultTime() {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 23
        components.minute = 59
        if let defaultDate = Calendar.current.date(from: components) {
            selectedDate = defaultDate
        }
    }
    
    private func saveTask() {
        if isRepeatEnabled && !repeatWeekdays.isEmpty {
            let groupId = UUID()
            let calendar = Calendar.current
            let startComponents = calendar.dateComponents([.hour, .minute], from: selectedDate)
            var loopDate = calendar.startOfDay(for: selectedDate)
            let endLoopDate = calendar.startOfDay(for: repeatEndDate)
            
            while loopDate <= endLoopDate {
                let weekday = calendar.component(.weekday, from: loopDate)
                if repeatWeekdays.contains(weekday) {
                    var targetDate = loopDate
                    if let hour = startComponents.hour, let minute = startComponents.minute {
                        targetDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: loopDate) ?? loopDate
                    }
                    let newItem = ToDoItem(title: title, date: targetDate, priority: selectedPriority, category: selectedCategory, repeatGroupId: groupId)
                    modelContext.insert(newItem)
                }
                if let next = calendar.date(byAdding: .day, value: 1, to: loopDate) {
                    loopDate = next
                } else {
                    break
                }
            }
            showToastMessage("繰り返しタスクを登録しました")
        } else {
            let newItem = ToDoItem(title: title, date: selectedDate, priority: selectedPriority, category: selectedCategory)
            modelContext.insert(newItem)
            showToastMessage("タスクを登録しました")
        }
        title = ""
        UIApplication.shared.endEditing()
    }
    
    private func showToastMessage(_ message: String) {
        toastMessage = message
        withAnimation {
            showToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showToast = false
            }
        }
    }
}

extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
