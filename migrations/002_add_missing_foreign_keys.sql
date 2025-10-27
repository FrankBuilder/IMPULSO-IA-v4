-- ============================================================================
-- Migration: Add Missing Foreign Keys
-- Date: 2025-10-27
-- Description: Adds critical foreign keys identified in database audit
-- ============================================================================

-- IMPORTANTE: Execute essas queries UMA DE CADA VEZ para identificar problemas

-- ============================================================================
-- PARTE 1: followup_sequences.campaign_id
-- ============================================================================

-- Verificar se há registros órfãos ANTES de adicionar FK
-- SELECT COUNT(*) as orfaos
-- FROM corev4_followup_sequences fs
-- LEFT JOIN corev4_followup_campaigns fc ON fs.campaign_id = fc.id
-- WHERE fc.id IS NULL;

-- Se houver órfãos, você tem 3 opções:
-- OPÇÃO A: Deletar registros órfãos
-- DELETE FROM corev4_followup_sequences
-- WHERE campaign_id NOT IN (SELECT id FROM corev4_followup_campaigns);

-- OPÇÃO B: Atribuir a uma campanha padrão
-- UPDATE corev4_followup_sequences
-- SET campaign_id = (SELECT id FROM corev4_followup_campaigns LIMIT 1)
-- WHERE campaign_id NOT IN (SELECT id FROM corev4_followup_campaigns);

-- OPÇÃO C: Criar campanhas "placeholder" para os órfãos
-- (Não recomendado, mas evita perda de dados)

-- Adicionar Foreign Key
ALTER TABLE corev4_followup_sequences
ADD CONSTRAINT fk_sequences_campaign
FOREIGN KEY (campaign_id)
REFERENCES corev4_followup_campaigns(id)
ON DELETE CASCADE;

-- Criar índice
CREATE INDEX IF NOT EXISTS idx_followup_sequences_campaign_id
ON corev4_followup_sequences(campaign_id);

-- ============================================================================
-- PARTE 2: followup_stage_history.followup_execution_id
-- ============================================================================

-- Verificar órfãos
-- SELECT COUNT(*) as orfaos
-- FROM corev4_followup_stage_history fsh
-- LEFT JOIN corev4_followup_executions fe ON fsh.followup_execution_id = fe.id
-- WHERE fe.id IS NULL;

-- Limpar órfãos (se houver)
-- DELETE FROM corev4_followup_stage_history
-- WHERE followup_execution_id NOT IN (SELECT id FROM corev4_followup_executions);

-- Adicionar Foreign Key
ALTER TABLE corev4_followup_stage_history
ADD CONSTRAINT fk_stage_history_execution
FOREIGN KEY (followup_execution_id)
REFERENCES corev4_followup_executions(id)
ON DELETE CASCADE;

-- Criar índice
CREATE INDEX IF NOT EXISTS idx_stage_history_execution_id
ON corev4_followup_stage_history(followup_execution_id);

-- ============================================================================
-- PARTE 3: lead_state_backup - company_id
-- ============================================================================

-- Verificar órfãos
-- SELECT COUNT(*) as orfaos
-- FROM corev4_lead_state_backup lsb
-- LEFT JOIN corev4_companies c ON lsb.company_id = c.id
-- WHERE c.id IS NULL;

-- Limpar órfãos (CRÍTICO PARA SEGURANÇA)
-- DELETE FROM corev4_lead_state_backup
-- WHERE company_id NOT IN (SELECT id FROM corev4_companies);

-- Adicionar Foreign Key
ALTER TABLE corev4_lead_state_backup
ADD CONSTRAINT fk_lead_backup_company
FOREIGN KEY (company_id)
REFERENCES corev4_companies(id)
ON DELETE CASCADE;

-- Criar índice
CREATE INDEX IF NOT EXISTS idx_lead_backup_company_id
ON corev4_lead_state_backup(company_id);

-- ============================================================================
-- PARTE 4: lead_state_backup - contact_id
-- ============================================================================

