//
//  NetAdvisorApp.swift
//  NetAdvisor
//
//  Created by Rama Krishna Konda on 14/12/25.
//

import SwiftUI

@main
struct NetAdvisorApp: App {
    init() {
        NotificationManager.shared.requestPermissionIfNeeded()
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
