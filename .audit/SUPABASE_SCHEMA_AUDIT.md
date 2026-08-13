# 🗄️ REPORTE Y ESPECIFICACIÓN DE SUPABASE SCHEMA & BACKEND INTEGRATION — POCKETPAY

**Fecha:** 10 de Agosto, 2026  
**Auditor Principal:** Antigravity Senior Security & Software Architect  
**Estado Actual:** 🔴 **INEXISTENTE / MOCK LOCAL UNICAMENTE**  

---

## 🎯 Diagnóstico y Necesidad de Backend

Actualmente PocketPay funciona como un cliente aislado con modelos estáticos en memoria. Para llevar la aplicación a nivel de producción seguro, se requiere una arquitectura basada en **Supabase (PostgreSQL + Auth + Edge Functions + RLS)** y Stripe para el procesamiento de pagos.

---

## 📐 Esquema de Base de Datos PostgreSQL Sugerido (Supabase)

```sql
-- 1. Habilitar extensión UUID
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. Tabla de Perfiles de Usuario (vinculada a auth.users de Supabase)
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT UNIQUE NOT NULL,
    full_name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    phone_number TEXT,
    mailing_address TEXT,
    avatar_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- 3. Tabla de Cuentas / Balances Financieros (Persistencia Transaccional)
CREATE TABLE public.accounts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    balance NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (balance >= 0.00),
    currency TEXT NOT NULL DEFAULT 'USD',
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- 4. Tabla de Métodos de Pago Guardados (Cifrado/Tokens de Stripe)
CREATE TABLE public.payment_methods (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    stripe_payment_method_id TEXT NOT NULL,
    card_brand TEXT NOT NULL,
    last4_digits VARCHAR(4) NOT NULL,
    expiry_date VARCHAR(5) NOT NULL,
    cardholder_name TEXT NOT NULL,
    color_theme TEXT NOT NULL DEFAULT 'purple',
    is_default BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- 5. Tabla de Transacciones (Ledger Inmutable)
CREATE TYPE transaction_type AS ENUM ('p2p', 'business', 'donation', 'account_transfer');
CREATE TYPE transaction_category AS ENUM ('utilities', 'rent', 'subscription', 'p2p', 'general');
CREATE TYPE transaction_status AS ENUM ('pending', 'completed', 'failed');

CREATE TABLE public.transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sender_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    recipient_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    recipient_name TEXT NOT NULL,
    recipient_phone TEXT,
    type transaction_type NOT NULL,
    category transaction_category NOT NULL,
    amount NUMERIC(12, 2) NOT NULL CHECK (amount > 0.00),
    status transaction_status NOT NULL DEFAULT 'pending',
    notes TEXT,
    is_incoming BOOLEAN NOT NULL DEFAULT false,
    stripe_payment_intent_id TEXT,
    recurring_payment_id UUID,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- 6. Tabla de Pagos Recurrentes / Servicios
CREATE TYPE payment_frequency AS ENUM ('weekly', 'biWeekly', 'monthly', 'quarterly', 'yearly');

CREATE TABLE public.recurring_payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    biller_name TEXT NOT NULL,
    amount NUMERIC(12, 2) NOT NULL CHECK (amount > 0.00),
    frequency payment_frequency NOT NULL,
    category transaction_category NOT NULL,
    next_payment_date DATE NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    auto_pay_enabled BOOLEAN NOT NULL DEFAULT false,
    last_payment_date TIMESTAMPTZ,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);
```

---

## 🔒 Políticas de Seguridad a Nivel de Fila (Row Level Security - RLS)

```sql
-- Habilitar RLS en todas las tablas
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_methods ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recurring_payments ENABLE ROW LEVEL SECURITY;

-- Políticas de Profiles
CREATE POLICY "Usuarios ven su propio perfil" ON public.profiles
    FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Usuarios actualizan su propio perfil" ON public.profiles
    FOR UPDATE USING (auth.uid() = id);

-- Políticas de Accounts
CREATE POLICY "Usuarios ven su propia cuenta" ON public.accounts
    FOR SELECT USING (auth.uid() = user_id);

-- Políticas de Payment Methods
CREATE POLICY "Usuarios gestionan sus métodos de pago" ON public.payment_methods
    FOR ALL USING (auth.uid() = user_id);

-- Políticas de Transactions
CREATE POLICY "Usuarios ven sus transacciones enviadas o recibidas" ON public.transactions
    FOR SELECT USING (auth.uid() = sender_id OR auth.uid() = recipient_id);

-- Políticas de Recurring Payments
CREATE POLICY "Usuarios gestionan sus servicios recurrentes" ON public.recurring_payments
    FOR ALL USING (auth.uid() = user_id);
```

---

## ⚡ Stripe & Supabase Edge Functions Requeridas

1. **`create-payment-intent`**: Function en Deno/Node.js que valida el token JWT del usuario de Supabase, instancia Stripe en el backend con la `STRIPE_SECRET_KEY` y retorna el `clientSecret` para la app iOS.
2. **`stripe-webhook`**: Endpoint que escucha eventos `payment_intent.succeeded` de Stripe y ejecuta una transacción atómica PostgreSQL (`BEGIN; UPDATE accounts... INSERT INTO transactions... COMMIT;`) asegurando idempotencia.
