-- =========================================================
-- 03. Pacientes e Documentos Sensíveis (schema pii)
-- =========================================================
-- Isolado em schema próprio para permitir GRANT restrito: só
-- as roles/serviços que realmente precisam de CPF/RG devem
-- ter acesso a este schema (ver 12_security_rls_views.sql).

CREATE TABLE pii.patients (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,

    full_name       TEXT NOT NULL,
    birth_date      DATE NOT NULL,
    phone_encrypted BYTEA,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at      TIMESTAMPTZ
);

-- Documentos em tabela separada da tabela principal de
-- pacientes: reduz o "blast radius" caso algum JOIN/relatório
-- mal escrito acabe expondo pii.patients por engano.
CREATE TABLE pii.patient_documents (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id        UUID NOT NULL REFERENCES pii.patients(id) ON DELETE CASCADE,
    document_type     pii.document_type NOT NULL,
    value_encrypted   BYTEA NOT NULL,     -- pgp_sym_encrypt(cpf/rg, chave_KMS)
    lookup_hash       TEXT NOT NULL,      -- HMAC(valor, pepper) — checa duplicidade sem decriptar
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (document_type, lookup_hash)
);

-- Consentimento LGPD: obrigatório registrar a base legal para
-- tratar dado de saúde (art. 11 da LGPD) e permitir revogação.
CREATE TABLE pii.consent_records (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id            UUID NOT NULL REFERENCES pii.patients(id) ON DELETE CASCADE,
    purpose               TEXT NOT NULL,   -- 'processamento_dados_saude','marketing','recomendacao_mente_leve'
    granted_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    revoked_at            TIMESTAMPTZ,
    consent_text_version  TEXT NOT NULL    -- versão do termo aceito, para rastreabilidade
);

CREATE INDEX idx_patient_documents_patient ON pii.patient_documents (patient_id);
CREATE INDEX idx_consent_patient_purpose ON pii.consent_records (patient_id, purpose);
