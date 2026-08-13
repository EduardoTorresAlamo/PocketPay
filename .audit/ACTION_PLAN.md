# 📋 PLAN DE ACCIÓN Y REMEDIACIÓN DE SEVERIDAD REAL — POCKETPAY

**Fecha:** 10 de Agosto, 2026  
**Auditor Principal:** Antigravity Senior Security & Software Architect  
**Estado de Verificación de Implementación:** ❌ **0% IMPLEMENTADO (0 DE 10 FIXES EN CÓDIGO FUENTE)**

---

## 🎯 Hoja de Ruta Priorizada de Correcciones (Roadmap)

### FASE 1: Remediación Crítica de Seguridad y Pérdida de Datos (Inmediato / Día 1-2)

- [ ] **Fix BUG-01 (Saldo Reset):** Añadir `updatedUser.save()` en `PaymentManager` tras deducir balances en `sendMoney`, `payBusiness` y `makeDonation`. *(Estado actual: ❌ PENDIENTE)*
- [ ] **Fix BUG-02 (Transacciones Wipe):** Implementar persistencia de transacciones en `KeychainManager` para que el historial no se borre al reiniciar la app. *(Estado actual: ❌ PENDIENTE)*
- [ ] **Fix BUG-03 (Reset Recurrente):** Corregir `ServicesViewModel.loadRecurringPayments()` para no sobrescribir `recurringPayments` con datos mock al agregar/pagar cuentas. *(Estado actual: ❌ PENDIENTE)*
- [ ] **Fix CODE-01 (Crash Tarjetas):** Insertar bounds check en `WalletView.swift` (`guard selectedCardIndex < paymentMethods.count`) para evitar crash fatal `Index out of range`. *(Estado actual: ❌ PENDIENTE)*
- [ ] **Fix SEC-02 (Keychain OSStatus & Biometría Enclave):** Verificar el código de retorno `OSStatus` en `KeychainManager` y vincular ítems sensibles al Secure Enclave (`.biometryAny`). *(Estado actual: ❌ PENDIENTE)*

---

### FASE 2: Concurrencia, Precisión Financiera y Rendimiento (Día 3-4)

- [ ] **Fix BUG-04 (Double Spend Lock):** Añadir `guard !isProcessing else { return false }` al inicio de `PaymentManager.sendMoney` para bloquear concurrencia. *(Estado actual: ❌ PENDIENTE)*
- [ ] **Fix BUG-06 (Keypad Internationalization):** Refactorizar `TransferViewModel` para trabajar con centavos enteros (`Int`) en lugar de manipulación de cadenas con coma flotante `Double`. *(Estado actual: ❌ PENDIENTE)*
- [ ] **Fix PRF-01 (DateFormatter Allocations):** Extraer los `DateFormatter` a propiedades estáticas en `Transaction.swift` / `CurrencyFormatter.swift` para eliminar caídas de FPS en scroll. *(Estado actual: ❌ PENDIENTE)*
- [ ] **Fix PRF-02 (Grouping CPU Blocking):** Mover el agrupamiento $O(N \log N)$ de `HistoryView.body` hacia `HistoryViewModel`. *(Estado actual: ❌ PENDIENTE)*
- [ ] **Fix ARC-01 (State Sync):** Suscribir `HomeViewModel` via Combine a los editores `@Published` de `AuthManager` y `PaymentManager`. *(Estado actual: ❌ PENDIENTE)*

---

### FASE 3: Infraestructura Backend & Supabase Integration (Día 5-7)

- [ ] **Integrar Supabase SDK:** Reemplazar `login(username:password:)` simulado con Supabase Auth real.
- [ ] **Desplegar Database Schema:** Crear tablas PostgreSQL (`profiles`, `accounts`, `payment_methods`, `transactions`, `recurring_payments`) con RLS habilitado.
- [ ] **Edge Functions:** Implementar Stripe Payment Intents y Webhooks en Supabase Edge Functions.
