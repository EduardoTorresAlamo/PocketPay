# 📋 POCKETPAY ACTION & REMEDIATION PLAN

**Date:** August 26, 2026  
**Auditor:** Antigravity Senior Security & Software Architect  
**Status:** In Progress (6 historical fixes verified & merged; 14 active tasks pending)

---

## 🎯 Verification of Previous Action Plan

| Previous ID | Description | Resolution Status | Verified Implementation |
| :--- | :--- | :---: | :--- |
| **Fix BUG-01** | Persist user balance deduction via `user.save()` | ✅ **RESOLVED** | `AuthManager.updateBalance(by:)` persists via `UserRepository` |
| **Fix BUG-02** | Persist transactions ledger in Keychain | ✅ **RESOLVED** | `PaymentManager.loadTransactions()` and `saveTransactions()` active |
| **Fix BUG-03** | Fix recurring payment data wipe on reload | ✅ **RESOLVED** | `ServicesViewModel.hasLoadedFromStore` prevents mock overwrites |
| **Fix CODE-01** | Bounds check in `WalletView` selectedCardIndex | ✅ **RESOLVED** | Protected with `if selectedCardIndex < paymentMethods.count` |
| **Fix BUG-04** | Double-charge re-entrancy lock | ✅ **RESOLVED** | Deduplicated through `PaymentManager.processCharge` `isProcessing` guard |
| **Fix PRF-01a** | Static `DateFormatter` in `Transaction.swift` | ✅ **RESOLVED** | Formatter instances cached as static constants |

---

## 🚀 Active Roadmap & Task Breakdown

### Phase 1: P0 Critical & Data Integrity Fixes (Immediate)

- [ ] **Task 1.1 (BUG-01 - 🔴 CRITICAL): Refactor P2P Keypad to Integer Cents**
  - **File:** [`TransferViewModel.swift`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/ViewModel/TransferViewModel.swift)
  - **Action:** Replace `CurrencyFormatter.plain(amount).split(separator: ".")` with integer cents arithmetic (`amountInCents: Int`) to prevent freeze on comma-decimal locales.

- [ ] **Task 1.2 (SEC-01 - 🔴 CRITICAL): Integrate Production Auth Gateway**
  - **File:** [`AuthManager.swift`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/Core/AuthManager.swift), [`LoginView.swift`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/View/LoginView.swift)
  - **Action:** Replace hardcoded `demo`/`password` with real backend JWT authentication (e.g. Supabase Auth) and remove demo credentials text from `LoginView`.

- [ ] **Task 1.3 (SEC-02 - 🔴 CRITICAL): Connect Server-Side Stripe PaymentSheet**
  - **File:** [`StripeManager.swift`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/Core/StripeManager.swift), [`APIKeys.swift`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/Config/APIKeys.swift)
  - **Action:** Add `StripePaymentSheet` SPM dependency, configure backend PaymentIntent endpoint, and present native PaymentSheet.

---

### Phase 2: P1 Navigation, Security & Architecture (Sprint 1)

- [ ] **Task 2.1 (ARC-01 - 🟠 HIGH): Restore Orphaned Services & History Navigation**
  - **File:** [`MainTabView.swift`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/View/MainTabView.swift), [`HomeView.swift`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/View/HomeView.swift)
  - **Action:** Add `ServicesView` and `HistoryView` tabs to `MainTabView`; add navigation links from `HomeView`'s Recent Transactions section.

- [ ] **Task 2.2 (SEC-03 - 🟠 HIGH): Secure Enclave Biometric Binding**
  - **File:** [`AuthManager.swift`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/Core/AuthManager.swift), [`KeychainManager.swift`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/Core/KeychainManager.swift)
  - **Action:** Store session credentials using `SecAccessControl` with `.biometryCurrentSet` and `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly`.

- [ ] **Task 2.3 (PRF-01 - 🟠 HIGH): Move History Grouping Out of SwiftUI Body**
  - **File:** [`HistoryView.swift`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/View/HistoryView.swift)
  - **Action:** Introduce a dedicated `HistoryViewModel` that caches grouped and sorted date sections to avoid $O(N^2)$ body recalculation.

- [ ] **Task 2.4 (ARC-02 - 🟠 HIGH): Reactive Combine Subscriptions in `HomeViewModel`**
  - **File:** [`HomeViewModel.swift`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/ViewModel/HomeViewModel.swift)
  - **Action:** Subscribe to `PaymentManager.$transactions` and `AuthManager.$currentUser` via Combine to automatically update UI state.

- [ ] **Task 2.5 (BUG-03 - 🟠 HIGH): Decouple Calendar Error Alerts from Payment Alerts**
  - **File:** [`ServicesViewModel.swift`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/ViewModel/ServicesViewModel.swift)
  - **Action:** Prevent `showingSuccess = true` from suppressing `CalendarManager` failure alerts in `payOneTimeBill()`.

---

### Phase 3: P2 Financial Accuracy & Performance Polish (Sprint 2)

- [ ] **Task 3.1 (BUG-02 - 🟠 HIGH): Decimal / Minor-Unit Balance Migration**
  - **Files:** `User.swift`, `Transaction.swift`, `PaymentManager.swift`
  - **Action:** Replace binary floating-point `Double` with `Decimal` or `Int64` (cents) for balances and transactions.

- [ ] **Task 3.2 (PRF-02 - 🟡 MEDIUM): Static DateFormatters in Recurring Models**
  - **File:** [`RecurringPayment.swift`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/Model/RecurringPayment.swift)
  - **Action:** Make `formattedNextPaymentDate` use a static shared `DateFormatter`.

- [ ] **Task 3.3 (BUG-04 - 🟡 MEDIUM): PRPay Brand Cleanup**
  - **Files:** [`Constants.swift`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/Config/Constants.swift), [`LoginView.swift`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/View/LoginView.swift), [`WalletView.swift`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/View/WalletView.swift)
  - **Action:** Rename all occurrences of `"PRPay"` and `"PR"` to `"PocketPay"`.

- [ ] **Task 3.4 (BUG-05 - 🟡 MEDIUM): Replace `.constant` Alert Bindings**
  - **Files:** [`ServicesView.swift`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/View/ServicesView.swift), [`AddPaymentView.swift`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/View/AddPaymentView.swift)
  - **Action:** Implement proper two-way `Binding<Bool>` for alert presentation.

- [ ] **Task 3.5 (BUG-06 & BUG-07 - 🟢 LOW): Clean Dead State & Modernize Modifiers**
  - **Files:** [`LoginView.swift`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/View/LoginView.swift), [`AddCardView.swift`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/View/AddCardView.swift)
  - **Action:** Remove dead `@State` variables and replace deprecated iOS 13-16 text modifiers with iOS 17+ equivalents.
