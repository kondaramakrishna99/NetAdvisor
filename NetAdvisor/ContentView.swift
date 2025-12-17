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

    // MARK: - ViewModel

    @StateObject private var viewModel = NetworkViewModel()

    // MARK: - Body

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {

                // MARK: - Status Bar
                statusSection

                // MARK: - Scan Button
                scanButton

                // MARK: - Network List
                networkList
            }.onDisappear {
                viewModel.stop()
            }
            .padding()
            .navigationTitle("NetAdvisor")
        }
    }

    // MARK: - Status Section

    private var statusSection: some View {
        VStack(spacing: 8) {
            statusRow(
                title: "Internet",
                isHealthy: viewModel.isInternetAvailable
            )

            statusRow(
                title: "Wi-Fi Path",
                isHealthy: viewModel.isWiFiPathHealthy
            )
        }
        .padding()
        .background(Color(.windowBackgroundColor))
        .cornerRadius(12)
    }

    private func statusRow(title: String, isHealthy: Bool) -> some View {
        HStack {
            Text(title)
                .font(.headline)

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(isHealthy ? Color.green : Color.red)
                    .frame(width: 10, height: 10)

                Text(isHealthy ? "Healthy" : "Unhealthy")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Scan Button

    private var scanButton: some View {
        Button(action: {
            viewModel.scanOnce()
        }) {
            HStack {
                if viewModel.isScanning {
                    ProgressView()
                        .scaleEffect(0.7)
                }

                Text(viewModel.isScanning ? "Scanning..." : "Scan Now")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(viewModel.isScanning)
    }

    // MARK: - Network List

    private var networkList: some View {
        List {
            ForEach(Array(viewModel.networks.enumerated()), id: \.element.id) { index, network in
                NetworkRow(
                    network: network,
                    isBest: network.id == viewModel.bestNetworkID,
                    isCurrent: network.id == viewModel.currentNetworkID
                )
            }
        }
        .listStyle(.inset)
    }
}

#Preview {
    ContentView()
}

struct NetworkRow: View {

    let network: ScannedNetwork
    let isBest: Bool
    let isCurrent: Bool
    
    var body: some View {
            HStack {

                signalBars

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(network.ssid)
                            .font(.headline)

                        if isBest {
                            badge(text: "BEST", color: .green)
                        }
                        
                        if isCurrent {
                               badge(text: "CURRENT", color: .blue)
                           }
                    }

                    Text(network.details)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("\(network.rssi) dBm")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    
    private func badge(text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(6)
    }
    
    private var signalBars: some View {
        let bars = network.signalBars   // 👈 reduce inference

        return HStack(spacing: 2) {
            ForEach(0..<bars, id: \.self) { index in
                let barHeight = CGFloat(6 + index * 4)
                let barColor: Color = .green

                Rectangle()
                    .fill(barColor)
                    .frame(width: 4, height: barHeight)
            }
        }
        .frame(width: 24)
    }
}
