-- =========================================================
-- 02. Autenticação e Controle de Acesso (schema auth)
-- =========================================================
-- Regra geral: NENHUMA senha em texto puro chega ao banco.
-- O hash (Argon2id) é calculado na camada de aplicação;
-- o banco apenas armazena e compara hashes.

CREATE TABLE auth.users (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- E-mail é dado pessoal (LGPD). Guardamos criptografado e
    -- um hash determinístico (HMAC) apenas para permitir
    -- busca/login sem expor o valor em claro em índices.
    email_encrypted       BYTEA NOT NULL,
    email_lookup_hash     TEXT  NOT NULL UNIQUE,     -- HMAC-SHA256(email, pepper) usado no login

    password_hash         TEXT NOT NULL,             -- Argon2id, gerado na aplicação
    password_updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),

    mfa_enabled            BOOLEAN NOT NULL DEFAULT false,
    mfa_secret_encrypted    BYTEA,

    status                 auth.user_status NOT NULL DEFAULT 'pending_verification',
    failed_login_count      SMALLINT NOT NULL DEFAULT 0,
    locked_until            TIMESTAMPTZ,

    created_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at              TIMESTAMPTZ                  -- soft delete p/ direito ao esquecimento (LGPD)
);

COMMENT ON COLUMN auth.users.email_encrypted IS
    'pgp_sym_encrypt(email, chave_gerenciada_por_KMS) — nunca em texto puro';
COMMENT ON COLUMN auth.users.password_hash IS
    'Hash Argon2id calculado pela aplicação. O banco nunca recebe a senha em claro';

-- ---------------------------------------------------------
-- RBAC — papéis e permissões
-- ---------------------------------------------------------
CREATE TABLE auth.roles (
    id          SMALLSERIAL PRIMARY KEY,
    name        TEXT NOT NULL UNIQUE,   -- 'patient', 'pharmacy_staff', 'support', 'admin'
    description TEXT
);

CREATE TABLE auth.permissions (
    id          SMALLSERIAL PRIMARY KEY,
    code        TEXT NOT NULL UNIQUE,   -- 'patients.read_pii', 'orders.write', etc.
    description TEXT
);

CREATE TABLE auth.role_permissions (
    role_id       SMALLINT NOT NULL REFERENCES auth.roles(id) ON DELETE CASCADE,
    permission_id SMALLINT NOT NULL REFERENCES auth.permissions(id) ON DELETE CASCADE,
    PRIMARY KEY (role_id, permission_id)
);

CREATE TABLE auth.user_roles (
    user_id UUID     NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    role_id SMALLINT NOT NULL REFERENCES auth.roles(id) ON DELETE CASCADE,
    PRIMARY KEY (user_id, role_id)
);

-- ---------------------------------------------------------
-- Sessões e recuperação de senha
-- ---------------------------------------------------------
CREATE TABLE auth.sessions (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    refresh_token_hash  TEXT NOT NULL UNIQUE,   -- nunca o token em claro
    ip_address          INET,
    user_agent          TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at          TIMESTAMPTZ NOT NULL,
    revoked_at          TIMESTAMPTZ
);

CREATE TABLE auth.password_reset_tokens (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    token_hash  TEXT NOT NULL UNIQUE,
    expires_at  TIMESTAMPTZ NOT NULL,
    used_at     TIMESTAMPTZ,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------
-- Auditoria de login — essencial para detectar força bruta
-- e acessos anômalos
-- ---------------------------------------------------------
CREATE TABLE auth.login_audit_log (
    id          BIGSERIAL PRIMARY KEY,
    user_id     UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    event_type  TEXT NOT NULL,   -- 'login_success','login_failed','password_reset','mfa_failed'
    ip_address  INET,
    user_agent  TEXT,
    success     BOOLEAN NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_login_audit_user_date ON auth.login_audit_log (user_id, created_at DESC);
CREATE INDEX idx_sessions_user ON auth.sessions (user_id) WHERE revoked_at IS NULL;
