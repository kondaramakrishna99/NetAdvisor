//
//  ScanScheduler.swift
//  NetAdvisor
//
//  Created by Rama Krishna Konda on 16/12/25.
//

import Foundation

final class ScanScheduler {

    private var timer: Timer?
    private let interval: TimeInterval
    private let action: () -> Void

    init(interval: TimeInterval, action: @escaping () -> Void) {
        self.interval = interval
        self.action = action
    }

    func start() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            self.action()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
