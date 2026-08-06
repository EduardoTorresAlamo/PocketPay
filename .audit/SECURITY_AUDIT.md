# 🔒 Reporte de Auditoría de Seguridad — PocketPay

**Fecha:** 6 de Agosto, 2026  
**Auditor:** Code Reviewer & Security Auditor Agent (`code-reviewer-auditor`)  
**Alcance (Audit Scope):** Evaluación de Vulnerabilidades, Cifrado, Persistencia, Autenticación y Cumplimiento PCI-DSS

---

## 🎯 Resumen de Hallazgos de Seguridad

| ID | Severidad | Título / Área | Archivo Afectado | Estado |
| :--- | :---: | :--- | :--- | :---: |
| **SEC-01** | 🔴 CRÍTICO | Almacenamiento Cuestionable de PII y Saldos en `UserDefaults` | [`PocketPay/Model/User.swift`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/Model/User.swift) | **RESUELTO ✅ (KeychainManager)** |
| **SEC-02** | 🔴 CRÍTICO | Credenciales Hardcodeadas y Ausencia de Tokens Secure Keychain | [`PocketPay/Core/AuthManager.swift`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/Core/AuthManager.swift#L49-L73) | PENDIENTE |
| **SEC-03** | 🟠 ALTO | Datos de Tarjetas Guardados en `UserDefaults` (Riesgo PCI-DSS) | [`PocketPay/Model/PaymentMethod.swift`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/Model/PaymentMethod.swift#L107-L124) | **RESUELTO ✅ (KeychainManager)** |
| **SEC-04** | 🟠 ALTO | Exposición Potencial de Secret Keys en Código Cliente | [`PocketPay/Config/APIKeys.swift`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/Config/APIKeys.swift) | **RESUELTO ✅ (Removido)** |
| **SEC-05** | 🟡 MEDIO | Flujo Biométrico Inseguro Sin Llaves de Keychain Ligadas al Secure Enclave | [`PocketPay/Core/AuthManager.swift`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/Core/AuthManager.swift#L75-L124) | PENDIENTE |
| **SEC-06** | 🟡 MEDIO | Ausencia de Transport Layer Security (ATS) y SSL Certificate Pinning | Global / Configuración de Red | PENDIENTE |
| **SEC-07** | 🟢 BAJO | Exposición de Mensajes de Error Internos del Sistema en la UI | [`PocketPay/Core/AuthManager.swift`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/Core/AuthManager.swift#L118-L122) | PENDIENTE |

---

## 🚨 Hallazgos Detallados y Estado de Remediación

### SEC-01: Almacenamiento Cuestionable de PII y Saldos (🔴 CRÍTICO — RESUELTO ✅)

#### Diagnóstico Previos vs Estado Actual
- **Previo:** `User.swift` guardaba la PII del usuario (nombre, correo, teléfono, dirección postal y saldo financiero) en `UserDefaults.standard` en texto plano (.plist).
- **Estado Actual:** ✅ **Resuelto**. Se creó [`KeychainManager.swift`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/Core/KeychainManager.swift) implementando la API nativa de `Security` (`SecItemAdd`, `SecItemCopyMatching`, `SecItemDelete`) con la clase `kSecClassGenericPassword` y accesibilidad `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. `User.save()`, `User.load()` y `User.clearSaved()` interactúan únicamente con la boveda cifrada del sistema.

---

### SEC-02: Credenciales Hardcodeadas y Ausencia de Backend Tokens (🔴 CRÍTICO — PENDIENTE)

#### Diagnóstico
En [`AuthManager.swift`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/Core/AuthManager.swift#L49-L73):
```swift
if username.lowercased() == "demo" && password == "password" {
    ...
}
```
1. La autenticación es puramente simulada en el cliente y acepta credenciales fijas (`demo` / `password`).
2. No existe intercambio ni almacenamiento de JWT (`accessToken` / `refreshToken`) firmado por un servidor backend.

#### Remediación Recomendada
Conectar `AuthManager.login` con el servicio backend mediante un endpoint `/api/v1/auth/login`. Al recibir los tokens de sesión, guardarlos inmediatamente en `KeychainManager` y utilizarlos en la cabecera `Authorization: Bearer <token>` de las solicitudes HTTP.

---

### SEC-03: Datos de Tarjetas en UserDefaults / Riesgo PCI-DSS (🟠 ALTO — RESUELTO ✅)

#### Diagnóstico Previos vs Estado Actual
- **Previo:** Los metadatos de las tarjetas de crédito y débito se persistían en `UserDefaults.standard`.
- **Estado Actual:** ✅ **Resuelto**. `PaymentMethod.saveAll()` y `PaymentMethod.loadAll()` fueron migrados a `KeychainManager`.

---

### SEC-04: Exposición de Secret Keys en Código Cliente (🟠 ALTO — RESUELTO ✅)

#### Diagnóstico Previos vs Estado Actual
- **Previo:** `APIKeys.swift` definía una propiedad estática `stripeSecretKey`.
- **Estado Actual:** ✅ **Resuelto**. La constante se eliminó por completo del código cliente. [`APIKeys.swift`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/Config/APIKeys.swift) conserva únicamente `stripePublishableKey` (que es segura de incluir en el bundle de la app) y el flag de mocks.

---

### SEC-05: Flujo Biométrico sin Vincular a Secure Enclave (🟡 MEDIO — PENDIENTE)

#### Diagnóstico
`AuthManager.authenticateWithBiometrics()` valida el sensor del dispositivo mediante `LAContext().evaluatePolicy(...)`. Sin embargo, tras la validación exitosa, no desencripta ningún secreto guardado en Keychain mediante una clave protegida con `SecAccessControlCreateWithFlags(..., .biometryAny, ...)`.

#### Riesgo
En un dispositivo jailbroken, herramientas como Frida pueden hacer hook a `evaluatePolicy` y forzar un retorno `true`, eludiendo el sensor biométrico sin requerir acceso físico.

---

## 🛡️ Checklist de Control de Seguridad

- [x] Reemplazar `UserDefaults` por `KeychainServices` para `User` y `PaymentMethod`.
- [x] Eliminar `APIKeys.stripeSecretKey` del cliente iOS.
- [ ] Conectar `AuthManager` con backend JWT/OAuth2.
- [ ] Proteger el token de sesión con llaves del Secure Enclave (`.biometryAny`).
- [ ] Habilitar SSL Pinning en la capa de red para la URL del backend (`APIKeys.backendURL`).
