import Foundation
import SwiftData
import SwiftUI

// カテゴリ定義
enum Category: String, Codable, CaseIterable, Identifiable {
    case work = "仕事"
    case privateLife = "プライベート"
    case shopping = "買い物"
    
    var id: String { self.rawValue }
    
    var localizedName: LocalizedStringKey {
        LocalizedStringKey(self.rawValue)
    }
    
    var localizedString: String {
            switch self {
            case .work: return String(localized: "仕事")
            case .privateLife: return String(localized: "プライベート")
            case .shopping: return String(localized: "買い物")
            }
        }
}
// 重要度定義
enum Priority: Int, Codable, CaseIterable, Identifiable, Comparable {
    case low = 1    // 低
    case medium = 2 // 中
    case high = 3   // 高
    
    var id: Int { self.rawValue }
    
    var title: LocalizedStringKey {
        switch self {
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        }
    }
    
    static func < (lhs: Priority, rhs: Priority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

@Model
final class ToDoItem {
    var id: UUID
    var title: String
    var date: Date
    var priority: Priority
    var category: Category
    var isCompleted: Bool
    var repeatGroupId: UUID? // 繰り返しタスクを識別するためのID
    
    init(title: String, date: Date, priority: Priority, category: Category, repeatGroupId: UUID? = nil) {
        self.id = UUID()
        self.title = title
        self.date = date
        self.priority = priority
        self.category = category
        self.isCompleted = false
        self.repeatGroupId = repeatGroupId
    }
}
