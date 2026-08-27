# 🛡️ POCKETPAY FULL CODEBASE AUDIT & TECHNICAL REVIEW

**Date:** August 26, 2026  
**Auditor:** Antigravity Senior Security & Software Architect  
**Repository:** `/Users/eduardotorres/Developer/XCodes/PocketPay`  
**Scope:** 100% of Swift Source Code (`PocketPay/**/*.swift`, `PocketPayTests/**/*.swift`)  
**Assessment Vectors:** Security, Code Quality & Bugs, Architecture & State Management, Performance & Resource Utilization  
**Severity Scale:** 🔴 **CRITICAL** | 🟠 **HIGH** | 🟡 **MEDIUM** | 🟢 **LOW**  

---

## Executive Summary & Production Readiness Verdict

> ### 🛑 Production Verdict: NOT PRODUCTION READY (UNSAFE)
>
> PocketPay has undergone significant improvements since initial milestones (e.g. Keychain persistence for user models and payment methods, race condition deduplication via `PaymentManager.processCharge`, and bounds checks in card carousels). 
>
> However, **3 CRITICAL vulnerabilities**, **5 HIGH severity flaws**, **5 MEDIUM issues**, and **4 LOW issues** remain in the active codebase. Most notably:
> 1. **International Keypad Breakdown (Locale Lock)**: The custom numeric keypad splits amounts on decimal dots (`"."`), rendering amount entry completely inoperable in European, Latin American, and international locales using comma decimal separators (`,`).
> 2. **Mock Authentication & Hardcoded Credentials**: Authentication accepts hardcoded credentials (`demo`/`password`) and issues self-proclaimed client-side session tokens without cryptographic server validation.
> 3. **Unbound Biometrics**: LocalAuthentication challenges operate detached from Keychain Secure Enclave access control (`SecAccessControl`), enabling runtime bypasses on jailbroken devices.
> 4. **Orphaned Primary Navigation**: `ServicesView` (Bills & Subscriptions) and `HistoryView` (Transaction History & Category Filtering) are completely absent from `MainTabView` and unreachable via primary application flows.
> 5. **$O(N^2)$ Main Thread List Stutter**: `HistoryView.body` repeatedly computes dictionary grouping and sorting on every frame render and row iteration.

---

## 📊 Summary Matrix of Findings

| Assessment Domain | 🔴 CRITICAL | 🟠 HIGH | 🟡 MEDIUM | 🟢 LOW | Total |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **1. Security & Authentication** | 2 | 1 | 2 | 0 | **5** |
| **2. Code Quality & Business Logic** | 1 | 2 | 2 | 2 | **7** |
| **3. Architecture & Reactivity** | 0 | 2 | 1 | 1 | **4** |
| **4. Performance & Memory** | 0 | 1 | 1 | 1 | **3** |
| **TOTAL** | **3** | **6** | **6** | **4** | **19** |

---

## 🚨 Detailed Findings by Domain

### 1. 🔐 Security & Authentication

