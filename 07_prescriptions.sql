-- =========================================================
-- 07. Prescrições Médicas (schema clinical)
-- =========================================================
-- Dado de saúde é "dado sensível" pela LGPD (art. 5º, II).
-- Acesso deve ser restrito por RLS (ver 12) e todo acesso de
-- leitura deve ser auditado (ver 13).

CREATE TABLE clinical.prescriptions (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id          UUID NOT NULL REFERENCES pii.patients(id) ON DELETE CASCADE,
    doctor_name         TEXT NOT NULL,
    doctor_crm          TEXT NOT NULL,
    doctor_uf           CHAR(2) NOT NULL,
    issued_at           DATE NOT NULL,
    expires_at          DATE NOT NULL,
    document_file_ref   TEXT,      -- referência a objeto em storage criptografado (S3+KMS), nunca o arquivo em si
    validated           BOOLEAN NOT NULL DEFAULT false,
    validated_by        UUID REFERENCES auth.users(id),   -- farmacêutico responsável
    validated_at        TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

    CHECK (expires_at >= issued_at)
);

CREATE TABLE clinical.prescription_items (
    id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    prescription_id      UUID NOT NULL REFERENCES clinical.prescriptions(id) ON DELETE CASCADE,
    product_id           UUID NOT NULL REFERENCES catalog.products(id),
    dosage_instructions  TEXT NOT NULL,
    quantity             INTEGER NOT NULL CHECK (quantity > 0)
);

CREATE INDEX idx_prescriptions_patient ON clinical.prescriptions (patient_id);
CREATE INDEX idx_prescriptions_expiry ON clinical.prescriptions (expires_at) WHERE validated = true;
