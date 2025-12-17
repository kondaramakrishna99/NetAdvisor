//
//  NetworkViewModel.swift
//  NetAdvisor
//
//  Created by Rama Krishna Konda on 16/12/25.
//

import Foundation
import Combine
import SwiftUI
import CoreWLAN

@MainActor
final class NetworkViewModel: ObservableObject {

    @Published var networks: [ScannedNetwork] = []
    @Published var isScanning = false
    @Published var isInternetAvailable = false
    @Published var isWiFiPathHealthy = false
    @Published var currentSSID: String?
    
    private let scanner: NetworkScanner
    private let healthMonitor: NetworkHealthMonitor
    private let scheduler: NetworkScheduler

    private var cancellables = Set<AnyCancellable>()

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

    convenience init() {
        self.init(
            scanner: NetworkScanner(),
            healthMonitor: NetworkHealthMonitor(),
            scheduler: NetworkScheduler()
        )
    }

    func stop() {
        scheduler.stop()
        cancellables.removeAll()
    }

    private func bindHealthMonitor() {
        healthMonitor.$isPathHealthy
            .sink { [weak self] in self?.isWiFiPathHealthy = $0 }
            .store(in: &cancellables)

        healthMonitor.$isInternetReachable
            .sink { [weak self] in self?.isInternetAvailable = $0 }
            .store(in: &cancellables)
    }

    private func startPeriodicScanning() {
        scheduler.start(interval: 20) { [weak self] in
            guard let self, self.isWiFiPathHealthy else { return }
            self.scanOnce()
        }
    }

    func scanOnce() {
        isScanning = true

        scanner.scanForNetworks { [weak self] cwNetworks in
            guard let self else { return }
            self.currentSSID = self.scanner.getCurrentNetwork()?.ssid
            
            let scanned = cwNetworks.map { ScannedNetwork(from: $0) }

            self.networks = scanned.sorted {
                $0.score(internetAvailable: self.isInternetAvailable) >
                $1.score(internetAvailable: self.isInternetAvailable)
            }

            self.isScanning = false
        }
    }

    deinit {
        // ✅ empty on purpose (Swift 6 safe)
    }
}
