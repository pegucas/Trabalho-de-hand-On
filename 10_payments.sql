-- =========================================================
-- 10. Pagamentos (schema commerce)
-- =========================================================
-- Conformidade PCI-DSS: NUNCA armazenar número completo de
-- cartão, CVV ou trilha magnética. Apenas o token retornado
-- pelo gateway (Stripe, Pagar.me, etc.) e os últimos 4 dígitos
-- para exibição ao usuário.

CREATE TABLE commerce.payment_methods (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id         UUID NOT NULL REFERENCES pii.patients(id),
    gateway_provider   TEXT NOT NULL,      -- 'stripe', 'pagarme', etc.
    gateway_token      TEXT NOT NULL,      -- token opaco do gateway, não dado de cartão
    brand              TEXT,
    last4              CHAR(4),
    expiry_month       SMALLINT,
    expiry_year        SMALLINT,
    is_default         BOOLEAN NOT NULL DEFAULT false,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE commerce.transactions (
    id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id                 UUID REFERENCES commerce.orders(id),
    payment_method_id        UUID NOT NULL REFERENCES commerce.payment_methods(id),
    amount_cents             INTEGER NOT NULL CHECK (amount_cents >= 0),
    status                   commerce.payment_status NOT NULL,
    gateway_transaction_id   TEXT NOT NULL UNIQUE,
    created_at               TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE commerce.invoices (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_id  UUID NOT NULL REFERENCES commerce.transactions(id),
    invoice_number  TEXT NOT NULL UNIQUE,
    issued_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    pdf_ref         TEXT     -- referência ao arquivo em storage, nunca o binário
);

CREATE INDEX idx_transactions_order ON commerce.transactions (order_id);
CREATE INDEX idx_payment_methods_patient ON commerce.payment_methods (patient_id);
