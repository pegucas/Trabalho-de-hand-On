-- =========================================================
-- 11. Notificações e Assistente de IA (schema engagement)
-- =========================================================
-- Esta é a área mais relevante para "prompt injection" de
-- fato: qualquer texto livre digitado por um usuário (ou vindo
-- de um campo de produto) que possa alimentar um prompt de
-- LLM precisa ser tratado como DADO, nunca como INSTRUÇÃO.

-- Templates com placeholders nomeados: a mensagem enviada
-- NUNCA é montada por concatenação de string no código da
-- aplicação. O bind de parâmetros funciona como em uma query
-- SQL preparada — texto de usuário nunca vira comando dentro
-- do template.
CREATE TABLE engagement.notification_templates (
    id             SMALLSERIAL PRIMARY KEY,
    code           TEXT NOT NULL UNIQUE,      -- 'reminder_refill_3d', 'subscription_renewed'
    channel        engagement.notification_channel NOT NULL,
    body_template  TEXT NOT NULL,             -- ex: 'Olá {{first_name}}, seu {{product_name}} chega em {{eta}}'
    is_active      BOOLEAN NOT NULL DEFAULT true
);

CREATE TABLE engagement.notifications_log (
    id               BIGSERIAL PRIMARY KEY,
    patient_id       UUID NOT NULL REFERENCES pii.patients(id),
    template_code    TEXT NOT NULL REFERENCES engagement.notification_templates(code),
    channel          engagement.notification_channel NOT NULL,
    sent_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    delivery_status  TEXT
);

-- Log do "algoritmo que mapeia a rotina do usuário" citado no
-- pitch, caso seja implementado com um LLM. Guarda o input já
-- sanitizado (nunca o prompt de sistema completo) e sinaliza
-- tentativas suspeitas de injeção para revisão humana.
--
-- Regra de aplicação que este schema pressupõe: qualquer ação
-- real sugerida pela IA (ex.: "reabastecer automaticamente")
-- passa pelas regras de negócio normais (as tabelas de
-- commerce.*) antes de virar pedido de verdade. O output do
-- modelo nunca executa uma ação diretamente no banco.
CREATE TABLE engagement.ai_assistant_interactions (
    id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id                  UUID NOT NULL REFERENCES pii.patients(id),
    session_id                  UUID NOT NULL,
    user_input_sanitized        TEXT NOT NULL,   -- delimitado/escapado antes de ir para o prompt
    model_used                  TEXT NOT NULL,
    output_text                 TEXT,
    flagged_injection_attempt   BOOLEAN NOT NULL DEFAULT false,
    reviewed_by                 UUID REFERENCES auth.users(id),
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_ai_interactions_flagged
    ON engagement.ai_assistant_interactions (flagged_injection_attempt)
    WHERE flagged_injection_attempt = true;

CREATE INDEX idx_ai_interactions_patient ON engagement.ai_assistant_interactions (patient_id, created_at DESC);
