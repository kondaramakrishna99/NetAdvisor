//
//  NetworkHealthMonitor.swift
//  NetAdvisor
//
//  Created by Rama Krishna Konda on 16/12/25.
//
import Foundation
import Network
import Combine

final class NetworkHealthMonitor: ObservableObject {

    @Published private(set) var isPathHealthy: Bool = false
    @Published private(set) var isInternetReachable: Bool = false

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkHealthMonitor")
    private let internetChecker = InternetReachabilityChecker()

    private var lastInternetCheck: Date?

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isPathHealthy = (path.status == .satisfied)
            }

            if path.status == .satisfied {
                self?.checkInternetIfNeeded()
            } else {
                DispatchQueue.main.async {
                    self?.isInternetReachable = false
                }
            }
        }

        monitor.start(queue: queue)
    }

    private func checkInternetIfNeeded() {
        let now = Date()
        if let last = lastInternetCheck, now.timeIntervalSince(last) < 30 {
            return // avoid spam
        }

        lastInternetCheck = now

        internetChecker.check { [weak self] reachable in
            DispatchQueue.main.async {
                self?.isInternetReachable = reachable
            }
        }
    }
}
