-- =========================================================
-- 08. Assinaturas de Tratamento Contínuo (schema commerce)
-- =========================================================

CREATE TABLE commerce.subscriptions (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id            UUID NOT NULL REFERENCES pii.patients(id),
    pharmacy_id           UUID NOT NULL REFERENCES partners.pharmacies(id),
    status                commerce.subscription_status NOT NULL DEFAULT 'active',
    frequency_days        SMALLINT NOT NULL DEFAULT 30,
    next_renewal_date     DATE NOT NULL,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    cancelled_at          TIMESTAMPTZ,
    cancellation_reason   TEXT       -- registra o motivo real de evasão, não assume "zero" por design
);

CREATE TABLE commerce.subscription_items (
    id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subscription_id        UUID NOT NULL REFERENCES commerce.subscriptions(id) ON DELETE CASCADE,
    product_id             UUID NOT NULL REFERENCES catalog.products(id),
    prescription_item_id   UUID REFERENCES clinical.prescription_items(id),
    quantity                INTEGER NOT NULL CHECK (quantity > 0)
);

-- Regra de negócio crítica: produto com requires_prescription = true
-- só pode entrar numa assinatura se houver prescription_item_id.
-- Validado aqui via trigger — não depender apenas do front-end.
CREATE OR REPLACE FUNCTION commerce.fn_validate_subscription_item()
RETURNS TRIGGER AS $$
DECLARE
    needs_prescription BOOLEAN;
BEGIN
    SELECT requires_prescription INTO needs_prescription
    FROM catalog.products WHERE id = NEW.product_id;

    IF needs_prescription AND NEW.prescription_item_id IS NULL THEN
        RAISE EXCEPTION
            'Produto % exige prescrição válida para entrar em uma assinatura', NEW.product_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validate_subscription_item
    BEFORE INSERT OR UPDATE ON commerce.subscription_items
    FOR EACH ROW EXECUTE FUNCTION commerce.fn_validate_subscription_item();

CREATE TABLE commerce.subscription_events (
    id               BIGSERIAL PRIMARY KEY,
    subscription_id  UUID NOT NULL REFERENCES commerce.subscriptions(id) ON DELETE CASCADE,
    event_type       TEXT NOT NULL,   -- 'created','paused','resumed','cancelled','renewal_failed'
    occurred_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    metadata         JSONB
);

CREATE INDEX idx_subscriptions_patient ON commerce.subscriptions (patient_id);
CREATE INDEX idx_subscriptions_next_renewal
    ON commerce.subscriptions (next_renewal_date) WHERE status = 'active';
