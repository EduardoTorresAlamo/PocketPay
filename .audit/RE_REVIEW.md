# Reporte de Re-Revisión de Fixes — PocketPay

**Fecha:** 10 de Agosto de 2026  
**Proyecto:** PocketPay (iOS / Swift)  
**Ubicación de Código:** `PocketPay/`  
**Estado General:** **100% VERIFICADO — 5 DE 5 FIXES APROBADOS**

---

## 1. Resumen Ejecutivo

Se ha realizado una auditoría y verificación exhaustiva sobre la implementación de los 5 fixes solicitados en la base de código de PocketPay. Todos los puntos han sido analizados a nivel de código fuente, validando el control de flujo, la persistencia en Keychain y la seguridad en la interfaz de usuario.

| # | Fix Solicitado | Archivo Evaluado | Líneas | Estado | Observación Principal |
|---|---|---|---|---|---|
| **1** | `PaymentManager.loadTransactions` lee de Keychain | `PocketPay/Core/PaymentManager.swift` | L60–L64 | **VERIFICADO (CORRECTO)** | Invoca `KeychainManager.load`, realiza fallback seguro a `mockTransactions` y ordena por fecha descendente. |
| **2** | `PaymentManager.sendMoney` tiene `guard !isProcessing` | `PocketPay/Core/PaymentManager.swift` | L84 | **VERIFICADO (CORRECTO)** | Protege contra reentradas/doble cobro al inicio del método. |
| **3** | `PaymentManager` llama `user.save()` tras deducciones | `PocketPay/Core/PaymentManager.swift` | L125, L186, L245 | **VERIFICADO (CORRECTO)** | Se ejecuta `if let user = authManager.currentUser { user.save() }` en `sendMoney`, `payBusiness` y `makeDonation`. |
| **4** | `ServicesViewModel.loadRecurringPayments` carga de Keychain primero | `PocketPay/ViewModel/ServicesViewModel.swift` | L90–L100 | **VERIFICADO (CORRECTO)** | Utiliza la bandera `hasLoadedFromStore` para leer de Keychain antes del fallback y evitar sobrescribir datos en memoria. |
| **5** | `WalletView` tiene bounds check en `selectedCardIndex` | `PocketPay/View/WalletView.swift` | L42–L56 | **VERIFICADO (CORRECTO)** | Condiciona el renderizado con `selectedCardIndex < paymentMethods.count`, incluye `guard` en acciones y ajusta el índice tras eliminación. |

---

## 2. Revisión Detallada por Punto

