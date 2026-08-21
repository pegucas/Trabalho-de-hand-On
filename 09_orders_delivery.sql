-- =========================================================
-- 09. Pedidos e Entrega — Última Milha (schema commerce)
-- =========================================================

CREATE TABLE commerce.orders (
    id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subscription_id      UUID REFERENCES commerce.subscriptions(id),   -- nulo se compra avulsa
    patient_id           UUID NOT NULL REFERENCES pii.patients(id),
    pharmacy_id          UUID NOT NULL REFERENCES partners.pharmacies(id),
    status               commerce.order_status NOT NULL DEFAULT 'pending',
    total_amount_cents   INTEGER NOT NULL CHECK (total_amount_cents >= 0),
    created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE commerce.order_items (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id            UUID NOT NULL REFERENCES commerce.orders(id) ON DELETE CASCADE,
    product_id          UUID NOT NULL REFERENCES catalog.products(id),
    quantity            INTEGER NOT NULL CHECK (quantity > 0),
    unit_price_cents    INTEGER NOT NULL CHECK (unit_price_cents >= 0)
);

CREATE TABLE commerce.deliveries (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id         UUID NOT NULL UNIQUE REFERENCES commerce.orders(id) ON DELETE CASCADE,
    address_id       UUID NOT NULL REFERENCES pii.addresses(id),
    courier_partner  TEXT,
    tracking_code    TEXT,
    estimated_at     TIMESTAMPTZ,
    delivered_at     TIMESTAMPTZ,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE commerce.delivery_tracking_events (
    id            BIGSERIAL PRIMARY KEY,
    delivery_id   UUID NOT NULL REFERENCES commerce.deliveries(id) ON DELETE CASCADE,
    status        TEXT NOT NULL,     -- 'coletado','em_rota','entregue','tentativa_falha'
    occurred_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    lat           NUMERIC(9,6),
    lng           NUMERIC(9,6)
);

CREATE INDEX idx_orders_patient ON commerce.orders (patient_id);
CREATE INDEX idx_orders_pharmacy_status ON commerce.orders (pharmacy_id, status);
CREATE INDEX idx_delivery_tracking_delivery ON commerce.delivery_tracking_events (delivery_id, occurred_at);
