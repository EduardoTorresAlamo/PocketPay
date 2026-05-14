//
//  ProfileView.swift
//  PRPay
//
//  Created by Eduardo Torres on 1/21/26.
//

import SwiftUI

struct ProfileView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var fullName = ""
    @State private var email = ""
    @State private var phoneNumber = ""
    @State private var mailingAddress = ""
    @State private var isEditing = false
    @State private var showingSaveSuccess = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    VStack(spacing: 16) {
                        // Avatar
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        AppConstants.Colors.primaryPurple,
                                        AppConstants.Colors.secondaryPurple
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)
                            .overlay(
                                Text(String(fullName.prefix(1).uppercased()))
                                    .font(.system(size: 40, weight: .bold))
                                    .foregroundColor(.white)
                            )
                            .shadow(color: AppConstants.Colors.primaryPurple.opacity(0.3), radius: 10, x: 0, y: 5)

                        Text(authManager.currentUser?.username ?? "")
                            .font(AppConstants.Typography.headline)
                            .foregroundColor(AppConstants.Colors.secondaryLabel)
                    }
                    .padding(.top, 24)

                    // Profile Information Form
                    VStack(spacing: 16) {
                        // Full Name
                        ProfileField(
                            label: "Full Name",
                            icon: "person.fill",
                            text: $fullName,
                            isEditing: isEditing
                        )

                        // Email
                        ProfileField(
                            label: "Email Address",
                            icon: "envelope.fill",
                            text: $email,
                            isEditing: isEditing,
                            keyboardType: .emailAddress
                        )

                        // Phone Number
                        ProfileField(
                            label: "Phone Number",
                            icon: "phone.fill",
                            text: $phoneNumber,
                            isEditing: isEditing,
                            keyboardType: .phonePad
                        )

                        // Mailing Address
                        ProfileField(
                            label: "Mailing Address",
                            icon: "house.fill",
                            text: $mailingAddress,
                            isEditing: isEditing,
                            isMultiline: true
                        )
                    }
                    .padding(.horizontal, 24)

                    // Action Buttons
                    VStack(spacing: 12) {
                        if isEditing {
                            // Save Button
                            Button(action: saveProfile) {
                                Text("Save Changes")
                                    .font(AppConstants.Typography.headline)
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(AppConstants.Colors.primaryPurple)
                                    .foregroundColor(.white)
                                    .cornerRadius(AppConstants.CornerRadius.medium)
                            }

                            // Cancel Button
                            Button(action: cancelEditing) {
                                Text("Cancel")
                                    .font(AppConstants.Typography.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(AppConstants.Colors.cardBackground)
                                    .foregroundColor(AppConstants.Colors.label)
                                    .cornerRadius(AppConstants.CornerRadius.medium)
                            }
                        } else {
                            // Edit Button
                            Button(action: { isEditing = true }) {
                                HStack {
                                    Image(systemName: "pencil")
                                    Text("Edit Profile")
                                }
                                .font(AppConstants.Typography.headline)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(AppConstants.Colors.primaryPurple)
                                .foregroundColor(.white)
                                .cornerRadius(AppConstants.CornerRadius.medium)
                            }
                        }

                        // Logout Button
                        Button(action: { authManager.logout() }) {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Logout")
                            }
                            .font(AppConstants.Typography.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppConstants.Colors.errorRed.opacity(0.1))
                            .foregroundColor(AppConstants.Colors.errorRed)
                            .cornerRadius(AppConstants.CornerRadius.medium)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                }
                .padding(.bottom, 24)
            }
            .background(AppConstants.Colors.background.ignoresSafeArea())
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .alert("Profile Updated", isPresented: $showingSaveSuccess) {
                Button("OK") {
                    showingSaveSuccess = false
                }
            } message: {
                Text("Your profile has been saved successfully")
            }
            .onAppear {
                loadProfile()
            }
        }
    }

    private func loadProfile() {
        if let user = authManager.currentUser {
            fullName = user.fullName
            email = user.email
            phoneNumber = user.phoneNumber
            mailingAddress = user.mailingAddress
        }
    }

    private func saveProfile() {
        guard var user = authManager.currentUser else { return }

        user.fullName = fullName
        user.email = email
        user.phoneNumber = phoneNumber
        user.mailingAddress = mailingAddress

        // Save to UserDefaults
        user.save()

        // Update in AuthManager
        authManager.currentUser = user

        isEditing = false
        showingSaveSuccess = true
    }

    private func cancelEditing() {
        loadProfile()
        isEditing = false
    }
}

// MARK: - Profile Field

struct ProfileField: View {
    let label: String
    let icon: String
    @Binding var text: String
    let isEditing: Bool
    var keyboardType: UIKeyboardType = .default
    var isMultiline: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(AppConstants.Typography.caption)
                .foregroundColor(AppConstants.Colors.secondaryLabel)
                .textCase(.uppercase)

            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(AppConstants.Colors.primaryPurple)
                    .frame(width: 24)

                if isEditing {
                    if isMultiline {
                        TextField("", text: $text, axis: .vertical)
                            .lineLimit(3...6)
                            .font(AppConstants.Typography.body)
                            .foregroundColor(AppConstants.Colors.label)
                            .keyboardType(keyboardType)
                            .textInputAutocapitalization(.sentences)
                    } else {
                        TextField("", text: $text)
                            .font(AppConstants.Typography.body)
                            .foregroundColor(AppConstants.Colors.label)
                            .keyboardType(keyboardType)
                            .textInputAutocapitalization(keyboardType == .emailAddress ? .never : .words)
                    }
                } else {
                    Text(text.isEmpty ? "Not set" : text)
                        .font(AppConstants.Typography.body)
                        .foregroundColor(text.isEmpty ? AppConstants.Colors.tertiaryLabel : AppConstants.Colors.label)
                }

                Spacer()
            }
            .padding()
            .background(isEditing ? AppConstants.Colors.cardBackground : AppConstants.Colors.cardBackground.opacity(0.5))
            .cornerRadius(AppConstants.CornerRadius.medium)
        }
    }
}

// MARK: - Preview

#Preview {
    ProfileView()
}
