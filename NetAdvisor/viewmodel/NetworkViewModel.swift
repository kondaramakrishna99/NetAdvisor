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
        print("🔍 Determining Best Network...")
        
        // Score all networks
        // Only the current network gets the internet bonus since we can only test connectivity on it
        let networksWithScores = networks.map { network -> (network: ScannedNetwork, score: Int) in
            let hasInternet = (network.id == current?.id) ? isInternetAvailable : false
            let score = network.score(internetAvailable: hasInternet)
            return (network, score)
        }
        
        // Log all network scores
        logNetworkScoresWithDetails(networksWithScores: networksWithScores, current: current)
        
        // Filter out networks with very weak signals (score < 20)
        let viableNetworks = networksWithScores.filter { $0.score >= 20 }
        
        // Find the network with the highest score
        guard let best = viableNetworks.max(by: { $0.score < $1.score }) else {
            print("❌ No viable networks found (all scores < 20)")
            return nil
        }
        
        print("🏆 Highest scoring network: \(best.network.ssid) (Score: \(best.score))")
        
        // If the best network is the current network, return nil (no need to switch)
        if let current = current, best.network.id == current.id {
            print("✅ Current network is already the best - no switch needed")
            return nil
        }
        
        // Only recommend switching if the new network is significantly better
        if let current = current,
           let currentScore = networksWithScores.first(where: { $0.network.id == current.id })?.score {
            let scoreDelta = best.score - currentScore
            
            print("📊 Score comparison: Current(\(current.ssid))=\(currentScore) vs Best(\(best.network.ssid))=\(best.score), Delta=\(scoreDelta)")
            
            // Hysteresis: require at least 15 points improvement to recommend switching
            guard scoreDelta >= 15 else {
                print("⚠️ Delta (\(scoreDelta)) below threshold (15) - not recommending switch")
                return nil
            }
            
            print("✅ Recommending switch to \(best.network.ssid) (delta: \(scoreDelta))")
        }
        
        return best.network
    }
    
    private func logNetworkScoresWithDetails(
        networksWithScores: [(network: ScannedNetwork, score: Int)],
        current: ScannedNetwork?
    ) {
        print("========== Network Scoring Details ==========")
        
        for item in networksWithScores.sorted(by: { $0.score > $1.score }) {
            let network = item.network
            let score = item.score
            let hasInternet = (network.id == current?.id) ? isInternetAvailable : false
            
            var flags: [String] = []
            if network.id == current?.id {
                flags.append("CURRENT")
                flags.append(hasInternet ? "INTERNET" : "NO INTERNET")
            }
            
            let flagText = flags.isEmpty ? "" : " [\(flags.joined(separator: ", "))]"
            
            print("""
            SSID: \(network.ssid)
            RSSI: \(network.rssi) dBm
            Band: \(network.band == .fiveGHz ? "5GHz" : "2.4GHz")
            Channel: \(network.channel)
            Security: \(network.security)
            Score: \(score)\(flagText)
            -----------------------------------
            """)
        }
        
        print("=============================================\n")
    }
    
    private func logNetworkScores(
        networks: [ScannedNetwork],
        current: ScannedNetwork?,
        best: ScannedNetwork?
    ) {
        print("========== NetAdvisor Scan ==========")

        for network in networks {
            // Only current network gets internet bonus
            let hasInternet = (network.id == current?.id) ? isInternetAvailable : false
            let score = network.score(internetAvailable: hasInternet)

            var flags: [String] = []
            if network.id == current?.id { 
                flags.append("CURRENT")
                if hasInternet {
                    flags.append("INTERNET")
                } else {
                    flags.append("NO INTERNET")
                }
            }
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
                let bestAlternative = self.determineBestNetwork(
                    networks: scanned,
                    current: current
                )
                
                // Determine the actual best network (including current)
                // Only current network gets internet bonus
                let actualBest = scanned.max { network1, network2 in
                    let hasInternet1 = (network1.id == current?.id) ? self.isInternetAvailable : false
                    let hasInternet2 = (network2.id == current?.id) ? self.isInternetAvailable : false
                    let score1 = network1.score(internetAvailable: hasInternet1)
                    let score2 = network2.score(internetAvailable: hasInternet2)
                    return score1 < score2 && score1 >= 20 && score2 >= 20
                }

                self.currentNetworkID = current?.id
                self.bestNetworkID = actualBest?.id

                // Sort networks by score (only current network gets internet bonus)
                self.networks = scanned.sorted {
                    let hasInternet1 = ($0.id == current?.id) ? self.isInternetAvailable : false
                    let hasInternet2 = ($1.id == current?.id) ? self.isInternetAvailable : false
                    return $0.score(internetAvailable: hasInternet1) >
                           $1.score(internetAvailable: hasInternet2)
                }

                self.evaluateNotification(
                    current: current,
                    best: bestAlternative
                )
                
                self.logNetworkScores(
                    networks: scanned,
                    current: current,
                    best: actualBest
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

        // Current network gets internet bonus, alternative network doesn't
        let currentScore = current.score(
            internetAvailable: isInternetAvailable
        )
        let bestScore = best.score(
            internetAvailable: false  // We don't know if alternative has internet
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
