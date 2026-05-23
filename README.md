# PocketPay

iOS P2P mobile payments app built with SwiftUI. Supports biometric authentication, a custom numeric keypad for transfers, transaction history with filters, and Stripe payment processing. Mock mode is on by default — no Stripe account needed to run the app.

Targets iOS 17+.

---

## ⚠️ Production Setup

By default the app runs in **mock mode** — no real payments occur. To process live transactions:

- Payment intents must be created on a **backend server** (never in client code). The secret key (`sk_test_...`) must never ship in the iOS binary.
- Add your Stripe publishable key to `PocketPay/Config/APIKeys.swift`.
- Point `APIKeys.backendURL` at your server endpoint.
- Set `APIKeys.useMockPayments = false`.

For development and evaluation, mock mode is sufficient and recommended.

---

## Stack

- SwiftUI (iOS 17+)
- MVVM architecture
- LocalAuthentication (Face ID / Touch ID)
- Stripe iOS SDK (optional — mock mode available)
- SF Symbols, no third-party UI dependencies

---

## Features

- **Authentication** — login with username/password or biometrics. Face ID / Touch ID failures fall back to device passcode automatically via `LocalAuthentication`.
- **Home dashboard** — balance card with show/hide toggle, recent transactions
- **P2P transfer** — contact search, custom numeric keypad, optional transfer note
- **Transaction history** — full list, filterable by type (P2P, business, donation, transfer), grouped by date
- **Wallet** — payment method management
- **Mock data** — contacts, users, and transactions are all pre-seeded; no backend required

---

## Getting Started

### Prerequisites

- macOS 14.0+
- Xcode 15.0+
- iOS 17.0+ simulator or device

### Build

1. Clone the repo and open the project:

```bash
open PocketPay.xcodeproj
```

2. Select your development team in **Signing & Capabilities**.
3. Choose a simulator or connected device.
4. Press `Cmd+R`.

The app runs in mock mode by default. No additional configuration needed.

---

## Stripe Setup

### Mock mode (default)

`APIKeys.useMockPayments` is set to `true` in `PocketPay/Config/APIKeys.swift`. In this mode:

- No Stripe API calls are made
- Payments simulate a 90% success rate
- All transfer UI is fully exercisable

### Production mode

1. Create a Stripe account at https://stripe.com and get your publishable key from the dashboard.
2. In `PocketPay/Config/APIKeys.swift`, set your key:

```swift
static let stripePublishableKey = "pk_live_..."
static let useMockPayments = false
```

3. Do not set `stripeSecretKey` in the client. All payment intents must be created server-side; the field in `APIKeys.swift` is a placeholder left for reference.
4. Set `backendURL` to your server endpoint that creates payment intents.

---

## Project Layout

```
PocketPay/
├── App/
│   └── PRPayApp.swift          # App entry point
├── Config/
│   ├── APIKeys.swift           # Stripe keys and mock flag
│   └── Constants.swift         # Colors, spacing, app-wide constants
├── Model/
│   ├── User.swift
│   ├── Transaction.swift
│   ├── Contact.swift
│   ├── PaymentMethod.swift
│   └── RecurringPayment.swift
├── View/
│   ├── LoginView.swift
│   ├── HomeView.swift
│   ├── TransferView.swift
│   ├── HistoryView.swift
│   ├── WalletView.swift
│   ├── ProfileView.swift
│   ├── ServicesView.swift
│   ├── TransactionDetailView.swift
│   ├── AddCardView.swift
│   ├── AddPaymentView.swift
│   ├── MainTabView.swift
│   └── ScanQRView.swift
├── ViewModel/
│   ├── HomeViewModel.swift
│   ├── TransferViewModel.swift
│   ├── WalletViewModel.swift
│   └── ServicesViewModel.swift
└── Core/
    ├── AuthManager.swift        # Biometric + credential auth
    ├── PaymentManager.swift     # Transfer orchestration
    ├── StripeManager.swift      # Stripe / mock integration
    └── CalendarManager.swift
```

---

## License

MIT
