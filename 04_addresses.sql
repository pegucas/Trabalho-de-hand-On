-- =========================================================
-- 04. Endereços (schema pii)
-- =========================================================
-- Compartilhada entre pacientes e farmácias parceiras via
-- owner_type/owner_id (polimorfismo simples). Endereço é dado
-- pessoal sensível quando ligado a um paciente identificável —
-- tratado com o mesmo rigor do CPF.

CREATE TABLE pii.addresses (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_type       pii.owner_type NOT NULL,
    owner_id         UUID NOT NULL,          -- referencia patients.id OU pharmacies.id

    street_encrypted BYTEA NOT NULL,
    number           TEXT NOT NULL,
    complement       TEXT,
    neighborhood     TEXT,
    city             TEXT NOT NULL,
    state            CHAR(2) NOT NULL,
    zip_code         TEXT NOT NULL,          -- CEP: necessário para roteamento logístico, risco isolado baixo

    is_primary       BOOLEAN NOT NULL DEFAULT true,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Como owner_id não tem uma única tabela de referência (é
-- patients OU pharmacies), a integridade é garantida por
-- trigger/aplicação, não por FK simples. Exemplo de trigger:
CREATE OR REPLACE FUNCTION pii.fn_validate_address_owner()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.owner_type = 'patient' AND NOT EXISTS (
        SELECT 1 FROM pii.patients WHERE id = NEW.owner_id
    ) THEN
        RAISE EXCEPTION 'owner_id % não corresponde a um paciente existente', NEW.owner_id;
    END IF;

    IF NEW.owner_type = 'pharmacy' AND NOT EXISTS (
        SELECT 1 FROM partners.pharmacies WHERE id = NEW.owner_id
    ) THEN
        RAISE EXCEPTION 'owner_id % não corresponde a uma farmácia existente', NEW.owner_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- O trigger é criado em 06_pharmacies_partners.sql, depois que
-- partners.pharmacies já existir.

CREATE INDEX idx_addresses_owner ON pii.addresses (owner_type, owner_id);
CREATE INDEX idx_addresses_zip ON pii.addresses (zip_code);
