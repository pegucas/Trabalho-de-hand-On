-- =========================================================
-- Eurofarma App B2B2C — 01. Extensões, Schemas e Tipos
-- =========================================================
-- Executar PRIMEIRO. Habilita extensões necessárias para
-- UUID, criptografia e busca, e cria os schemas por domínio
-- que permitem GRANT/REVOKE granular (menor privilégio).

CREATE EXTENSION IF NOT EXISTS pgcrypto;   -- gen_random_uuid(), pgp_sym_encrypt/decrypt, digest()
CREATE EXTENSION IF NOT EXISTS citext;     -- comparação case-insensitive
CREATE EXTENSION IF NOT EXISTS pg_trgm;    -- busca fuzzy (nomes de produtos, farmácias)

-- ---------------------------------------------------------
-- Schemas por domínio
-- ---------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS auth;         -- autenticação e controle de acesso
CREATE SCHEMA IF NOT EXISTS pii;          -- dados pessoais sensíveis (CPF, RG, endereço)
CREATE SCHEMA IF NOT EXISTS clinical;     -- dados de saúde (prescrições)
CREATE SCHEMA IF NOT EXISTS catalog;      -- catálogo de produtos
CREATE SCHEMA IF NOT EXISTS partners;     -- farmácias parceiras
CREATE SCHEMA IF NOT EXISTS commerce;     -- assinaturas, pedidos, pagamentos
CREATE SCHEMA IF NOT EXISTS engagement;   -- notificações e assistente de IA
CREATE SCHEMA IF NOT EXISTS audit;        -- trilha de auditoria

-- ---------------------------------------------------------
-- ENUMs reutilizados entre tabelas
-- ---------------------------------------------------------
CREATE TYPE auth.user_status AS ENUM
    ('active', 'suspended', 'pending_verification', 'deleted');

CREATE TYPE pii.document_type AS ENUM
    ('CPF', 'RG', 'CNPJ');

CREATE TYPE pii.owner_type AS ENUM
    ('patient', 'pharmacy');

CREATE TYPE catalog.product_type AS ENUM
    ('medicamento_prescricao', 'medicamento_isento', 'fitoterapico_natural');

CREATE TYPE commerce.subscription_status AS ENUM
    ('active', 'paused', 'cancelled', 'payment_failed');

CREATE TYPE commerce.order_status AS ENUM
    ('pending', 'confirmed', 'separating', 'out_for_delivery', 'delivered', 'cancelled');

CREATE TYPE commerce.payment_status AS ENUM
    ('authorized', 'captured', 'failed', 'refunded');

CREATE TYPE engagement.notification_channel AS ENUM
    ('push', 'sms', 'email', 'whatsapp');
