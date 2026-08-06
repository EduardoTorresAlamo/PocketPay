//
//  PocketPayTests.swift
//  PocketPayTests
//
//  Created by Eduardo Torres on 1/21/26.
//

import Testing
@testable import PocketPay

/// Placeholder suite that proves the test target is wired up and can reach the
/// app module's internal types. Replace with real coverage as it is written.
///
/// The suite is `@MainActor`-isolated because `AuthManaging` / `PaymentProcessing`
/// and every conforming type are isolated to the main actor.
@MainActor
struct PocketPayTests {
    @Test("Test target links against the app module")
    func testTargetIsWiredUp() {
        // PaymentManager can be constructed with injected collaborators,
        // which is what makes the rest of the app unit-testable.
        let manager: any PaymentProcessing = PaymentManager()
        #expect(manager.transactions.isEmpty == false)
    }
}
