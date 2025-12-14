//
//  ContentView.swift
//  NetAdvisor
//
//  Created by Rama Krishna Konda on 14/12/25.
//

import SwiftUI
import CoreWLAN

@available(macOS 10.15, *)
struct ContentView: View {

    // MARK: - State

    @State private var networks: [CWNetwork] = []
    @State private var statusMessage: String = "Ready"
    @State private var isScanning: Bool = false

    private let scanner = NetworkScanner()

    // MARK: - View

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            headerView

            Divider()

            if isScanning {
                ProgressView("Scanning Wi-Fi networks…")
            } else if networks.isEmpty {
                Text(statusMessage)
                    .foregroundColor(.secondary)
            } else {
                networkListView
            }

            Spacer()

            Divider()

            footerView
        }
        .padding()
        .frame(minWidth: 650, minHeight: 450)
        .onAppear {
            scanNetworks()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Text("NetAdvisor – Available Wi-Fi Networks")
                .font(.headline)

            Spacer()

            Button(action: scanNetworks) {
                Label("Rescan", systemImage: "arrow.clockwise")
            }
            .disabled(isScanning)
        }
    }

    // MARK: - Network List

    private var networkListView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(networks.indices, id: \.self) { index in
                    NetworkRow(
                        index: index + 1,
                        network: networks[index]
                    )
                    Divider()
                }
            }
        }
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            Text("Found \(networks.count) network(s)")
                .font(.footnote)
                .foregroundColor(.secondary)

            Spacer()

            if let current = scanner.getCurrentNetwork() {
                Text("Connected: \(current.ssid)")
                    .font(.footnote)
            }
        }
    }

    // MARK: - Actions

    private func scanNetworks() {
        isScanning = true
        statusMessage = "Scanning…"
        networks = []

        scanner.scanForNetworks { scanned in
            DispatchQueue.main.async {
                self.networks = scanned
                self.isScanning = false
                self.statusMessage = scanned.isEmpty
                    ? "No Wi-Fi networks found or permission denied."
                    : "Scan complete"
            }
        }
    }
}

@available(macOS 10.15, *)
private struct NetworkRow: View {

    let index: Int
    let network: CWNetwork

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(index). \(network.ssid ?? "Hidden Network")")
                    .font(.system(.body, design: .monospaced))

                if network.ssid == nil {
                    Text("(Hidden)")
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("\(network.rssiValue) dBm")
                    .foregroundColor(signalColor)
            }

            HStack(spacing: 16) {
                Text("Channel: \(network.wlanChannel?.channelNumber ?? 0)")
                Text("Band: \(bandDescription)")
                Text("Security: \(securityDescription)")
            }
            .font(.footnote)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var bandDescription: String {
        network.wlanChannel?.channelBand == .band5GHz ? "5 GHz" : "2.4 GHz"
    }

    private var securityDescription: String {
        if network.supportsSecurity(.wpa3Personal) { return "WPA3" }
        if network.supportsSecurity(.wpa2Personal) { return "WPA2" }
        if network.supportsSecurity(.wpaPersonal) { return "WPA" }
        return "Open"
    }

    private var signalColor: Color {
        switch network.rssiValue {
        case -50...0: return .green
        case -65..<(-50): return .yellow
        case -75..<(-65): return .orange
        default: return .red
        }
    }
}
