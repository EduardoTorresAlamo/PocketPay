//
//  ScanQRView.swift
//  PRPay
//
//  Created by Eduardo Torres on 1/21/26.
//

import SwiftUI

struct ScanQRView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.black
                    .ignoresSafeArea()

                VStack(spacing: AppConstants.Spacing.extraLarge) {
                    Spacer()

                    // QR Scanner Frame
                    ZStack {
                        // Scanner frame overlay
                        RoundedRectangle(cornerRadius: AppConstants.CornerRadius.large)
                            .stroke(AppConstants.Colors.primaryPurple, lineWidth: 3)
                            .frame(width: 250, height: 250)

                        // Corners
                        VStack {
                            HStack {
                                ScannerCorner()
                                Spacer()
                                ScannerCorner()
                                    .rotation3DEffect(.degrees(90), axis: (x: 0, y: 0, z: 1))
                            }
                            Spacer()
                            HStack {
                                ScannerCorner()
                                    .rotation3DEffect(.degrees(-90), axis: (x: 0, y: 0, z: 1))
                                Spacer()
                                ScannerCorner()
                                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 0, z: 1))
                            }
                        }
                        .frame(width: 250, height: 250)
                    }

                    // Instructions
                    VStack(spacing: AppConstants.Spacing.small) {
                        Text("Scan QR Code")
                            .font(AppConstants.Typography.title2)
                            .foregroundColor(.white)
                            .bold()

                        Text("Align the QR code within the frame")
                            .font(AppConstants.Typography.body)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, AppConstants.Spacing.large)

                    Spacer()

                    // Coming Soon Badge
                    VStack(spacing: AppConstants.Spacing.small) {
                        Image(systemName: "hammer.fill")
                            .font(.system(size: 40))
                            .foregroundColor(AppConstants.Colors.primaryPurple)

                        Text("Feature Coming Soon")
                            .font(AppConstants.Typography.headline)
                            .foregroundColor(.white)

                        Text("QR code scanning functionality will be available in a future update")
                            .font(AppConstants.Typography.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppConstants.Spacing.extraLarge)
                    }
                    .padding(.bottom, AppConstants.Spacing.extraLarge)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
}

// MARK: - Scanner Corner

struct ScannerCorner: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(AppConstants.Colors.primaryPurple)
                .frame(width: 40, height: 4)

            Rectangle()
                .fill(AppConstants.Colors.primaryPurple)
                .frame(width: 4, height: 40)
        }
    }
}

// MARK: - Preview

#Preview {
    ScanQRView()
}
