import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    
    // 通知の許可をリクエスト
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("通知許可が得られました")
            } else if let error = error {
                print("通知許可エラー: \(error.localizedDescription)")
            }
        }
    }
    
    // 指定した時間の通知をセットする（タスク数を引数で受け取る）
    func scheduleNotifications(taskCount: Int, notifyAt8: Bool, notifyAt12: Bool, notifyAt17: Bool) {
        // 一旦既存の通知を全てキャンセル（重複防止）
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        guard taskCount > 0 else { return } // タスクが0なら通知しない
        
        if notifyAt8 { scheduleRequest(hour: 8, taskCount: taskCount) }
        if notifyAt12 { scheduleRequest(hour: 12, taskCount: taskCount) }
        if notifyAt17 { scheduleRequest(hour: 17, taskCount: taskCount) }
    }
    
    private func scheduleRequest(hour: Int, taskCount: Int) {
        let content = UNMutableNotificationContent()
        content.title = "今日のタスク確認"
        content.body = "今日の残りのタスクはあと \(taskCount) 件です。頑張りましょう！"
        content.sound = .default
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "daily_notification_\(hour)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
}
