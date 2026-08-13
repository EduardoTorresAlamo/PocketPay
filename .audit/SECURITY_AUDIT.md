# 🔒 REPORTE DE AUDITORÍA DE SEGURIDAD (SECURITY AUDIT) — POCKETPAY

**Fecha:** 10 de Agosto, 2026  
**Auditor Principal:** Antigravity Senior Security & Software Architect  
**Alcance (Scope):** Evaluación de Vulnerabilidades, Cifrado, Persistencia Criptográfica, Autenticación y Cumplimiento de Seguridad  

---

## 🎯 Hallazgos de Seguridad Detallados

### 🔴 SEC-01: Autenticación Frágil con Credenciales Hardcodeadas y Ausencia de Session Token (CRÍTICO)

#### Ubicación
[`PocketPay/Core/AuthManager.swift:L54-L74`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/Core/AuthManager.swift#L54-L74)

#### Descripción del Problema
La función `login(username:password:)` simula la autenticación contra una cuenta fija en código cliente:
```swift
if username.lowercased() == "demo" && password == "password" {
    var user = User.load() ?? User.mockUser
    user.username = username
    currentUser = user
    isAuthenticated = true
    ...
}
```
No se realiza ninguna petición remota a un servidor seguro, no se recibe un token JWT o bearer token firmado, ni se gestiona expiración de sesión. La bandera de autenticación es simplemente una propiedad booleana `@Published var isAuthenticated = false` local en memoria.

#### Impacto en Producción
- **Acceso No Autorizado Universal:** Cualquier usuario que descargue la app puede ingresar con las credenciales por defecto `demo` / `password`.
- **Falta de Revocación de Sesión:** Si la sesión es comprometida, no existe endpoint de revocación server-side.
- **Riesgo Faltante PCI / Regulación:** Almacenar o simular claves sin backend destruye cualquier certificación de seguridad financiera.

#### Solución Recomendada
1. Conectar `login(username:password:)` con un backend Supabase Auth (`supabase.auth.signInWithPassword(email:password:)`).
2. Recibir `AccessToken` y `RefreshToken` criptográficos firmados (Ed25519 / RS256).
3. Guardar el `RefreshToken` en el Keychain usando `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.

---

### 🔴 SEC-02: Cifrado Incompleto en Keychain, Falta de Secure Enclave `SecAccessControl` y Supresión Silenciosa de Errores `OSStatus` (CRÍTICO)

#### Ubicación
[`PocketPay/Core/KeychainManager.swift:L18-L77`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/Core/KeychainManager.swift#L18-L77) & [`PocketPay/Core/AuthManager.swift:L84-L119`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/Core/AuthManager.swift#L84-L119)

#### Descripción del Problema
1. **Ignoración de Errores `OSStatus`:** En `KeychainManager.swift`:
```swift
SecItemDelete(deleteQuery as CFDictionary)
SecItemAdd(addQuery as CFDictionary, nil)
```
El valor de retorno `OSStatus` devuelto por `SecItemAdd` y `SecItemDelete` es **completamente ignorado**. Si el Keychain del dispositivo está bloqueado, lleno, o carece del entitlement `keychain-access-groups`, el almacenamiento de credenciales o datos de usuario falla silenciosamente sin notificar al código llamante.
2. **Biometría Desvinculada del Secure Enclave:** En `AuthManager.swift`:
```swift
let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Log in to PocketPay")
```
`authenticateWithBiometrics()` valida la identidad usando `LAContext`, pero **NO desencripta ni solicita un item de Keychain protegido por `SecAccessControlCreateFlags.biometryAny`**.

#### Impacto en Producción
- **Bypass de Biometría mediante Frida / Substrate:** En dispositivos con Jailbreak o entornos de análisis dinámico, una simple regla de Frida que fuerce `LAContext.evaluatePolicy` a retornar `true` otorgará acceso total a la cuenta, ya que no se requiere una clave privada generada dentro del Hardware Secure Enclave.
- **Pérdida Silenciosa de Datos:** Al fallar `SecItemAdd`, el usuario cree que su información se guardó, pero al cerrar la app los datos habrán desaparecido.

#### Solución Recomendada
1. Comprobar sistemáticamente el `OSStatus` devuelto por `SecItemAdd` y lanzar excepciones de tipo `AppError.keychainError(status)`.
2. Crear un registro en Keychain con `SecAccessControl` configurado con `.biometryAny` o `.userPresence`:
```swift
var error: Unmanaged<CFError>?
guard let accessControl = SecAccessControlCreateWithFlags(
    kCFAllocatorDefault,
    kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
    .biometryAny,
    &error
) else { return }
```

---

### 🟠 SEC-03: Ausencia de SSL Certificate Pinning y Configuración ATS Inexistente (ALTO)

#### Ubicación
[`PocketPay/Core/StripeManager.swift:L62-L86`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/Core/StripeManager.swift#L62-L86) & [`PocketPay/Config/APIKeys.swift:L21`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/Config/APIKeys.swift#L21)

#### Descripción del Problema
La integración remota para crear intenciones de pago en Stripe (`createPaymentIntent`) no incluye validación de certificados SSL (`SSL Certificate Pinning`) ni configuración explícita en `Info.plist` para `App Transport Security (ATS)`.

#### Impacto en Producción
En redes Wi-Fi públicas o no seguras, atacantes pueden realizar ataques Man-in-the-Middle (MitM) instalando certificados CA maliciosos en el dispositivo del usuario e interceptar tokens de tarjetas, montos y PII.

#### Solución Recomendada
Implementar `URLSessionDelegate` con la callback `urlSession(_:didReceive:completionHandler:)` para validar la clave pública (Public Key Pinning) del dominio backend de Stripe / Supabase.

---

### 🟠 SEC-04: Exposición de PII y Datos Financieros en Logs de Consola (`print`) (ALTO)

#### Ubicación
[`PocketPay/Core/CalendarManager.swift:L46-L175`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/Core/CalendarManager.swift#L46-L175) & [`PocketPay/Core/StripeManager.swift:L48`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/Core/StripeManager.swift#L48)

#### Descripción del Problema
Se utiliza `print()` ad-hoc para registrar eventos de calendario y pagos:
```swift
print("📅 CalendarManager: Starting to create recurring event '\(title)'")
print("📅 CalendarManager: Event date: \(startDate)")
```
Los títulos de los eventos contienen nombres de facturas, servicios contratados y montos de los usuarios.

#### Impacto en Producción
En iOS, `print()` escribe directamente en el sistema de logs global del sistema operativo (`syslog` / `Apple Unified Logging`). Cualquier aplicación de escritorio conectada por USB o herramientas de diagnóstico pueden leer estos logs en tiempo real sin requerir privilegios especiales.

#### Solución Recomendada
Reemplazar `print()` por `import os` y `Logger(subsystem:category:)`, utilizando calificadores de privacidad en datos sensibles: `\(title, privacy: .private)`.

---

### 🟡 SEC-05: Exposición Directa de Errores Internos en la UI (`error.localizedDescription`) (MEDIO)

#### Ubicación
[`PocketPay/Core/AuthManager.swift:L116`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/Core/AuthManager.swift#L116) & [`PocketPay/Core/CalendarManager.swift:L60`](file:///Users/eduardotorres/Developer/XCodes/PocketPay/PocketPay/Core/CalendarManager.swift#L60)

#### Descripción del Problema
Al capturar excepciones genéricas (`catch`), se asigna `error.localizedDescription` directamente a la propiedad `@Published var errorMessage: String?` que se muestra al usuario en la interfaz.

#### Impacto en Producción
Mensajes de error internos del framework (e.g. `LAErrorDomain code -2`, `NSURLErrorDomain`) exponen información sobre la versión del SO, arquitectura de archivos y estado de los sensores al usuario final o a atacantes.

#### Solución Recomendada
Mapear todos los errores del sistema a casos amigables y sanitizados en `AppError.swift`.