-- Verificar órfãos
-- SELECT COUNT(*) as orfaos
-- FROM corev4_lead_state_backup lsb
-- LEFT JOIN corev4_contacts c ON lsb.contact_id = c.id
-- WHERE c.id IS NULL;

-- Limpar órfãos
-- DELETE FROM corev4_lead_state_backup
-- WHERE contact_id NOT IN (SELECT id FROM corev4_contacts);

-- Adicionar Foreign Key
ALTER TABLE corev4_lead_state_backup
ADD CONSTRAINT fk_lead_backup_contact
FOREIGN KEY (contact_id)
REFERENCES corev4_contacts(id)
ON DELETE CASCADE;

-- Criar índice composto (comum buscar backups por contato)
CREATE INDEX IF NOT EXISTS idx_lead_backup_contact_id
ON corev4_lead_state_backup(contact_id);

-- ============================================================================
-- PARTE 5: message_dedup - contact_id
-- ============================================================================

-- Verificar órfãos
-- SELECT COUNT(*) as orfaos
-- FROM corev4_message_dedup md
-- LEFT JOIN corev4_contacts c ON md.contact_id = c.id
-- WHERE c.id IS NULL;

-- Limpar órfãos
-- DELETE FROM corev4_message_dedup
-- WHERE contact_id NOT IN (SELECT id FROM corev4_contacts);

-- Adicionar Foreign Key
ALTER TABLE corev4_message_dedup
ADD CONSTRAINT fk_dedup_contact
FOREIGN KEY (contact_id)
REFERENCES corev4_contacts(id)
ON DELETE CASCADE;

-- Criar índice
CREATE INDEX IF NOT EXISTS idx_message_dedup_contact_id
ON corev4_message_dedup(contact_id);

-- ============================================================================
-- VERIFICAÇÃO FINAL
-- ============================================================================

-- Verificar todas as FKs adicionadas
-- SELECT
--   tc.table_name,
--   tc.constraint_name,
--   kcu.column_name,
--   ccu.table_name AS references_table,
--   ccu.column_name AS references_column
-- FROM information_schema.table_constraints tc
-- JOIN information_schema.key_column_usage kcu
--   ON tc.constraint_name = kcu.constraint_name
-- JOIN information_schema.constraint_column_usage ccu
--   ON tc.constraint_name = ccu.constraint_name
-- WHERE tc.constraint_type = 'FOREIGN KEY'
--   AND tc.table_name IN (
--     'corev4_followup_sequences',
--     'corev4_followup_stage_history',
--     'corev4_lead_state_backup',
--     'corev4_message_dedup'
--   )
-- ORDER BY tc.table_name, tc.constraint_name;

-- Contar FKs por tabela
-- SELECT
--   tc.table_name,
--   COUNT(*) as foreign_key_count
-- FROM information_schema.table_constraints tc
-- WHERE tc.constraint_type = 'FOREIGN KEY'
--   AND tc.table_schema = 'public'
-- GROUP BY tc.table_name
-- ORDER BY foreign_key_count DESC;

-- ============================================================================
-- ROLLBACK (se necessário)
-- ============================================================================
/*
-- Execute em ordem reversa:
ALTER TABLE corev4_message_dedup DROP CONSTRAINT IF EXISTS fk_dedup_contact;
DROP INDEX IF EXISTS idx_message_dedup_contact_id;

ALTER TABLE corev4_lead_state_backup DROP CONSTRAINT IF EXISTS fk_lead_backup_contact;
DROP INDEX IF EXISTS idx_lead_backup_contact_id;

ALTER TABLE corev4_lead_state_backup DROP CONSTRAINT IF EXISTS fk_lead_backup_company;
DROP INDEX IF EXISTS idx_lead_backup_company_id;

ALTER TABLE corev4_followup_stage_history DROP CONSTRAINT IF EXISTS fk_stage_history_execution;
DROP INDEX IF EXISTS idx_stage_history_execution_id;

ALTER TABLE corev4_followup_sequences DROP CONSTRAINT IF EXISTS fk_sequences_campaign;
DROP INDEX IF EXISTS idx_followup_sequences_campaign_id;
*/
