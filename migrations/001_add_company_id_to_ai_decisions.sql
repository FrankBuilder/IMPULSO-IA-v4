-- ============================================================================
-- Migration: Add company_id to corev4_ai_decisions
-- Date: 2025-10-27
-- Description: Adds multi-tenant isolation to AI decisions table
-- ============================================================================

-- IMPORTANTE: Execute essas queries em ordem sequencial, não todas de uma vez!

-- ============================================================================
-- ETAPA 1: Adicionar coluna como NULLABLE (permite dados existentes)
-- ============================================================================
ALTER TABLE corev4_ai_decisions
ADD COLUMN IF NOT EXISTS company_id UUID;

-- ============================================================================
-- ETAPA 2: Preencher company_id para registros existentes
-- ============================================================================
-- OPÇÃO A: Se ai_decisions está relacionada a followup_executions
UPDATE corev4_ai_decisions ad
SET company_id = fe.company_id
FROM corev4_followup_executions fe
WHERE ad.followup_execution_id = fe.id
  AND ad.company_id IS NULL;

-- OPÇÃO B: Se ainda houver registros NULL, atribuir a uma empresa padrão
-- (AVISO: Ajuste o UUID abaixo para uma empresa válida no seu sistema)
-- UPDATE corev4_ai_decisions
-- SET company_id = (SELECT id FROM corev4_companies LIMIT 1)
-- WHERE company_id IS NULL;

-- ============================================================================
-- ETAPA 3: Verificar se ainda há registros sem company_id
-- ============================================================================
-- Execute esta query para verificar:
-- SELECT COUNT(*) as registros_sem_company
-- FROM corev4_ai_decisions
-- WHERE company_id IS NULL;

-- Se retornar 0, pode prosseguir. Se retornar > 0, resolva primeiro!

-- ============================================================================
-- ETAPA 4: Tornar coluna obrigatória (NOT NULL)
-- ============================================================================
ALTER TABLE corev4_ai_decisions
ALTER COLUMN company_id SET NOT NULL;

-- ============================================================================
-- ETAPA 5: Adicionar Foreign Key
-- ============================================================================
ALTER TABLE corev4_ai_decisions
ADD CONSTRAINT fk_ai_decisions_company
FOREIGN KEY (company_id)
REFERENCES corev4_companies(id)
ON DELETE CASCADE;

-- ============================================================================
-- ETAPA 6: Criar índice para performance
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_ai_decisions_company_id
ON corev4_ai_decisions(company_id);

-- Índice composto para queries comuns
CREATE INDEX IF NOT EXISTS idx_ai_decisions_company_created
ON corev4_ai_decisions(company_id, created_at DESC);

-- ============================================================================
-- ETAPA 7: Habilitar Row Level Security (RLS)
-- ============================================================================
ALTER TABLE corev4_ai_decisions ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- ETAPA 8: Criar políticas RLS
-- ============================================================================

-- Política de SELECT: Usuários só veem decisões da sua empresa
DROP POLICY IF EXISTS "Users can view their company AI decisions" ON corev4_ai_decisions;
CREATE POLICY "Users can view their company AI decisions"
ON corev4_ai_decisions
FOR SELECT
USING (
  company_id IN (
    SELECT id FROM corev4_companies
    WHERE id = (current_setting('app.current_company_id', true))::uuid
  )
);

-- Política de INSERT: Usuários só podem criar decisões para sua empresa
DROP POLICY IF EXISTS "Users can insert AI decisions for their company" ON corev4_ai_decisions;
CREATE POLICY "Users can insert AI decisions for their company"
ON corev4_ai_decisions
FOR INSERT
WITH CHECK (
  company_id = (current_setting('app.current_company_id', true))::uuid
);

-- Política de UPDATE: Usuários só podem atualizar decisões da sua empresa
DROP POLICY IF EXISTS "Users can update their company AI decisions" ON corev4_ai_decisions;
CREATE POLICY "Users can update their company AI decisions"
ON corev4_ai_decisions
FOR UPDATE
USING (
  company_id = (current_setting('app.current_company_id', true))::uuid
)
WITH CHECK (
  company_id = (current_setting('app.current_company_id', true))::uuid
);

-- Política de DELETE: Usuários só podem deletar decisões da sua empresa
DROP POLICY IF EXISTS "Users can delete their company AI decisions" ON corev4_ai_decisions;
CREATE POLICY "Users can delete their company AI decisions"
ON corev4_ai_decisions
FOR DELETE
USING (
  company_id = (current_setting('app.current_company_id', true))::uuid
);

-- ============================================================================
-- ETAPA 9: Verificação final
-- ============================================================================
-- Execute essas queries para confirmar que tudo está OK:

-- Verificar estrutura
-- SELECT column_name, data_type, is_nullable
-- FROM information_schema.columns
-- WHERE table_name = 'corev4_ai_decisions'
-- AND column_name = 'company_id';

-- Verificar foreign key
-- SELECT
--   tc.constraint_name,
--   tc.table_name,
--   kcu.column_name,
--   ccu.table_name AS foreign_table_name,
--   ccu.column_name AS foreign_column_name
-- FROM information_schema.table_constraints AS tc
-- JOIN information_schema.key_column_usage AS kcu
--   ON tc.constraint_name = kcu.constraint_name
-- JOIN information_schema.constraint_column_usage AS ccu
--   ON ccu.constraint_name = tc.constraint_name
-- WHERE tc.table_name = 'corev4_ai_decisions'
--   AND tc.constraint_type = 'FOREIGN KEY';

-- Verificar RLS
-- SELECT tablename, rowsecurity
-- FROM pg_tables
-- WHERE tablename = 'corev4_ai_decisions';

-- Verificar políticas
-- SELECT policyname, cmd, qual, with_check
-- FROM pg_policies
-- WHERE tablename = 'corev4_ai_decisions';

-- ============================================================================
-- ROLLBACK (se necessário)
-- ============================================================================
-- USE COM CUIDADO! Isso remove todas as mudanças:
/*
DROP POLICY IF EXISTS "Users can delete their company AI decisions" ON corev4_ai_decisions;
DROP POLICY IF EXISTS "Users can update their company AI decisions" ON corev4_ai_decisions;
DROP POLICY IF EXISTS "Users can insert AI decisions for their company" ON corev4_ai_decisions;
DROP POLICY IF EXISTS "Users can view their company AI decisions" ON corev4_ai_decisions;
ALTER TABLE corev4_ai_decisions DISABLE ROW LEVEL SECURITY;
DROP INDEX IF EXISTS idx_ai_decisions_company_created;
DROP INDEX IF EXISTS idx_ai_decisions_company_id;
ALTER TABLE corev4_ai_decisions DROP CONSTRAINT IF EXISTS fk_ai_decisions_company;
ALTER TABLE corev4_ai_decisions DROP COLUMN IF EXISTS company_id;
*/
