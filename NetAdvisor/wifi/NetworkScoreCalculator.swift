//
//  NetworkScoreCalculator.swift
//  NetAdvisor
//
//  Created by Rama Krishna Konda on 17/12/25.
//

import Foundation

struct NetworkScoreCalculator {

    static func score(
        network: ScannedNetwork,
        internetAvailable: Bool
    ) -> Int {

        let signal = signalScore(network.rssi)
        let band = bandScore(network.band, rssi: network.rssi)
        let security = securityScore(network.security)
        let internet = internetAvailable ? 10 : 0

        // 🔑 Hard guard: weak signal can NEVER be best
        if signal < 20 {
            return signal + internet
        }

        let total = signal + band + security + internet
        return min(total, 100)
    }

    // MARK: - Subscores

    private static func signalScore(_ rssi: Int) -> Int {
        switch rssi {
        case -45...0: return 50      // Reduced from 55 to balance with band
        case -55..<(-45): return 40  // Reduced from 45
        case -65..<(-55): return 30  // Reduced from 35
        case -75..<(-65): return 20  // Reduced from 25
        case -85..<(-75): return 10  // Reduced from 15
        default: return 5
        }
    }

    private static func bandScore(_ band: WiFiBand, rssi: Int) -> Int {
        switch band {
        case .fiveGHz:
            // 5GHz gets higher bonus when signal is good enough
            // This reflects real-world performance for bandwidth-intensive tasks
            if rssi >= -60 {
                return 20  // Strong 5GHz signal = excellent performance
            } else if rssi >= -70 {
                return 15  // Moderate 5GHz signal = good performance
            } else {
                return 10  // Weak 5GHz signal = still better than 2.4GHz
            }
            
        case .twoPointFourGHz:
            // 2.4GHz gets lower score due to congestion and lower bandwidth
            return 5
        }
    }

    private static func securityScore(_ security: String) -> Int {
        if security.contains("WPA3") { return 10 }
        if security.contains("WPA2") { return 7 }
        if security.contains("WPA") { return 4 }
        return 0
    }
}
