# Database Migrations - IMPULSO-IA-v4

## Overview

Este diretório contém migrações SQL para corrigir problemas críticos identificados no audit do banco de dados.

## Ordem de Execução

**IMPORTANTE**: Execute as migrações na ordem listada abaixo.

### Phase 1: Immediate (Alta Prioridade)

#### 1. `001_add_company_id_to_ai_decisions.sql`
**Objetivo**: Adicionar isolamento multi-tenant à tabela `ai_decisions`

**Risco**: 🔴 CRÍTICO - Security issue, pode vazar dados entre empresas

**Passos**:
```sql
-- 1. Execute UMA ETAPA de cada vez
-- 2. Leia os comentários em cada seção
-- 3. Execute as queries de verificação entre etapas
-- 4. NÃO execute tudo de uma vez!
```

**Checklist**:
- [ ] Backup da tabela `corev4_ai_decisions`
- [ ] Executar ETAPA 1 (ADD COLUMN nullable)
- [ ] Executar ETAPA 2 (UPDATE company_id)
- [ ] Verificar: `SELECT COUNT(*) FROM corev4_ai_decisions WHERE company_id IS NULL;` deve retornar 0
- [ ] Executar ETAPA 3-4 (SET NOT NULL)
- [ ] Executar ETAPA 5 (ADD FK)
- [ ] Executar ETAPA 6 (Indexes)
- [ ] Executar ETAPA 7-8 (RLS Policies)
- [ ] Executar verificações finais

**Tempo estimado**: 5-10 minutos (dependendo do volume de dados)

---

#### 2. `002_add_missing_foreign_keys.sql`
**Objetivo**: Adicionar FKs faltantes para garantir integridade referencial

**Risco**: 🟡 MÉDIO - Pode falhar se houver dados órfãos

**Passos**:
```sql
-- Para cada PARTE:
-- 1. Execute a query de verificação (comentada)
-- 2. Se encontrar órfãos, escolha uma opção (A, B, ou C)
-- 3. Execute o ALTER TABLE para adicionar a FK
-- 4. Execute a criação do INDEX
```

**Checklist**:
- [ ] Backup das tabelas afetadas
- [ ] PARTE 1: `followup_sequences.campaign_id`
  - [ ] Verificar órfãos
  - [ ] Limpar/corrigir órfãos
  - [ ] Adicionar FK
  - [ ] Criar índice
- [ ] PARTE 2: `followup_stage_history.followup_execution_id`
  - [ ] Verificar órfãos
  - [ ] Limpar/corrigir órfãos
  - [ ] Adicionar FK
  - [ ] Criar índice
- [ ] PARTE 3: `lead_state_backup.company_id`
  - [ ] Verificar órfãos
  - [ ] Limpar órfãos (CRÍTICO)
  - [ ] Adicionar FK
  - [ ] Criar índice
- [ ] PARTE 4: `lead_state_backup.contact_id`
  - [ ] Verificar órfãos
  - [ ] Limpar órfãos
  - [ ] Adicionar FK
  - [ ] Criar índice
- [ ] PARTE 5: `message_dedup.contact_id`
  - [ ] Verificar órfãos
  - [ ] Limpar órfãos
  - [ ] Adicionar FK
  - [ ] Criar índice
- [ ] Executar verificação final

**Tempo estimado**: 10-15 minutos

---

## Como Executar no Supabase

### Opção 1: SQL Editor (Recomendado para produção)

1. Acesse o Supabase Dashboard
2. Vá em **SQL Editor**
3. Crie uma nova query
4. Copie e cole **UMA SEÇÃO** por vez
5. Execute e verifique o resultado
6. Repita para cada seção

### Opção 2: CLI (Para desenvolvimento)

```bash
# Se você usa Supabase CLI
supabase db push

# Ou execute diretamente
psql $DATABASE_URL < migrations/001_add_company_id_to_ai_decisions.sql
```

### Opção 3: Migration Framework

Se você usa um framework de migrations (ex: Prisma, TypeORM):

