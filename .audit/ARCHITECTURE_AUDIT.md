# 🏛️ REPORTE DE AUDITORÍA ARQUITECTÓNICA (ARCHITECTURE & CLEAN CODE) — POCKETPAY

**Fecha:** 10 de Agosto, 2026  
**Auditor Principal:** Antigravity Senior Security & Software Architect  
**Alcance (Scope):** Evaluación de Acoplamiento, Gestión de Estado Reactive/Combine, Inyección de Dependencias y Buenas Prácticas SwiftUI  

---

## 🔬 Análisis Arquitectónico Detallado

### 🟠 ARC-01: Ausencia de Suscripción Reactiva (Combine) entre ViewModels y Singletons (ALTO)

#### Ubicación
[`PocketPay/ViewModel/HomeViewModel.swift:L40-L53`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/ViewModel/HomeViewModel.swift#L40-L53) & [`PocketPay/View/HomeView.swift:L133-L135`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/View/HomeView.swift#L133-L135)

#### Diagnóstico
`HomeViewModel` mantiene copias locales de los datos:
```swift
@Published var currentUser: User?
@Published var recentTransactions: [Transaction] = []
```
Sin embargo, `HomeViewModel` no se suscribe a las publicaciones `@Published` de `AuthManager.shared` ni de `PaymentManager.shared`. Solo toma una captura puntual de los datos en `init()` y en `loadData()`.

#### Impacto
Si el usuario realiza una transferencia P2P desde `TransferView` o actualiza su nombre en `ProfileView`, la vista `HomeView` **no se entera del cambio** mientras permanezca montada en el árbol de vistas de SwiftUI, mostrando información desactualizada (saldo anterior, transacciones viejas) hasta que se fuerce un `.onAppear`.

#### Solución
En `HomeViewModel`, suscribir los editores de Combine a las fuentes de verdad:
```swift
authManager.currentUserPublisher
    .receive(on: RunLoop.main)
    .assign(to: &$currentUser)

paymentManager.transactionsPublisher
    .map { Array($0.prefix(5)) }
    .receive(on: RunLoop.main)
    .assign(to: &$recentTransactions)
```

---

### 🟠 ARC-02: Violación de Principios SwiftUI / Uso Incorrecto de `@StateObject` con Singletons (ALTO)

#### Ubicación
[`PocketPay/View/WalletView.swift:L17`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/View/WalletView.swift#L17) & [`PocketPay/View/HistoryView.swift:L16-L20`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/View/HistoryView.swift#L16-L20)

#### Diagnóstico
1. En `WalletView.swift`:
```swift
@StateObject private var viewModel = WalletViewModel.shared
```
En SwiftUI, `@StateObject` está diseñado para crear y poseer la vida útil de una instancia nueva de objeto observable. Usar `@StateObject` asignando una referencia singleton compartida (`WalletViewModel.shared`) destruye el ciclo de vida gestionado por SwiftUI y puede provocar fugas de estado y comportamientos impredecibles al destruir y recrear vistas.
2. En `HistoryView.swift`:
```swift
@StateObject private var servicesViewModel = ServicesViewModel()
```
`HistoryView` crea una instancia desechable de `ServicesViewModel` únicamente para transferir su referencia a `TransactionDetailView`.

#### Solución
- Usar `@ObservedObject` o `@EnvironmentObject` para referencias compartidas o singletons.
- Inyectar `ServicesViewModel` a través de la jerarquía de entorno o contenedor de dependencias.

---

### 🟡 ARC-03: Falta de Abstracción de Logging Centralizado (MEDIO)

#### Ubicación
Global en todos los componentes del sistema.

#### Diagnóstico
El proyecto carece de una capa o wrapper de logging (e.g. `AppLogger`). Todo el rastreo se realiza mediante directivas `print()` dispersas en clases de negocio como `CalendarManager`.

#### Solución
Crear un módulo `Utility/Logger.swift` basado en `os.Logger` para categorizar registros en subsistemas (`.auth`, `.payments`, `.calendar`) con control de niveles en entornos de Release vs Debug.