### 1. `PaymentManager.loadTransactions` lee de Keychain
* **Archivo:** [`PaymentManager.swift`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/Core/PaymentManager.swift#L60-L64)
* **Código Implementado:**
```swift
func loadTransactions() {
    let saved: [Transaction]? = KeychainManager.load(key: PaymentManager.transactionsKeychainKey)
    let source = saved ?? Transaction.mockTransactions
    transactions = source.sorted { $0.date > $1.date }
}
```
* **Análisis:**
  1. `KeychainManager.load(key: PaymentManager.transactionsKeychainKey)` es invocado para obtener las transacciones guardadas.
  2. Si `saved` es `nil` (primer inicio de la aplicación), el operador nulo-coalescente `??` utiliza `Transaction.mockTransactions`.
  3. La lista se ordena por fecha descendente (`$0.date > $1.date`) garantizando que la transacción más reciente aparezca al inicio.
  4. `loadTransactions()` es invocado desde el `init()` de `PaymentManager`.
  5. Cada transacción procesada posteriormente invoca `saveTransactions()`, persistiendo los cambios en Keychain.

---

### 2. `PaymentManager.sendMoney` tiene guard `!isProcessing`
* **Archivo:** [`PaymentManager.swift`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/Core/PaymentManager.swift#L82-L85)
* **Código Implementado:**
```swift
func sendMoney(to contact: Contact, amount: Double, notes: String?) async -> Bool {
    // Reject re-entrant taps while a charge is already in flight (double-charge guard).
    guard !isProcessing else { return false }

    guard let currentUser = authManager.currentUser else { ... }
```
* **Análisis:**
  1. La primera instrucción de `sendMoney` es `guard !isProcessing else { return false }`.
  2. Esto previene peticiones concurrentes o reentrantes (ejemplo: usuario haciendo doble tap rápido en el botón de envío).
  3. `isProcessing` se establece en `true` a la línea 101 antes de llamar a `stripeManager.processPayment` y se restablece a `false` tanto en el flujo de éxito (L127) como en el de error (L132).
  4. *Nota técnica adicional:* `sendMoney` cumple estrictamente el requisito. Los otros métodos (`payBusiness` y `makeDonation`) manejan `isProcessing = true`, pero no cuentan con el `guard !isProcessing` inicial.

---

### 3. `PaymentManager` llama `user.save()` tras deducciones
* **Archivo:** [`PaymentManager.swift`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/Core/PaymentManager.swift#L123-L125)
* **Código Implementado:**

*En `sendMoney`:*
```swift
// Optimistically deduct balance from the in-memory user model.
authManager.currentUser?.balance -= amount
if let user = authManager.currentUser { user.save() }
```

*En `payBusiness`:*
```swift
// Update user balance
authManager.currentUser?.balance -= amount
if let user = authManager.currentUser { user.save() }
```

*En `makeDonation`:*
```swift
// Update user balance
authManager.currentUser?.balance -= amount
if let user = authManager.currentUser { user.save() }
```
* **Análisis:**
  1. En los tres métodos de pago (`sendMoney`, `payBusiness`, `makeDonation`), inmediatamente después de sustraer el monto del balance en memoria (`authManager.currentUser?.balance -= amount`), se ejecuta la persistencia mediante `user.save()`.
  2. `user.save()` actualiza el estado del usuario en la persistencia local (`KeychainManager`), asegurando que el nuevo saldo persista tras el reinicio de la app.

---

### 4. `ServicesViewModel.loadRecurringPayments` carga de Keychain primero
* **Archivo:** [`ServicesViewModel.swift`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/ViewModel/ServicesViewModel.swift#L90-L100)
* **Código Implementado:**
```swift
func loadRecurringPayments() {
    if !hasLoadedFromStore {
        let saved: [RecurringPayment]? = KeychainManager.load(key: Self.recurringKeychainKey)
        recurringPayments = saved ?? RecurringPayment.mockRecurringPayments
        hasLoadedFromStore = true
    }
    KeychainManager.save(recurringPayments, key: Self.recurringKeychainKey)

    activePayments = recurringPayments.filter { $0.isActive }
    duePayments = recurringPayments.filter { $0.isActive && $0.isDueSoon }
}
```
* **Análisis:**
  1. Utiliza la propiedad booleana `hasLoadedFromStore` (inicializada en `false`).
  2. En la primera ejecución (`!hasLoadedFromStore`), lee de Keychain mediante `KeychainManager.load(key: Self.recurringKeychainKey)`.
  3. Si existen datos almacenados, asigna `saved`; si no, usa `RecurringPayment.mockRecurringPayments`.
  4. Marca `hasLoadedFromStore = true`, lo cual garantiza que llamadas subsecuentes a `loadRecurringPayments()` durante la misma sesión no sobrescriban los elementos en memoria con datos antiguos de almacenamiento antes de persisitir.
  5. Guarda en Keychain la lista actualizada y refresca las propiedades publicadas `activePayments` y `duePayments`.

---

### 5. `WalletView` tiene bounds check en `selectedCardIndex`
* **Archivo:** [`WalletView.swift`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/View/WalletView.swift#L42-L56)
* **Código Implementado:**
```swift
// Card Actions — only rendered while the index still points at a card,
// since removals can leave `selectedCardIndex` past the end of the array.
if selectedCardIndex >= 0, selectedCardIndex < viewModel.paymentMethods.count {
    CardActionsView(
        card: viewModel.paymentMethods[selectedCardIndex],
        setAsDefaultAction: {
            guard selectedCardIndex < viewModel.paymentMethods.count else { return }
            viewModel.setDefaultPaymentMethod(viewModel.paymentMethods[selectedCardIndex])
        },
        removeAction: {
            guard selectedCardIndex < viewModel.paymentMethods.count else { return }
            viewModel.removePaymentMethod(viewModel.paymentMethods[selectedCardIndex])
            if selectedCardIndex > 0 {
                selectedCardIndex -= 1
            }
        }
    )
    .padding(.horizontal, 24)
}
```
* **Análisis:**
  1. **Nivel Vista (SwiftUI):** La sección `CardActionsView` está envuelta en la condición `if selectedCardIndex >= 0, selectedCardIndex < viewModel.paymentMethods.count`. Si la lista queda vacía o el índice está fuera de rango, no se renderiza la vista de acciones, evitando accesos fuera de rango (Index out of range crash).
  2. **Nivel Closure (Acciones):**
     - En `setAsDefaultAction`: `guard selectedCardIndex < viewModel.paymentMethods.count else { return }`.
     - En `removeAction`: `guard selectedCardIndex < viewModel.paymentMethods.count else { return }`.
  3. **Ajuste Pos-eliminación:** Tras remover una tarjeta en `removeAction`, si `selectedCardIndex > 0`, se decrementa en 1 (`selectedCardIndex -= 1`), manteniendo el índice dentro de los límites válidos del arreglo actualizado.

---

## 3. Conclusión

Los **5 fixes evaluados en PocketPay están correctamente implementados** y cumplen con los estándares de robustez, persistencia y seguridad requeridos:
- Persistencia en Keychain activa para transacciones y pagos recurrentes.
- Protección contra doble cobro/reentrante en `sendMoney`.
- Sincronización inmediata del balance del usuario en almacenamiento mediante `user.save()`.
- Verificaciones de límites de arreglo (bounds check) en `WalletView` que evitan crashes al manipular o eliminar tarjetas de crédito.