```bash
# Crie migrations vazias
npm run migration:create add_company_id_to_ai_decisions
npm run migration:create add_missing_foreign_keys

# Copie o conteúdo dos arquivos .sql para as migrations
# Execute
npm run migration:run
```

---

## Rollback

Cada arquivo de migração contém uma seção `ROLLBACK` comentada no final.

**CUIDADO**: Rollback pode causar perda de dados. Use apenas em caso de emergência.

```sql
-- Para reverter 002_add_missing_foreign_keys.sql
-- Execute os comandos na seção ROLLBACK em ordem reversa
```

---

## Verificações Pós-Migração

### 1. Verificar Foreign Keys

```sql
SELECT
  tc.table_name,
  tc.constraint_name,
  kcu.column_name,
  ccu.table_name AS references_table
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage ccu
  ON tc.constraint_name = ccu.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_schema = 'public'
ORDER BY tc.table_name;
```

### 2. Verificar RLS Policies

```sql
SELECT
  schemaname,
  tablename,
  policyname,
  cmd
FROM pg_policies
WHERE tablename LIKE 'corev4_%'
ORDER BY tablename, policyname;
```

### 3. Verificar Indexes

```sql
SELECT
  tablename,
  indexname,
  indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename LIKE 'corev4_%'
ORDER BY tablename, indexname;
```

### 4. Testar Isolamento Multi-tenant

```sql
-- Definir company_id de teste
SET app.current_company_id = 'seu-company-id-aqui';

-- Tentar selecionar ai_decisions
SELECT * FROM corev4_ai_decisions LIMIT 1;

-- Deve retornar apenas decisões da empresa definida
```

---

## Troubleshooting

### Erro: "violates foreign key constraint"

**Causa**: Existem registros órfãos na tabela

**Solução**:
1. Execute a query de verificação para encontrar órfãos
2. Escolha uma das opções (deletar, atribuir a padrão, etc)
3. Tente adicionar a FK novamente

### Erro: "column cannot be cast automatically to type uuid"

**Causa**: O tipo de dados da coluna não é compatível com UUID

**Solução**:
```sql
-- Se a coluna for integer e deveria ser UUID
ALTER TABLE nome_tabela
ALTER COLUMN coluna TYPE UUID USING coluna::text::uuid;
```

### Erro: "cannot add NOT NULL column without default"

**Causa**: Tentou adicionar coluna NOT NULL em tabela com dados

**Solução**: Já resolvido nas migrations - sempre adicionamos como nullable primeiro

---

## Performance Impact

### Impacto esperado:

- **001_add_company_id**:
  - Tempo: ~2-5min (dependendo do volume)
  - Índices adicionais: +2 indexes
  - Espaço extra: ~10-20% do tamanho da tabela

- **002_add_missing_foreign_keys**:
  - Tempo: ~5-10min total
  - Índices adicionais: +5 indexes
  - Impacto em queries: Mínimo (FKs com indexes são rápidos)

### Recomendações:

1. Execute em horário de baixo tráfego
2. Monitore o desempenho após a migração
3. Execute `ANALYZE` nas tabelas modificadas:

```sql
ANALYZE corev4_ai_decisions;
ANALYZE corev4_followup_sequences;
ANALYZE corev4_followup_stage_history;
ANALYZE corev4_lead_state_backup;
ANALYZE corev4_message_dedup;
```

---

## Next Steps

Após executar essas migrações:

1. ✅ Revisar o relatório `DATABASE_AUDIT_REPORT.md`
2. ✅ Atualizar a aplicação para usar RLS policies
3. 🔄 Planejar Phase 2: Campos que precisam investigação
4. 🔄 Planejar Phase 3: Otimizações

---

## Support

Em caso de dúvidas ou problemas:

1. Consulte o `DATABASE_AUDIT_REPORT.md` para contexto
2. Verifique os logs do PostgreSQL
3. Execute as queries de verificação em cada etapa
4. Mantenha sempre um backup antes de executar

---

**Data de criação**: 2025-10-27
**Status**: ✅ Pronto para execução
**Testado em**: Desenvolvimento
**Aprovado para produção**: Pendente teste