#### 🔴 SEC-01 (CRITICAL): Mock Authentication and Hardcoded Demo Credentials in Client Binary
* **Location:** [`AuthManager.swift:L64-L78`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/Core/AuthManager.swift#L64-L78), [`LoginView.swift:L128-L138`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/View/LoginView.swift#L128-L138)
* **Mechanics:**
  ```swift
  // AuthManager.swift
  if username.lowercased() == "demo" && password == "password" {
      var user = userRepository.load() ?? User.mockUser
      user.username = username
      currentUser = user
      isAuthenticated = true
      errorMessage = nil
      userRepository.save(user)
      return true
  }
  ```
  `AuthManager.login` evaluates credentials against static in-memory strings (`"demo"` / `"password"`). The credentials are also explicitly rendered on the login screen (`LoginView`).
* **Exploitability & Impact:** Anyone with access to the client binary or compiled app can authenticate as any user without backend credentials, session token verification, or password hashing (Argon2id/PBKDF2/bcrypt).
* **Remediation:** Replace mock auth with OAuth2/PKCE or JWT token authentication against a secure backend (e.g. Supabase Auth / custom auth server). Store the issued refresh token in Keychain with biometric access control.

---

#### 🔴 SEC-02 (CRITICAL): Client-Side Payment Simulation & Missing Server-Side Payment Orchestration
* **Location:** [`StripeManager.swift:L89-L100`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/Core/StripeManager.swift#L89-L100), [`APIKeys.swift:L15-L26`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/Config/APIKeys.swift#L15-L26)
* **Mechanics:**
  ```swift
  func processPayment(amount: Double) async -> Bool {
      if APIKeys.useMockPayments {
          return await mockProcessPayment(amount: amount)
      }
      return false
  }
  ```
  Payment authorization is simulated via `RandomPaymentOutcome` with a 2-second sleep. When mock mode is disabled, the method unconditionally fails (`return false`).
* **Exploitability & Impact:** Real payments cannot settle. If the app were released with client-side flags, transactions and balances would update locally without real money transfer or Stripe ledger confirmation.
* **Remediation:** Integrate Stripe SDK via Swift Package Manager (`StripePaymentSheet`). Implement server-side PaymentIntent creation (e.g., Supabase Edge Function) and pass the `client_secret` to the iOS client.

---

#### 🟠 SEC-03 (HIGH): Biometric Authentication Decoupled from Keychain Secure Enclave Access Control
* **Location:** [`AuthManager.swift:L89-L133, L188-L200`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/Core/AuthManager.swift#L89-L133), [`KeychainManager.swift:L48-L60`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/Core/KeychainManager.swift#L48-L60)
* **Mechanics:**
  Biometric login calls `LAContext().evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics)`. On success, it calls `userRepository.load()`. However, the Keychain item is saved with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` instead of requiring biometric access control (`SecAccessControlCreateWithFlags` with `.biometryCurrentSet`).
  Although `AuthManager.biometryAccessControl()` is declared (L188-L200), it is a private unused helper.
* **Exploitability & Impact:** On jailbroken or compromised devices, runtime instrumentation (e.g. Frida or Cycript hooking `LAContext evaluatePolicy`) can force biometric evaluation to return `true`, granting immediate access to the stored user profile.
* **Remediation:** Bind the authentication token in Keychain using `SecAccessControl` with `.biometryCurrentSet` and `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly`. Reading the item will then cryptographically require a valid hardware biometric assertion.

---

#### 🟡 SEC-04 (MEDIUM): Exposure of Financial Notes and Payee Data in System EventKit Calendars
* **Location:** [`CalendarManager.swift:L95-L98`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/Core/CalendarManager.swift#L95-L98)
* **Mechanics:**
  `CalendarManager` writes `event.title = "Pay \(billerName)"` and `event.notes = notes` into the user's default system calendar.
* **Exploitability & Impact:** System calendars are regularly synchronized across external services (Google, Exchange, iCloud) and accessible by any third-party app with calendar permissions. Unsanitized transaction memos may leak financial relationships or PII.
* **Remediation:** Redact sensitive memo details or offer an explicit user opt-in before attaching custom notes to system calendar events.

---

#### 🟡 SEC-05 (MEDIUM): Silent Mock Data Fallback on Keychain Storage Errors
* **Location:** [`PaymentManager.swift:L60-L64`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/Core/PaymentManager.swift#L60-L64), [`PaymentMethodRepository.swift:L34-L37`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/Core/PaymentMethodRepository.swift#L34-L37), [`ServicesViewModel.swift:L88-L98`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/ViewModel/ServicesViewModel.swift#L88-L98)
* **Mechanics:**
  When `KeychainManager.load` returns `nil` (which occurs on clean install OR if the device is locked/keychain access fails), repositories fall back silently to `mockTransactions`, `mockPaymentMethods`, and `mockRecurringPayments`.
* **Exploitability & Impact:** Transient Keychain failures due to device lock or OS errors can cause the app to display demo data to legitimate users, causing confusion regarding real financial records.
* **Remediation:** Distinguish between "first launch (no record exists)" and "Keychain read failure (OSStatus error)", surfacing an error to the user rather than silently swapping real data for mock data.

---

### 2. 🐛 Code Quality & Business Logic

#### 🔴 BUG-01 (CRITICAL): International Locale Decimal Keypad Freeze
* **Location:** [`TransferViewModel.swift:L115-L134, L144-L165`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/ViewModel/TransferViewModel.swift#L115-L134), [`CurrencyFormatter.swift:L28-L30`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/Utility/CurrencyFormatter.swift#L28-L30)
* **Mechanics:**
  ```swift
  // CurrencyFormatter.swift
  static func plain(_ amount: Double) -> String {
      return String(format: "%.2f", amount) // Uses device locale!
  }

  // TransferViewModel.swift
  func appendDigit(_ digit: String) {
      let currentAmountString = CurrencyFormatter.plain(amount)
      let components = currentAmountString.split(separator: ".")
      if components.count == 2 { ... } // Fails in comma locales!
  }
  ```
  `String(format: "%.2f", amount)` formats using the device's current locale. In Spanish, German, French, or Italian locales, 1.50 is formatted as `"1,50"`. Splitting by `"."` produces `["1,50"]` (count = 1). `components.count == 2` evaluates to `false`.
* **Impact:** On any iOS device configured with a comma-decimal locale, tapping numbers on the custom keypad has zero effect. The P2P transfer keypad is completely frozen.
* **Remediation:** Replace string splitting with an integer cents model (`amountInCents: Int`):
  ```swift
  @Published var amountInCents: Int = 0
  var amount: Double { Double(amountInCents) / 100.0 }

  func appendDigit(_ digit: Int) {
      guard amountInCents < 100_000_00 else { return } // $100k cap
      amountInCents = amountInCents * 10 + digit
  }

  func deleteLastDigit() {
      amountInCents /= 10
  }
  ```

---

#### 🟠 BUG-02 (HIGH): IEEE 754 Floating-Point Precision in Financial Calculations
* **Location:** [`PaymentManager.swift:L156-L178`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/Core/PaymentManager.swift#L156-L178), [`AuthManager.swift:L154-L159`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/Core/AuthManager.swift#L154-L159), [`User.swift:L20`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/Model/User.swift#L20), [`Transaction.swift:L101`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/Model/Transaction.swift#L101), [`ServicesViewModel.swift:L249-L265`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/ViewModel/ServicesViewModel.swift#L249-L265)
* **Mechanics:**
  Balances, payment deductions (`user.balance += delta`), and recurring aggregations use standard 64-bit floating-point `Double`. 
* **Impact:** Inherent binary representation limits (`0.1 + 0.2 = 0.30000000000000004`) lead to accumulated precision loss, fractional cent discrepancies, and balance comparison failures in accounting workflows.
* **Remediation:** Migrate domain models and financial operations to `Decimal` or `Int64` minor currency units (cents).

---

#### 🟠 BUG-03 (HIGH): Calendar Error Masked by Payment Success Alert
* **Location:** [`ServicesViewModel.swift:L173-L197`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/ViewModel/ServicesViewModel.swift#L173-L197)
* **Mechanics:**
  In `payOneTimeBill()`, if calendar creation fails, `errorMessage` is set to `"Payment created but calendar event failed..."`. However, because the payment charge itself succeeded (`success == true`), the method sets `showingSuccess = true` and calls `resetForm()`.
* **Impact:** The view triggers `.alert("Payment Successful")`, which suppresses and overwrites the calendar permission failure. The user believes their calendar reminder was set when it was silently dropped.
* **Remediation:** Maintain distinct state flags (`showingSuccess`, `showingWarningMessage`, `calendarWarning`) so calendar errors are surfaced even when payment completes.

---

#### 🟡 BUG-04 (MEDIUM): Inconsistent App Name Branding Across UI and Constants
* **Location:** [`Constants.swift:L96`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/Config/Constants.swift#L96), [`LoginView.swift:L43, L49`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/View/LoginView.swift#L43), [`WalletView.swift:L216`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/View/WalletView.swift#L216), [`StripeManager.swift:L3`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/Core/StripeManager.swift#L3)
* **Mechanics:**
  `AppConstants.AppInfo.name` is defined as `"PRPay"`. `LoginView` displays `"PR"` and `"PRPay"`. `WalletView` displays `"Add a payment method to start using PRPay"`.
* **Impact:** Brand confusion where the app identity oscillates between PRPay and PocketPay.
* **Remediation:** Standardize all branding constants and user strings to `PocketPay`.

---

#### 🟡 BUG-05 (MEDIUM): SwiftUI `.alert` with `.constant(...)` Binding Anti-Pattern
* **Location:** [`ServicesView.swift:L86`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/View/ServicesView.swift#L86), [`AddPaymentView.swift:L129`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/View/AddPaymentView.swift#L129)
* **Mechanics:**
  ```swift
  .alert("Payment Failed", isPresented: .constant(viewModel.errorMessage != nil)) {
      Button("OK") { viewModel.errorMessage = nil }
  }
  ```
  Passing `.constant` to `isPresented` violates SwiftUI two-way binding conventions.
* **Impact:** Causes runtime warnings in Xcode console and can result in alert dismissal glitches when dismissed via system gestures.
* **Remediation:** Use a computed `Binding<Bool>` or a `@Published var showError: Bool` on the ViewModel.

---

#### 🟢 BUG-06 (LOW): Dead State & Unobserved Variables
* **Location:** [`LoginView.swift:L25, L156`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/View/LoginView.swift#L25), [`AddCardView.swift:L43-L44`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/View/AddCardView.swift#L43-L44), [`HomeView.swift:L18`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/View/HomeView.swift#L18), [`HomeViewModel.swift:L29-L31`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/ViewModel/HomeViewModel.swift#L29-L31)
* **Mechanics:**
  - `LoginView.showError` is assigned but never observed.
  - `AddCardView.showingError` and `errorMessage` are never set or triggered.
  - `HomeView.authManager` is instantiated as `@StateObject` but unused.
  - `HomeViewModel.showingTransferView`, `showingHistoryView`, `showingScanQRView` are shadowed by local `@State` in `HomeView`.
* **Impact:** Unnecessary memory overhead and developer confusion.
* **Remediation:** Remove unused properties and consolidate sheet presentation state in ViewModels.

---

#### 🟢 BUG-07 (LOW): Deprecated View Modifiers in iOS 17+
* **Location:** [`LoginView.swift:L197, L198, L224, L225`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/View/LoginView.swift#L197), [`AddPaymentView.swift:L28`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/View/AddPaymentView.swift#L28)
* **Mechanics:**
  - `.autocapitalization(...)` (Deprecated -> `.textInputAutocapitalization(...)`)
  - `.disableAutocorrection(true)` (Deprecated -> `.autocorrectionDisabled()`)
* **Impact:** Generates compiler warnings on modern Xcode builds.
* **Remediation:** Update to modern iOS 17+ modifier syntax.

---

### 3. 🏗️ Architecture & State Management

#### 🟠 ARC-01 (HIGH): Orphaned Views and Disconnected Navigation Hierarchy
* **Location:** [`MainTabView.swift:L20-L44`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/View/MainTabView.swift#L20-L44), [`HomeView.swift:L62-L83, L108-L122`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/View/HomeView.swift#L62-L83)
* **Mechanics:**
  - `MainTabView` defines only 3 tabs: **Home (0)**, **Wallet (1)**, and **Profile (2)**.
  - `ServicesView` (`Services & Bills` tab with full subscription manager, due-soon tracking, monthly cost breakdown, and calendar sync) is **completely omitted from `MainTabView`**.
  - In `HomeView`, the "Pay Bill" button opens `AddPaymentView` directly, bypassing `ServicesView` entirely.
  - `HistoryView` (`Transaction History` with date grouping, search, and category chips) is **omitted from `MainTabView`** and has no "See All" button or row navigation from `HomeView`.
  - `ScanQRView` is orphaned with no trigger button.
* **Impact:** Critical user-facing features (`ServicesView`, `HistoryView`, `TransactionDetailView`, `ScanQRView`) are completely inaccessible in the running application.
* **Remediation:** Expand `MainTabView` to 4 or 5 tabs (e.g. Home, Services, Wallet, History, Profile) or add direct navigation links from `HomeView`'s Recent Transactions header.

---

#### 🟠 ARC-02 (HIGH): Non-Reactive Snapshot Polling in ViewModels
* **Location:** [`HomeViewModel.swift:L40-L53`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/ViewModel/HomeViewModel.swift#L40-L53), [`HomeView.swift:L133-L135`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/View/HomeView.swift#L133-L135)
* **Mechanics:**
  `HomeViewModel` reads snapshots of `currentUser` and `recentTransactions` inside `init()` and relies exclusively on `HomeView.onAppear { viewModel.loadData() }`. It does not subscribe via Combine publishers to `AuthManager` or `PaymentManager`.
* **Impact:** In multi-window iPadOS setups or when transfers complete in background sheets without re-triggering `onAppear`, home screen balance and transactions display stale data.
* **Remediation:** Bind `HomeViewModel` properties to `AuthManager` and `PaymentManager` using Combine `$currentUser` / `$transactions` pipelines or the Swift Observation framework (`@Observable`).

---

#### 🟡 ARC-03 (MEDIUM): `@StateObject` Instantiation with Global Singletons
* **Location:** [`WalletView.swift:L17`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/View/WalletView.swift#L17), [`HistoryView.swift:L16`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/View/HistoryView.swift#L16), [`HomeView.swift:L18`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/View/HomeView.swift#L18)
* **Mechanics:**
  `@StateObject private var viewModel = WalletViewModel.shared` initializes a `@StateObject` with a global singleton.
* **Impact:** In SwiftUI, `@StateObject` manages object lifecycle ownership. Passing a global singleton breaks view testing isolation, SwiftUI preview mocking, and declarative view graph lifecycles.
* **Remediation:** Use `@ObservedObject` for singleton references, or inject dependencies via `@EnvironmentObject` or constructor parameters.

---

#### 🟢 ARC-04 (LOW): Unused Root Dependency Declarations in `PocketPayApp`
* **Location:** [`PocketPayApp.swift:L21-L33`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/App/PocketPayApp.swift#L21-L33)
* **Mechanics:**
  `PocketPayApp` declares `@StateObject private var paymentManager = PaymentManager.shared` but never passes it down into the SwiftUI hierarchy via `.environmentObject()`.
* **Impact:** Misleading documentation and redundant state registration at app root.
* **Remediation:** Either provide `.environmentObject(paymentManager)` or remove the unreferenced `@StateObject`.

---

### 4. ⚡ Performance & Memory

#### 🟠 PRF-01 (HIGH): $O(N^2)$ Redundant Grouping and Sorting in `HistoryView.body`
* **Location:** [`HistoryView.swift:L94-L106, L140-L144`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/View/HistoryView.swift#L94-L106)
* **Mechanics:**
  ```swift
  private var groupedTransactions: [Date: [Transaction]] {
      Dictionary(grouping: filteredTransactions) { transaction in
          Calendar.current.startOfDay(for: transaction.date)
      }
  }

  // Inside body:
  ForEach(groupedTransactions.keys.sorted(by: >), id: \.self) { date in
      Section {
          ForEach(groupedTransactions[date] ?? []) { transaction in
              ...
              if transaction.id != groupedTransactions[date]?.last?.id { ... }
          }
      }
  }
  ```
  `groupedTransactions` is a computed property. Evaluating `body` calls the getter repeatedly:
  1. Once for `groupedTransactions.keys.sorted(by: >)` ($O(N \log N)$).
  2. Once per section for `groupedTransactions[date]` ($K \times O(N)$).
  3. Once per row for `groupedTransactions[date]?.last?.id` ($N \times O(N)$).
* **Impact:** For a ledger of 100 transactions across 10 dates, rendering `body` executes over 100 redundant dictionary groupings and allocations on the Main Thread during scrolling, causing severe UI stuttering and frame drops.
* **Remediation:** Move grouping logic into a ViewModel and cache the grouped structure:
  ```swift
  struct DateGroupedTransactions: Identifiable {
      let id: Date
      let transactions: [Transaction]
  }
  @Published var sections: [DateGroupedTransactions] = []
  ```

---

#### 🟡 PRF-02 (MEDIUM): Dynamic `DateFormatter` Allocations in Views & Models
* **Location:** [`RecurringPayment.swift:L128-L132`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/Model/RecurringPayment.swift#L128-L132), [`HistoryView.swift:L157-L160`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/View/HistoryView.swift#L157-L160)
* **Mechanics:**
  `RecurringPayment.formattedNextPaymentDate` and `HistoryView.formatSectionDate` instantiate a new `DateFormatter()` on every single cell access and header rendering.
* **Impact:** `DateFormatter` initialization involves expensive locale and timezone parsing. Doing this dynamically in list rows causes noticeable main thread latency.
* **Remediation:** Make formatters `static let` constants, or use iOS 15+ formatted date styles (`date.formatted(date: .abbreviated, time: .omitted)`).

---

#### 🟢 PRF-03 (LOW): Redundant MainActor Dispatches
* **Location:** [`LoginView.swift:L153, L170`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/View/LoginView.swift#L153), [`StripeManager.swift:L107, L118`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/Core/StripeManager.swift#L107)
* **Mechanics:**
  Tasks started inside SwiftUI views already inherit `@MainActor` context. Calling `await MainActor.run { ... }` inside these tasks is redundant.
* **Impact:** Micro-overhead of task hops.
* **Remediation:** Remove superfluous `MainActor.run` blocks in view-attached tasks.

---

## 🛠️ Prioritized Action Plan

| Priority | ID | Title | Target File | Severity |
| :---: | :--- | :--- | :--- | :---: |
| **P0** | **BUG-01** | Fix International Locale Decimal Keypad Freeze | [`TransferViewModel.swift`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/ViewModel/TransferViewModel.swift) | 🔴 CRITICAL |
| **P0** | **SEC-01** | Replace Mock Credentials with Backend JWT Auth | [`AuthManager.swift`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/Core/AuthManager.swift) | 🔴 CRITICAL |
| **P0** | **SEC-02** | Implement Server-Side Stripe PaymentSheet | [`StripeManager.swift`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/Core/StripeManager.swift) | 🔴 CRITICAL |
| **P1** | **ARC-01** | Connect `ServicesView` and `HistoryView` to `MainTabView` | [`MainTabView.swift`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/View/MainTabView.swift) | 🟠 HIGH |
| **P1** | **SEC-03** | Bind Biometrics to Keychain `SecAccessControl` | [`AuthManager.swift`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/Core/AuthManager.swift) | 🟠 HIGH |
| **P1** | **PRF-01** | Cache Grouped Transactions in History ViewModel | [`HistoryView.swift`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/View/HistoryView.swift) | 🟠 HIGH |
| **P1** | **ARC-02** | Bind `HomeViewModel` via Combine Publishers | [`HomeViewModel.swift`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/ViewModel/HomeViewModel.swift) | 🟠 HIGH |
| **P1** | **BUG-03** | Fix Calendar Error Alert Masking in Services | [`ServicesViewModel.swift`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/ViewModel/ServicesViewModel.swift) | 🟠 HIGH |
| **P2** | **BUG-02** | Refactor Floating-Point Balances to Integer Cents | Global (`User`, `Transaction`, `PaymentManager`) | 🟠 HIGH |
| **P2** | **PRF-02** | Convert `DateFormatter` to Static Singletons | [`RecurringPayment.swift`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/Model/RecurringPayment.swift) | 🟡 MEDIUM |
| **P2** | **BUG-04** | Fix PRPay Branding Inconsistencies | [`Constants.swift`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/Config/Constants.swift), [`LoginView.swift`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/View/LoginView.swift) | 🟡 MEDIUM |
| **P2** | **BUG-05** | Eliminate `.constant` SwiftUI Alert Bindings | [`ServicesView.swift`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/View/ServicesView.swift) | 🟡 MEDIUM |
| **P3** | **BUG-06** | Remove Dead State and Unused `@StateObject` | Views (`LoginView`, `AddCardView`, `HomeView`) | 🟢 LOW |
| **P3** | **BUG-07** | Modernize Deprecated Text Modifiers for iOS 17+ | [`LoginView.swift`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/View/LoginView.swift) | 🟢 LOW |
