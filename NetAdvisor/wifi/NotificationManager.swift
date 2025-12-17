//
//  NotificationManager.swift
//  NetAdvisor
//
//  Created by Rama Krishna Konda on 17/12/25.
//

import UserNotifications

final class NotificationManager {

    static let shared = NotificationManager()

    private init() {}

    func requestPermissionIfNeeded() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func notifyBetterNetwork(current: String, best: String, delta: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Better Wi-Fi Available"
        content.body =
            "You're connected to \(current).\n" +
            "\(best) is significantly better (\(delta) points)."

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}
