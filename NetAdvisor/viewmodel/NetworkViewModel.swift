//
//  NetworkViewModel.swift
//  NetAdvisor
//
//  Created by Rama Krishna Konda on 16/12/25.
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class NetworkViewModel: ObservableObject {

    // MARK: - Published State (UI)

    @Published var networks: [ScannedNetwork] = []
    @Published var isScanning: Bool = false
    @Published var isInternetAvailable: Bool = false
    @Published var isWiFiPathHealthy: Bool = false

    // MARK: - Dependencies

    private let scanner: NetworkScanner
    private let healthMonitor: NetworkHealthMonitor
    private let scheduler: NetworkScheduler

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Designated Initializer (NO defaults)

    init(
        scanner: NetworkScanner,
        healthMonitor: NetworkHealthMonitor,
        scheduler: NetworkScheduler
    ) {
        self.scanner = scanner
        self.healthMonitor = healthMonitor
        self.scheduler = scheduler

        bindHealthMonitor()
        startPeriodicScanning()
    }

    // MARK: - Convenience Initializer (SAFE)

    convenience init() {
        self.init(
            scanner: NetworkScanner(),
            healthMonitor: NetworkHealthMonitor(),
            scheduler: NetworkScheduler()
        )
    }

    // MARK: - Bind Health Signals

    private func bindHealthMonitor() {

        healthMonitor.$isPathHealthy
            .sink { [weak self] healthy in
                self?.isWiFiPathHealthy = healthy
            }
            .store(in: &cancellables)

        healthMonitor.$isInternetReachable
            .sink { [weak self] reachable in
                self?.isInternetAvailable = reachable
            }
            .store(in: &cancellables)
    }

    // MARK: - Scanning Control

    private func startPeriodicScanning() {
        scheduler.start(interval: 20) { [weak self] in
            guard let self else { return }

            if self.isWiFiPathHealthy {
                self.scanOnce()
            }
        }
    }

    func scanOnce() {
        isScanning = true

        scanner.scanForNetworks { [weak self] scanned in
            guard let self else { return }
            self.networks = scanned
            self.isScanning = false
        }
    }

    // MARK: - Cleanup

    deinit {
        scheduler.stop()
    }
}
