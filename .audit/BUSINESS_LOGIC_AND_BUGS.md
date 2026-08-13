# 🐛 REPORTE DE BUGS DE LÓGICA DE NEGOCIO Y DATOS (BUSINESS LOGIC & DATA CORRUPTION) — POCKETPAY

**Fecha:** 10 de Agosto, 2026  
**Auditor Principal:** Antigravity Senior Security & Software Architect  
**Alcance (Scope):** Evaluación de Lógica Financiera, Persistencia en Registro (Ledger), Condición de Carrera, Precisión Numérica y Keypads  

---

## 🔬 Análisis Detallado de Bugs de Negocio y Data Loss

### 🔴 BUG-01: Pérdida Total de Datos y Fallo de Persistencia del Saldo (`balance`) (CRÍTICO)

#### Ubicación
[`PocketPay/Core/PaymentManager.swift:L110, L169, L226`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/Core/PaymentManager.swift#L110) & [`PocketPay/Model/User.swift:L57-L75`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/Model/User.swift#L57-L75)

#### Descripción del Problema
Cuando una transferencia P2P (`sendMoney`), pago de servicio (`payBusiness`) o donación (`makeDonation`) se completa con éxito, `PaymentManager` deduce el monto del usuario actual en memoria:
```swift
authManager.currentUser?.balance -= amount
```
**Sin embargo, jamás se invoca `authManager.currentUser?.save()` ni `user.save()`.**

#### Impacto en Producción
El nuevo saldo modificado existe únicamente en la memoria RAM del proceso actual. Cuando el usuario cierra la aplicación o el sistema operativo la mata en segundo plano, la siguiente ejecución invoca `User.load()`, la cual lee los datos antiguos guardados en Keychain. **El saldo gastado por el usuario reaparece mágicamente**, permitiendo gastar el mismo dinero indefinidamente localmente.

#### Solución Recomendada
En `PaymentManager.swift`, tras descontar el saldo, invocar inmediatamente la persistencia:
```swift
if let updatedUser = authManager.currentUser {
    updatedUser.save()
}
```

---

### 🔴 BUG-02: Pérdida del Historial de Transacciones (Ausencia de Persistencia en Ledger) (CRÍTICO)

#### Ubicación
[`PocketPay/Core/PaymentManager.swift:L27, L56-L59, L107`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/Core/PaymentManager.swift#L27)

#### Descripción del Problema
La propiedad `@Published var transactions: [Transaction] = []` en `PaymentManager` se inicializa mediante `loadTransactions()`, el cual lee el arreglo estático en memoria `Transaction.mockTransactions`.
Cuando el usuario envía o paga dinero, la nueva transacción se inserta en el índice 0:
```swift
transactions.insert(transaction, at: 0)
```
**No existe ninguna llamada para guardar el arreglo `transactions` en Keychain, CoreData o Supabase.**

#### Impacto en Producción
Todas las transferencias y recibos de dinero generados por el usuario se borran de la faz de la app en cuanto la aplicación se reinicia. El historial vuelve a mostrar únicamente las 12 transacciones mock originales.

#### Solución Recomendada
1. Implementar la persistencia de transacciones en `KeychainManager` o BD relacional.
2. Guardar el arreglo codificado tras cada inserción.

---

### 🔴 BUG-03: Reset Destructivo Automático de Servicios Recurrentes en `ServicesViewModel` (CRÍTICO)

#### Ubicación
[`PocketPay/ViewModel/ServicesViewModel.swift:L81-L85, L113, L178`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/ViewModel/ServicesViewModel.swift#L81-L85)

#### Descripción del Problema
En `ServicesViewModel.swift`, la función `loadRecurringPayments()` reinicia incondicionalmente el estado del ViewModel con los datos estáticos de prueba:
```swift
func loadRecurringPayments() {
    recurringPayments = RecurringPayment.mockRecurringPayments
    activePayments = recurringPayments.filter { $0.isActive }
    duePayments = recurringPayments.filter { $0.isActive && $0.isDueSoon }
}
```
En las funciones `payBill` (línea 113) y `payOneTimeBill` (línea 178), tras añadir un nuevo pago recurrente al arreglo (`recurringPayments.append(newRecurring)`), el código ejecuta inmediatamente `loadRecurringPayments()`.

#### Impacto en Producción
Cualquier intento por parte del usuario de añadir un nuevo pago recurrente o actualizar la fecha de su factura resulta en el **borrado automático inmediato del nuevo elemento**. La lista se sobrescribe al instante con los valores iniciales mock.

#### Solución Recomendada
Eliminar la reasignación forzada de `mockRecurringPayments` en `loadRecurringPayments()`. Cargar únicamente desde la capa de persistencia.

---

### 🟠 BUG-04: Race Condition y Doble Gasto (Double Charge) por Falta de Concurrency Lock (ALTO)

#### Ubicación
[`PocketPay/Core/PaymentManager.swift:L72-L88`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/Core/PaymentManager.swift#L72-L88) & [`PocketPay/ViewModel/TransferViewModel.swift:L183-L195`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/ViewModel/TransferViewModel.swift#L183-L195)

#### Descripción del Problema
En `PaymentManager.sendMoney(to:amount:notes:)`, se valida el saldo antes de procesar el pago:
```swift
guard currentUser.balance >= amount else {
    errorMessage = "Insufficient balance"
    return false
}
isProcessing = true
let paymentSuccess = await stripeManager.processPayment(amount: amount)
```
Sin embargo, `sendMoney` **NO verifica si `isProcessing` ya es `true` al inicio de la función**.

#### Impacto en Producción
Si el usuario presiona dos veces rápidamente el botón "Send Money" (o la UI sufre un retraso de renderizado), dos tareas asíncronas paralelas entran a `sendMoney`. Ambas evalúan `currentUser.balance >= amount` antes de que la primera complete la deducción, permitiendo efectuar dos cobros y dejando la cuenta del usuario con **saldo negativo no autorizado**.

#### Solución Recomendada
Añadir una cláusula guard al inicio de `sendMoney`:
```swift
guard !isProcessing else { return false }
```

---

### 🟠 BUG-05: Inprecisión Financiera por Uso de Floating-Point (`Double`) (ALTO)

#### Ubicación
Global en `User.swift`, `Transaction.swift`, `PaymentManager.swift`, `RecurringPayment.swift`, `TransferViewModel.swift`.

#### Descripción del Problema
Los balances financieros y montos de transferencias utilizan el tipo primitivo `Double` (coma flotante IEEE 754 de 64 bits).
Las operaciones de resta `balance -= amount` y sumatoria `reduce(0) { $0 + $1.amount }` acumulan imprecisiones binarias en representación de punto flotante:
`1250.00 - 0.70 = 1249.2999999999997`.

#### Impacto en Producción
Errores de redondeo en operaciones contables que provocan descuadres de centavos, fallos en comprobaciones de saldo insuficiente y discrepancias en auditorías financieras.

#### Solución Recomendada
Refactorizar todos los atributos monetarios para utilizar `Decimal` o enteros que representen centavos (`Int64`).

---

### 🟠 BUG-06: Algoritmo Inestable y Sensible a `Locale` en Keypad Numérico (ALTO)

#### Ubicación
[`PocketPay/ViewModel/TransferViewModel.swift:L112-L163`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/ViewModel/TransferViewModel.swift#L112-L163)

#### Descripción del Problema
El teclado numérico personalizado convierte el monto en `Double` a `String` usando `CurrencyFormatter.plain(amount)`, hace un split por el carácter `"."`, altera la cadena de texto de los centavos y luego re-parsea la cadena como `Double`:
```swift
let currentAmountString = CurrencyFormatter.plain(amount)
let components = currentAmountString.split(separator: ".")
...
amount = Double("\(dollars).\(newCents)") ?? amount
```
1. Si el dispositivo del usuario está configurado en una región/idioma donde el separador decimal es la coma `,` (e.g. España, Argentina, Alemania), `CurrencyFormatter.plain` genera cadenas con `,`, rompiendo el `.split(separator: ".")`.
2. `Double("1.50")` puede retornar `nil` en locales con coma, o imprecisiones de coma flotante desconfiguran los centavos.

#### Impacto en Producción
El teclado numérico de transferencia se congela por completo en dispositivos con idioma o región internacional, impidiendo ingresar montos.

#### Solución Recomendada
Reemplazar la manipulación de strings por aritmética entera basada en centavos (`var amountInCents: Int = 0`).

---

### 🟡 BUG-07: Error Matemático en Estimación de Gastos Mensuales Recurrentes (`totalMonthlyRecurring`) (MEDIO)

#### Ubicación
[`PocketPay/ViewModel/ServicesViewModel.swift:L240-L256`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/ViewModel/ServicesViewModel.swift#L240-L256)

#### Descripción del Problema
En `totalMonthlyRecurring`, los pagos semanales se multiplican por 4 y los bisemanales por 2:
```swift
case .weekly: return total + (payment.amount * 4)
case .biWeekly: return total + (payment.amount * 2)
```
Un año tiene 52 semanas (4.333 semanas por mes) y 26 periodos bisemanales (2.166 por mes).

#### Impacto en Producción
La proyección mensual mostrada en el "Monthly Overview" subestima los costos reales del usuario en un **8.3% anual**.

#### Solución Recomendada
Usar las fórmulas exactas:
- Semanal: `(amount * 52) / 12` (multiplicador: ~4.3333)
- Bisemanal: `(amount * 26) / 12` (multiplicador: ~2.1666)
