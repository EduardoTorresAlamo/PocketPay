# ⚡ REPORTE DE AUDITORÍA DE RENDIMIENTO Y RENDERS (PERFORMANCE & MEMORY) — POCKETPAY

**Fecha:** 10 de Agosto, 2026  
**Auditor Principal:** Antigravity Senior Security & Software Architect  
**Alcance (Scope):** Asignaciones de Memoria, Concurrencia Async/Await, Latencia de UI y Rendimiento de Scroll en Listas SwiftUI  

---

## 🔬 Análisis de Rendimiento y Cuellos de Botella

### 🟠 PRF-01: Instanciación Descontrolada de `DateFormatter` en Filas SwiftUI (ALTO)

#### Ubicación
[`PocketPay/Model/Transaction.swift:L151-L162`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/Model/Transaction.swift#L151-L162), [`PocketPay/Model/RecurringPayment.swift:L128-L132`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/Model/RecurringPayment.swift#L128-L132) & [`PocketPay/View/HistoryView.swift:L157-L160`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/View/HistoryView.swift#L157-L160)

#### Diagnóstico
Las propiedades calculadas `formattedDate` y `formattedTime` en la estructura `Transaction` inicializan una nueva instancia de `DateFormatter` **cada vez que la propiedad es evaluada**:

```swift
var formattedDate: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d, yyyy"
    return formatter.string(from: date)
}
```

#### Impacto
Crear un `DateFormatter` en Swift es una operación extremadamente costosa en CPU y memoria debido a la carga interna de tablas de localización, zonas horarias y calendarios de ICU.
Al hacer desplazamientos (scroll) en `HistoryView` o `HomeView`, cada renderizado de celda invoca estas propiedades. Para una lista de 50 elementos, se instancian más de 100 objetos `DateFormatter` por segundo, provocando **caídas severas de cuadros por segundo (stuttering / dropped frames)** y picos innecesarios en la huella de memoria.

#### Solución Recomendada
Centralizar los formateadores como propiedades `static let` en `CurrencyFormatter.swift` o en un helper dedicado:

```swift
enum DateFormatters {
    static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f
    }()
}
```

---

### 🟠 PRF-02: Algoritmo Ineficiente $O(N \log N)$ de Agrupación de Fechas en el Thread Principal (ALTO)

#### Ubicación
[`PocketPay/View/HistoryView.swift:L27-L32, L140-L144`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/View/HistoryView.swift#L27-L32)

#### Diagnóstico
En `HistoryView.swift`, las propiedades calculadas `filteredTransactions` y `groupedTransactions` realizan filtrados, ordenamientos de diccionarios y agrupaciones de fechas en cada evaluación del cuerpo de la vista (`body`):

```swift
private var groupedTransactions: [Date: [Transaction]] {
    Dictionary(grouping: filteredTransactions) { transaction in
        Calendar.current.startOfDay(for: transaction.date)
    }
}
```

#### Impacto
Cada vez que el usuario interactúa con la UI (e.g. selecciona un chip de categoría o SwiftUI recalcula el layout), se ejecuta la agrupación $O(N \log N)$ en el `@MainActor`. Con historiales extensos de transacciones, esto causa congelamiento momentáneo del hilo de UI.

#### Solución Recomendada
Mover el cómputo de agrupación fuera del `body` de SwiftUI hacia el ViewModel, ejecutándolo únicamente cuando la lista de transacciones cambia o el filtro seleccionado se actualiza.

---

### 🟡 PRF-03: Exceso de Saltos de Actor mediante `MainActor.run` Fragmentados (MEDIO)

#### Ubicación
[`PocketPay/Core/StripeManager.swift:L114-L151`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/Core/StripeManager.swift#L114-L151)

#### Diagnóstico
En `StripeManager.swift`, se realizan múltiples llamadas dispersas a `await MainActor.run { ... }` dentro de la misma función asíncrona para actualizar propiedades individuales (`isProcessing`, `errorMessage`).

#### Solución Recomendada
Anotar la clase completa o los métodos de actualización UI con `@MainActor` para evitar hops continuos de contexto en el runtime de Swift Concurrency.
