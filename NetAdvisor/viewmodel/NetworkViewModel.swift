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
    @Published var currentNetworkID: String?
    @Published var bestNetworkID: String?
    private var lastNotifiedBestID: String?
    private let scoreDeltaThreshold = 1
    private let scanner: NetworkScanner
    private let healthMonitor: NetworkHealthMonitor
    private let scheduler: NetworkScheduler
    private var lastNotifiedBestSSID: String?
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
        NotificationManager.shared.requestPermissionIfNeeded()
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
    
    private func determineCurrentNetwork(
        from networks: [ScannedNetwork]
    ) -> ScannedNetwork? {

        guard let currentSSID else { return nil }

        // Pick strongest network among same SSID
        return networks
            .filter { $0.ssid == currentSSID }
            .max(by: { $0.rssi < $1.rssi })
    }
    
    private func determineBestNetwork(
        networks: [ScannedNetwork],
        current: ScannedNetwork?
    ) -> ScannedNetwork? {

        networks
            .filter { $0.id != current?.id }
            .max {
                $0.score(internetAvailable: isInternetAvailable) <
                $1.score(internetAvailable: isInternetAvailable)
            }
    }
    
    private func logNetworkScores(
        networks: [ScannedNetwork],
        current: ScannedNetwork?,
        best: ScannedNetwork?
    ) {
        print("========== NetAdvisor Scan ==========")

        for network in networks {
            let score = network.score(internetAvailable: isInternetAvailable)

            var flags: [String] = []
            if network.id == current?.id { flags.append("CURRENT") }
            if network.id == best?.id { flags.append("BEST") }

            let flagText = flags.isEmpty ? "" : " [\(flags.joined(separator: ", "))]"

            print("""
            SSID: \(network.ssid)
            RSSI: \(network.rssi)
            Band: \(network.band)
            Security: \(network.security)
            Score: \(score)\(flagText)
            -----------------------------------
            """)
        }

        print("=====================================\n")
    }
    
    private func evaluateRecommendation() {
        guard
            let currentSSID,
            let currentNetwork = networks.first(where: { $0.ssid == currentSSID }),
            let bestNetwork = networks.first
        else { return }

        let currentScore = currentNetwork.score(
            internetAvailable: isInternetAvailable
        )
        let bestScore = bestNetwork.score(
            internetAvailable: isInternetAvailable
        )

        let delta = bestScore - currentScore
        let threshold = 15

        guard
            delta >= threshold,
            bestNetwork.ssid != currentSSID,
            bestNetwork.ssid != lastNotifiedBestSSID
        else { return }

        lastNotifiedBestSSID = bestNetwork.ssid

        NotificationManager.shared.notifyBetterNetwork(
            current: currentNetwork.ssid,
            best: bestNetwork.ssid,
            delta: delta
        )
    }
    
    private func notifyBetterNetworkAvailable(
        current: ScannedNetwork,
        best: ScannedNetwork,
        delta: Int
    ) {
        NotificationManager.shared.notifyBetterNetwork(
            current: current.ssid,
            best: best.ssid,
            delta: delta
        )
    }

    func scanOnce() {
        isScanning = true

        scanner.scanForNetworks { [weak self] cwNetworks in
            guard let self else { return }

            Task { @MainActor in
                self.currentSSID = self.scanner.getCurrentNetwork()?.ssid

                let scanned = cwNetworks.map { ScannedNetwork(from: $0) }

                let current = self.determineCurrentNetwork(from: scanned)
                let best = self.determineBestNetwork(
                    networks: scanned,
                    current: current
                )

                self.currentNetworkID = current?.id
                self.bestNetworkID = best?.id

                self.networks = scanned.sorted {
                    $0.score(internetAvailable: self.isInternetAvailable) >
                    $1.score(internetAvailable: self.isInternetAvailable)
                }

                self.evaluateNotification(
                    current: current,
                    best: best
                )
                
                self.logNetworkScores(
                    networks: scanned,
                    current: current,
                    best: best
                )

                self.isScanning = false
            }
        }
    }
    
    private func evaluateNotification(
        current: ScannedNetwork?,
        best: ScannedNetwork?
    ) {
        guard
            let current,
            let best
        else { return }

        let currentScore = current.score(
            internetAvailable: isInternetAvailable
        )
        let bestScore = best.score(
            internetAvailable: isInternetAvailable
        )

        let delta = bestScore - currentScore
        let threshold = 15

        guard
            delta >= threshold,
            best.id != lastNotifiedBestID
        else { return }

        lastNotifiedBestID = best.id

        NotificationManager.shared.notifyBetterNetwork(
            current: current.ssid,
            best: best.ssid,
            delta: delta
        )
    }

    deinit {
        // ✅ empty on purpose (Swift 6 safe)
    }
}
