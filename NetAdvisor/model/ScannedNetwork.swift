//
//  ScannedNetwork.swift
//  NetAdvisor
//
//  Created by Rama Krishna Konda on 16/12/25.
//

import Foundation
import CoreWLAN

public struct ScannedNetwork: Identifiable, Hashable, Equatable {
    public let id: String
    public let ssid: String
    public let rssi: Int
    public let channel: Int
    public let band: WiFiBand
    public let security: String
    public let isHidden: Bool

    public init(
        id: String,
        ssid: String,
        rssi: Int,
        channel: Int,
        band: WiFiBand,
        security: String,
        isHidden: Bool
    ) {
        self.id = id
        self.ssid = ssid
        self.rssi = rssi
        self.channel = channel
        self.band = band
        self.security = security
        self.isHidden = isHidden
    }

    public init(from cwNetwork: CWNetwork) {
        self.id = cwNetwork.bssid ?? UUID().uuidString
        self.ssid = cwNetwork.ssid ?? "Hidden"
        self.rssi = cwNetwork.rssiValue
        self.channel = cwNetwork.wlanChannel?.channelNumber ?? 0
        self.band = cwNetwork.wlanChannel?.channelBand == .band5GHz ? .fiveGHz : .twoPointFourGHz
        self.security = NetworkScanner.securityDescription(for: cwNetwork)
        self.isHidden = cwNetwork.ssid == nil
    }
    
    var details: String {
            let bandText = band == .fiveGHz ? "5 GHz" : "2.4 GHz"
            return "\(bandText) • Ch \(channel) • \(security)"
        }
    
    var signalBars: Int {
            switch rssi {
            case -50...0: return 4
            case -60..<(-50): return 3
            case -70..<(-60): return 2
            default: return 1
            }
        }
    
    func score(internetAvailable: Bool) -> Int {
            NetworkScoreCalculator.score(
                network: self,
                internetAvailable: internetAvailable
            )
        }

    func isRecommended(
            comparedTo others: [ScannedNetwork],
            internetAvailable: Bool
        ) -> Bool {
            let myScore = score(internetAvailable: internetAvailable)
            let bestOther = others
                .map { $0.score(internetAvailable: internetAvailable) }
                .max() ?? 0

            return myScore == bestOther
        }
}

public enum NetworkBand: Equatable {
    case twoPointFourGHz
    case fiveGHz
}
