-- =========================================================
-- 06. Farmácias Parceiras — "Centros de Distribuição"
-- (schema partners)
-- =========================================================

CREATE TABLE partners.pharmacies (
    id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    legal_name               TEXT NOT NULL,
    trade_name               TEXT NOT NULL,
    cnpj_encrypted           BYTEA NOT NULL,
    cnpj_lookup_hash         TEXT NOT NULL UNIQUE,
    anvisa_license_number    TEXT NOT NULL,
    is_active                BOOLEAN NOT NULL DEFAULT true,
    integration_sla_minutes  SMALLINT DEFAULT 60,   -- meta de "última milha" citada no pitch
    created_at               TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE partners.pharmacy_staff (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pharmacy_id  UUID NOT NULL REFERENCES partners.pharmacies(id) ON DELETE CASCADE,
    user_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    job_title    TEXT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (pharmacy_id, user_id)
);

CREATE TABLE partners.pharmacy_inventory (
    pharmacy_id     UUID NOT NULL REFERENCES partners.pharmacies(id) ON DELETE CASCADE,
    product_id      UUID NOT NULL REFERENCES catalog.products(id) ON DELETE CASCADE,
    stock_quantity  INTEGER NOT NULL DEFAULT 0 CHECK (stock_quantity >= 0),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (pharmacy_id, product_id)
);

-- Agora que partners.pharmacies existe, liga o trigger de
-- validação de owner_id criado em 04_addresses.sql
CREATE TRIGGER trg_validate_address_owner
    BEFORE INSERT OR UPDATE ON pii.addresses
    FOR EACH ROW EXECUTE FUNCTION pii.fn_validate_address_owner();

CREATE INDEX idx_pharmacy_staff_pharmacy ON partners.pharmacy_staff (pharmacy_id);
CREATE INDEX idx_pharmacy_inventory_product ON partners.pharmacy_inventory (product_id);
