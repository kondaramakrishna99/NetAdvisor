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
        List(viewModel.networks) { network in
            NetworkRow(network: network)
        }
        .listStyle(.inset)
    }
}

#Preview {
    ContentView()
}

struct NetworkRow: View {

    let network: ScannedNetwork

    var body: some View {
        HStack {

            // Signal Strength
            signalBars

            VStack(alignment: .leading, spacing: 4) {
                Text(network.ssid)
                    .font(.headline)

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
