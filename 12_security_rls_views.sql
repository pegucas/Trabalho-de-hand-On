-- =========================================================
-- 12. Row-Level Security, Views Seguras e Papéis de Acesso
-- =========================================================
-- ATENÇÃO: em produção, use um script de migração que checa
-- se o role já existe (DO $$ ... EXCEPTION WHEN duplicate_object)
-- antes de rodar CREATE ROLE — aqui está simplificado para fins
-- de documentação da estrutura.

CREATE ROLE app_readonly NOLOGIN;
CREATE ROLE app_write NOLOGIN;
CREATE ROLE app_admin NOLOGIN;
CREATE ROLE app_pharmacy_staff NOLOGIN;

-- ---------------------------------------------------------
-- Por padrão, ninguém enxerga nada. Acesso é concedido
-- explicitamente — princípio do menor privilégio. Isso é a
-- defesa de banco contra SQL injection: mesmo que uma query
-- maliciosa passe pela aplicação, a role conectada só alcança
-- o que foi explicitamente liberado aqui.
-- ---------------------------------------------------------
REVOKE ALL ON ALL TABLES IN SCHEMA pii, clinical, commerce FROM PUBLIC;

GRANT USAGE ON SCHEMA auth, pii, clinical, catalog, partners, commerce, engagement
    TO app_write, app_admin;

GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA commerce TO app_write;
GRANT SELECT ON ALL TABLES IN SCHEMA catalog TO app_readonly, app_write, app_pharmacy_staff;
GRANT ALL ON ALL TABLES IN SCHEMA pii, clinical TO app_admin;

-- app_pharmacy_staff precisa de GRANT explícito nas tabelas
-- além da política de RLS: RLS filtra LINHAS, mas sem o GRANT
-- de tabela o acesso já é negado antes mesmo de a política ser
-- avaliada. Aqui o escopo fica restrito ao paciente/endereço
-- ligado a algum pedido daquela farmácia (garantido pela policy).
GRANT USAGE ON SCHEMA pii TO app_pharmacy_staff;
GRANT SELECT ON pii.patients TO app_pharmacy_staff;
GRANT SELECT ON pii.addresses TO app_pharmacy_staff;
GRANT SELECT, UPDATE ON commerce.orders, commerce.deliveries TO app_pharmacy_staff;
GRANT SELECT, UPDATE ON partners.pharmacy_inventory TO app_pharmacy_staff;

-- ---------------------------------------------------------
-- Row-Level Security nas tabelas com dado sensível
-- ---------------------------------------------------------
ALTER TABLE pii.patients ENABLE ROW LEVEL SECURITY;
ALTER TABLE pii.patient_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE pii.addresses ENABLE ROW LEVEL SECURITY;
ALTER TABLE clinical.prescriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE commerce.payment_methods ENABLE ROW LEVEL SECURITY;

-- Paciente só enxerga o próprio registro
CREATE POLICY patient_self_access ON pii.patients
    USING (user_id = current_setting('app.current_user_id')::uuid);

-- Farmácia só enxerga paciente com pedido/assinatura ativa nela
-- (nunca a base inteira de pacientes da Eurofarma)
CREATE POLICY pharmacy_scoped_access ON pii.patients
    FOR SELECT
    TO app_pharmacy_staff
    USING (
        EXISTS (
            SELECT 1 FROM commerce.orders o
            WHERE o.patient_id = pii.patients.id
              AND o.pharmacy_id = current_setting('app.current_pharmacy_id')::uuid
        )
    );

-- Documentos (CPF/RG) seguem o mesmo escopo do paciente dono
CREATE POLICY patient_documents_owner_access ON pii.patient_documents
    USING (
        patient_id IN (
            SELECT id FROM pii.patients
            WHERE user_id = current_setting('app.current_user_id')::uuid
        )
    );

-- Endereço: paciente vê o próprio; farmácia só vê o endereço
-- de entrega de um pedido/entrega dela (nunca a lista completa
-- de endereços de um paciente).
CREATE POLICY address_patient_self_access ON pii.addresses
    FOR ALL
    USING (
        owner_type = 'patient' AND owner_id IN (
            SELECT id FROM pii.patients
            WHERE user_id = current_setting('app.current_user_id')::uuid
        )
    );

CREATE POLICY address_pharmacy_delivery_access ON pii.addresses
    FOR SELECT
    TO app_pharmacy_staff
    USING (
        EXISTS (
            SELECT 1 FROM commerce.deliveries d
            JOIN commerce.orders o ON o.id = d.order_id
            WHERE d.address_id = pii.addresses.id
              AND o.pharmacy_id = current_setting('app.current_pharmacy_id')::uuid
        )
    );

-- Prescrição: paciente vê a própria; farmacêutico responsável
-- pela validação também tem acesso (necessário para conferir
-- a receita antes de liberar o medicamento).
CREATE POLICY prescription_patient_self_access ON clinical.prescriptions
    USING (
        patient_id IN (
            SELECT id FROM pii.patients
            WHERE user_id = current_setting('app.current_user_id')::uuid
        )
    );

CREATE POLICY prescription_pharmacist_validation_access ON clinical.prescriptions
    FOR SELECT
    TO app_pharmacy_staff
    USING (validated_by = current_setting('app.current_user_id')::uuid);

-- Meio de pagamento: NUNCA visível para farmácia — só o
-- próprio paciente e a role de admin (que já tem GRANT ALL).
CREATE POLICY payment_method_patient_self_access ON commerce.payment_methods
    USING (
        patient_id IN (
            SELECT id FROM pii.patients
            WHERE user_id = current_setting('app.current_user_id')::uuid
        )
    );

-- ---------------------------------------------------------
-- View "segura": expõe apenas o necessário para operação do
-- dia a dia (ex.: atendimento, logística), sem CPF/RG/e-mail
-- em claro.
-- ---------------------------------------------------------
CREATE VIEW pii.patients_safe_view AS
SELECT
    id,
    full_name,
    birth_date,
    created_at
FROM pii.patients
WHERE deleted_at IS NULL;

GRANT SELECT ON pii.patients_safe_view TO app_pharmacy_staff;
