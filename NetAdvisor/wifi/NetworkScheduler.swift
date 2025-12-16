//
//  NetworkScheduler.swift
//  NetAdvisor
//
//  Created by Rama Krishna Konda on 16/12/25.
//
import Foundation

/// Lightweight periodic task scheduler.
/// - Uses DispatchSourceTimer (accurate + power efficient)
/// - Does NOT depend on SwiftUI or MainActor
/// - Safe to call from any thread
final class NetworkScheduler {

    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "netadvisor.scheduler.queue")

    /// Starts a periodic task
    /// - Parameters:
    ///   - interval: interval in seconds
    ///   - task: closure executed on background queue
    func start(interval: TimeInterval, task: @escaping () -> Void) {
        stop() // ensure no duplicate timers

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(
            deadline: .now(),
            repeating: interval,
            leeway: .seconds(1)
        )

        timer.setEventHandler(handler: task)
        timer.resume()

        self.timer = timer
    }

    /// Stops the running task
    func stop() {
        timer?.cancel()
        timer = nil
    }

    deinit {
        stop()
    }
}
