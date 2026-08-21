-- =========================================================
-- 05. Catálogo de Produtos (schema catalog)
-- =========================================================
-- Inclui medicamentos de prescrição, isentos de prescrição
-- (OTC) e a linha "Mente Leve" (fitoterápicos/naturais)
-- descrita no pitch.

CREATE TABLE catalog.product_categories (
    id            SMALLSERIAL PRIMARY KEY,
    name          TEXT NOT NULL UNIQUE,        -- 'Mente Leve', 'Cardiovascular', etc.
    product_type  catalog.product_type NOT NULL,
    description   TEXT
);

CREATE TABLE catalog.products (
    id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category_id                 SMALLINT NOT NULL REFERENCES catalog.product_categories(id),
    sku                         TEXT NOT NULL UNIQUE,
    name                        TEXT NOT NULL,
    description                 TEXT,
    active_ingredient           TEXT,
    product_type                catalog.product_type NOT NULL,
    requires_prescription       BOOLEAN NOT NULL DEFAULT false,
    anvisa_registration_number  TEXT,          -- obrigatório também para fitoterápicos regularizados
    unit_price_cents            INTEGER NOT NULL CHECK (unit_price_cents >= 0),
    is_active                   BOOLEAN NOT NULL DEFAULT true,
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Segurança clínica: produto natural vendido junto de
-- medicamento de prescrição pode gerar interação. Esta tabela
-- permite o sistema bloquear/alertar combinações perigosas
-- (ex.: fitoterápico x anticoagulante) antes do checkout.
CREATE TABLE catalog.product_interactions (
    product_id_a  UUID NOT NULL REFERENCES catalog.products(id) ON DELETE CASCADE,
    product_id_b  UUID NOT NULL REFERENCES catalog.products(id) ON DELETE CASCADE,
    severity      TEXT NOT NULL CHECK (severity IN ('leve', 'moderada', 'grave')),
    description   TEXT NOT NULL,
    PRIMARY KEY (product_id_a, product_id_b),
    CHECK (product_id_a <> product_id_b)
);

CREATE INDEX idx_products_category ON catalog.products (category_id);
CREATE INDEX idx_products_name_trgm ON catalog.products USING gin (name gin_trgm_ops);
CREATE INDEX idx_products_type ON catalog.products (product_type) WHERE is_active = true;
