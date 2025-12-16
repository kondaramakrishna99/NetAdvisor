import Foundation
import CoreWLAN
import CoreLocation

@available(macOS 10.15, *)
public final class NetworkScanner: NSObject, CLLocationManagerDelegate {

    // MARK: - Core Properties
    private let wifiClient = CWWiFiClient.shared()
    private let locationManager = CLLocationManager()
    private var interface: CWInterface?

    private var pendingScanCompletion: (([CWNetwork]) -> Void)?

    // MARK: - Init
    public override init() {
        super.init()
        print("=== NetAdvisor NetworkScanner Initialized ===")
        self.interface = wifiClient.interface()
        self.locationManager.delegate = self
    }

    // MARK: - Public API

    /// Asynchronously scans for available Wi‑Fi networks.
    /// - Parameter completion: Returns sorted CWNetwork list (strongest first)
    public func scanForNetworks(completion: @escaping ([CWNetwork]) -> Void) {
        guard interface != nil else {
            print("❌ No Wi‑Fi interface available")
            completion([])
            return
        }

        let status: CLAuthorizationStatus
        if #available(macOS 11.0, *) {
            status = locationManager.authorizationStatus
        } else {
            status = CLLocationManager.authorizationStatus()
        }

        switch status {
        case .notDetermined:
            print("🔒 Requesting location permission to scan Wi-Fi networks...")
            pendingScanCompletion = completion
            locationManager.requestWhenInUseAuthorization()

        case .authorized, .authorizedAlways:
            performNetworkScan(completion: completion)

        case .denied, .restricted:
            print("❌ Location permission denied – cannot scan Wi‑Fi")
            completion([])

        @unknown default:
            print("❌ Unknown location authorization status")
            completion([])
        }
    }

    /// Returns information about the currently connected network
    public func getCurrentNetwork() -> CurrentNetwork? {
        guard let interface = interface,
              let ssid = interface.ssid() else {
            return nil
        }

        return CurrentNetwork(
            ssid: ssid,
            bssid: interface.bssid() ?? "Unknown",
            rssi: interface.rssiValue(),
            noise: interface.noiseMeasurement(),
            channel: interface.wlanChannel()?.channelNumber ?? 0,
            band: interface.wlanChannel()?.channelBand == .band5GHz ? .fiveGHz : .twoPointFourGHz,
            security: interface.security()
        )
    }

    // MARK: - Core Scan Logic
    private func performNetworkScan(completion: @escaping ([CWNetwork]) -> Void) {
        guard let interface = interface, interface.powerOn() else {
            print("❌ Wi‑Fi is turned off or interface unavailable")
            completion([])
            return
        }

        do {
            print("🔍 NetAdvisor scanning Wi‑Fi networks...")
            let networks = try interface.scanForNetworks(withName: nil, includeHidden: true)
            let sortedNetworks = networks.sorted { $0.rssiValue > $1.rssiValue }
            completion(sortedNetworks)
        } catch {
            print("❌ Wi‑Fi scan failed: \(error.localizedDescription)")
            completion([])
        }
    }

    // MARK: - CLLocationManagerDelegate
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status: CLAuthorizationStatus
        if #available(macOS 11.0, *) {
            status = manager.authorizationStatus
        } else {
            status = CLLocationManager.authorizationStatus()
        }

        if let completion = pendingScanCompletion,
           status == .authorized || status.rawValue == 3 /* .authorizedAlways */ {
            print("✅ Location permission granted, resuming Wi-Fi scan...")
            performNetworkScan(completion: completion)
            pendingScanCompletion = nil
        } else if status == .denied || status == .restricted, let completion = pendingScanCompletion {
            print("❌ Location permission denied - cannot scan Wi-Fi networks")
            completion([])
            pendingScanCompletion = nil
        }
    }

    // MARK: - Helpers
    public static func securityDescription(for network: CWNetwork) -> String {
        if network.supportsSecurity(.wpa3Personal) { return "WPA3" }
        if network.supportsSecurity(.wpa3Enterprise) { return "WPA3 Enterprise" }
        if network.supportsSecurity(.wpa2Personal) { return "WPA2" }
        if network.supportsSecurity(.wpa2Enterprise) { return "WPA2 Enterprise" }
        if network.supportsSecurity(.wpaPersonal) { return "WPA" }
        if network.supportsSecurity(.wpaEnterprise) { return "WPA Enterprise" }
        if network.supportsSecurity(.WEP) { return "WEP" }
        return "Open"
    }

    public func formatNetworks(_ networks: [CWNetwork]) -> String {
        guard !networks.isEmpty else { return "No networks found" }

        var result = "Available Networks (\(networks.count) found):\n"
        result += "--------------------------------------------------\n"

        for (index, network) in networks.enumerated() {
            let ssid = network.ssid ?? "Hidden"
            let bssid = network.bssid ?? "Unknown"
            let band = network.wlanChannel?.channelBand == .band5GHz ? "5GHz" : "2.4GHz"

            result += "\n\(index + 1). \(ssid)"
            if network.ssid == nil { result += " (Hidden)" }
            result += "\n   BSSID: \(bssid)"
            result += "\n   Signal: \(network.rssiValue) dBm"
            result += "\n   Channel: \(network.wlanChannel?.channelNumber ?? 0) (\(band))"
            result += "\n   Security: \(NetworkScanner.securityDescription(for: network))"
            result += "\n   Signal Quality: \(signalQuality(network.rssiValue))/5"
            result += "\n"
        }

        return result
    }

    private func signalQuality(_ rssi: Int) -> Int {
        switch rssi {
        case -50...0: return 5
        case -60..<(-50): return 4
        case -70..<(-60): return 3
        case -80..<(-70): return 2
        default: return 1
        }
    }
    
    private func mapToDomain(_ network: CWNetwork) -> ScannedNetwork {
        let band: WiFiBand = network.wlanChannel?.channelBand == .band5GHz ? .fiveGHz : .twoPointFourGHz
        return ScannedNetwork(
            id: network.bssid ?? UUID().uuidString,
            ssid: network.ssid ?? "Hidden",
            rssi: network.rssiValue,
            channel: network.wlanChannel?.channelNumber ?? 0,
            band: band,
            security: NetworkScanner.securityDescription(for: network),
            isHidden: network.ssid == nil
        )
    }
}

// MARK: - Supporting Models
public struct CurrentNetwork {
    public let ssid: String
    public let bssid: String
    public let rssi: Int
    public let noise: Int
    public let channel: Int
    public let band: WiFiBand
    public let security: CWSecurity
}

public enum WiFiBand {
    case twoPointFourGHz
    case fiveGHz
}
