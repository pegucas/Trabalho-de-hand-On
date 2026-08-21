-- =========================================================
-- 13. Auditoria (schema audit)
-- =========================================================
-- Toda tabela sensível grava o estado anterior e novo em
-- audit.audit_log. Essencial para investigar incidentes e para
-- demonstrar conformidade com a LGPD (rastreabilidade de quem
-- acessou/alterou dado pessoal ou de saúde).

CREATE TABLE audit.audit_log (
    id           BIGSERIAL PRIMARY KEY,
    table_name   TEXT NOT NULL,
    record_id    TEXT NOT NULL,
    action       TEXT NOT NULL,        -- 'INSERT', 'UPDATE', 'DELETE'
    old_data     JSONB,
    new_data     JSONB,
    changed_by   TEXT DEFAULT current_setting('app.current_user_id', true),
    changed_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION audit.fn_audit_trigger()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO audit.audit_log (table_name, record_id, action, old_data, new_data)
    VALUES (
        TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME,
        COALESCE(NEW.id::TEXT, OLD.id::TEXT),
        TG_OP,
        CASE WHEN TG_OP IN ('UPDATE','DELETE') THEN to_jsonb(OLD) ELSE NULL END,
        CASE WHEN TG_OP IN ('UPDATE','INSERT') THEN to_jsonb(NEW) ELSE NULL END
    );
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Aplicar em todas as tabelas com dado sensível
CREATE TRIGGER trg_audit_patients
    AFTER INSERT OR UPDATE OR DELETE ON pii.patients
    FOR EACH ROW EXECUTE FUNCTION audit.fn_audit_trigger();

CREATE TRIGGER trg_audit_patient_documents
    AFTER INSERT OR UPDATE OR DELETE ON pii.patient_documents
    FOR EACH ROW EXECUTE FUNCTION audit.fn_audit_trigger();

CREATE TRIGGER trg_audit_addresses
    AFTER INSERT OR UPDATE OR DELETE ON pii.addresses
    FOR EACH ROW EXECUTE FUNCTION audit.fn_audit_trigger();

CREATE TRIGGER trg_audit_prescriptions
    AFTER INSERT OR UPDATE OR DELETE ON clinical.prescriptions
    FOR EACH ROW EXECUTE FUNCTION audit.fn_audit_trigger();

CREATE TRIGGER trg_audit_payment_methods
    AFTER INSERT OR UPDATE OR DELETE ON commerce.payment_methods
    FOR EACH ROW EXECUTE FUNCTION audit.fn_audit_trigger();

CREATE INDEX idx_audit_log_table_record ON audit.audit_log (table_name, record_id, changed_at DESC);
