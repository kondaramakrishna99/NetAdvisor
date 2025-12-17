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
        let band = bandScore(network.band)
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
        case -45...0: return 55
        case -55..<(-45): return 45
        case -65..<(-55): return 35
        case -75..<(-65): return 25
        case -85..<(-75): return 15
        default: return 5
        }
    }

    private static func bandScore(_ band: WiFiBand) -> Int {
        switch band {
        case .fiveGHz: return 10   // reduced weight
        case .twoPointFourGHz: return 5
        }
    }

    private static func securityScore(_ security: String) -> Int {
        if security.contains("WPA3") { return 10 }
        if security.contains("WPA2") { return 7 }
        if security.contains("WPA") { return 4 }
        return 0
    }
}
