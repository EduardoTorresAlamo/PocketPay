---
# AGENTS.md — PocketPay

**Stack**: SwiftUI, Swift 6, MVVM, LocalAuthentication (Face ID / Touch ID), Stripe iOS SDK (optional — mock mode default), EventKit, Security, iOS 17+
**Deploy**: Xcode (App Store pending)
**Language**: Swift
**Type**: ios-app
**Fintech**: yes

---

iOS P2P mobile payments app. Biometric auth, custom numeric keypad for transfers, transaction history with filters, payment method management. Mock mode by default — no Stripe account needed to run.

## Commands

```bash
xcodebuild -scheme PocketPay -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
```

## Rules

- All sensitive data is PCI/NACHA-protected when fintech=true
- Mobile-first responsive design (PR market)
- Conventional commits: feat:, fix:, chore:
- Test before merge to main
- No force-push

## Related

- [[wiki/projects/PocketPay.md]] in Obsidian vault
