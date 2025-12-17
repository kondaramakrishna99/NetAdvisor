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

        var score = 0

        // 1️⃣ Signal strength (max 50)
        score += signalScore(network.rssi)

        // 2️⃣ Band preference (max 20)
        score += bandScore(network.band)

        // 3️⃣ Security bonus (max 20)
        score += securityScore(network.security)

        // 4️⃣ Internet availability (max 10)
        if internetAvailable {
            score += 10
        }

        return min(score, 100)
    }

    // MARK: - Subscores

    private static func signalScore(_ rssi: Int) -> Int {
        switch rssi {
        case -50...0: return 50
        case -60..<(-50): return 40
        case -70..<(-60): return 30
        case -80..<(-70): return 20
        default: return 10
        }
    }

    private static func bandScore(_ band: WiFiBand) -> Int {
        switch band {
        case .fiveGHz: return 20
        case .twoPointFourGHz: return 10
        }
    }

    private static func securityScore(_ security: String) -> Int {
        if security.contains("WPA3") { return 20 }
        if security.contains("WPA2") { return 15 }
        if security.contains("WPA") { return 10 }
        return 0
    }
}
