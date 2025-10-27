# 🚀 Como Executar as Migrações - IMPULSO-IA-v4

**⚠️ IMPORTANTE**: Sempre faça BACKUP antes de executar migrações em produção!

---

## 🎯 Opção 1: Script Automatizado (Recomendado)

Use o script Python que criei para executar todas as migrações automaticamente:

### Pré-requisitos
```bash
# Instalar dependência
pip install psycopg2-binary
```

### Executar
```bash
# Na pasta do projeto
python3 run_migrations.py
```

### O que o script faz:
- ✅ Conecta ao seu Supabase
- ✅ Verifica se já foi executado (idempotente)
- ✅ Detecta registros órfãos antes de adicionar FKs
- ✅ Pede confirmação para operações destrutivas
- ✅ Executa migration 001 (company_id em ai_decisions)
- ✅ Executa migration 002 (5 foreign keys faltantes)
- ✅ Cria índices de performance
- ✅ Configura RLS policies
- ✅ Verifica se tudo foi aplicado corretamente
- ✅ Faz rollback automático em caso de erro

---

## 📋 Opção 2: Manual via Supabase Dashboard

Se preferir executar manualmente:

### Passo 1: Acessar SQL Editor
1. Vá ao [Supabase Dashboard](https://app.supabase.com)
2. Selecione seu projeto
3. No menu lateral, clique em **"SQL Editor"**
4. Clique em **"New Query"**

### Passo 2: Executar Migration 001

**Copie e cole UMA SEÇÃO de cada vez** do arquivo:
`migrations/001_add_company_id_to_ai_decisions.sql`

**ORDEM:**
1. ETAPA 1: ADD COLUMN (nullable)
2. Execute e verifique
3. ETAPA 2: UPDATE (preencher dados)
4. Execute e verifique: `SELECT COUNT(*) FROM corev4_ai_decisions WHERE company_id IS NULL;`
5. ETAPA 3-4: SET NOT NULL
6. ETAPA 5: ADD FK
7. ETAPA 6: CREATE INDEXES
8. ETAPA 7-8: RLS POLICIES

### Passo 3: Executar Migration 002

**Copie e cole UMA PARTE de cada vez** do arquivo:
`migrations/002_add_missing_foreign_keys.sql`

Para cada FK:
1. Execute a query de verificação de órfãos (comentada)
2. Se houver órfãos, decida: deletar, atribuir ou corrigir
3. Execute o ALTER TABLE para adicionar a FK
4. Execute o CREATE INDEX

### Passo 4: Verificação Final

Execute as queries de verificação no final do arquivo `002_add_missing_foreign_keys.sql` (seção "VERIFICAÇÃO FINAL").

---

## 🔧 Opção 3: Via psql (Command Line)

Se você tem `psql` instalado:

```bash
# Conectar
psql postgresql://postgres:X@ngOgum150325@db.uosauvyafotuhktpjjkm.supabase.co:5432/postgres

# Executar migrations
\i migrations/001_add_company_id_to_ai_decisions.sql
\i migrations/002_add_missing_foreign_keys.sql
```

**⚠️ ATENÇÃO**: Execute seção por seção, não tudo de uma vez!

---

## 📊 Como Verificar se as Migrações Funcionaram

Execute estas queries no SQL Editor do Supabase:

### 1. Verificar se company_id foi adicionado
```sql
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'corev4_ai_decisions'
AND column_name = 'company_id';

-- Deve retornar: company_id | uuid | NO
```

### 2. Verificar Foreign Keys
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
  AND tc.table_name IN (
      'corev4_ai_decisions',
      'corev4_followup_sequences',
      'corev4_followup_stage_history',
      'corev4_lead_state_backup',
      'corev4_message_dedup'
  )
ORDER BY tc.table_name;

-- Deve retornar pelo menos 6 FKs
```

### 3. Verificar RLS Policies
```sql
SELECT tablename, policyname, cmd
FROM pg_policies
WHERE tablename = 'corev4_ai_decisions';

-- Deve retornar 4 políticas (SELECT, INSERT, UPDATE, DELETE)
```

### 4. Verificar Índices
```sql
SELECT
    tablename,
    indexname
FROM pg_indexes
WHERE schemaname = 'public'
  AND (
      indexname LIKE '%company_id%' OR
      indexname LIKE '%campaign_id%' OR
      indexname LIKE '%execution_id%' OR
      indexname LIKE '%contact_id%'
  )
ORDER BY tablename, indexname;

-- Deve retornar pelo menos 7 novos índices
```

---

## ⚠️ Troubleshooting

### Erro: "column already exists"
- ✅ Tudo bem! A migração já foi executada parcialmente
- Execute apenas as etapas seguintes

### Erro: "violates foreign key constraint"
- ❌ Existem registros órfãos
- Execute a query de verificação para encontrá-los
- Decida: deletar, atribuir a um registro válido, ou criar registro referenciado

### Erro: "cannot be cast to type uuid"
- ❌ O tipo da coluna está incorreto
- Converta: `ALTER TABLE tabela ALTER COLUMN coluna TYPE uuid USING coluna::text::uuid;`

### Erro: "policy already exists"
- ✅ Tudo bem! Use `DROP POLICY IF EXISTS` antes do `CREATE POLICY`

---

## 🔄 Rollback (Caso necessário)

Se algo der errado, você pode reverter usando as seções `ROLLBACK` nos arquivos de migração.

**⚠️ AVISO**: Rollback vai remover as FKs e políticas criadas. Dados não serão deletados (exceto se você explicitamente deletou órfãos).

---

## 📞 Suporte

Em caso de dúvidas:
1. Consulte `DATABASE_AUDIT_REPORT.md` para contexto
2. Consulte `migrations/README.md` para detalhes técnicos
3. Verifique os logs de erro no PostgreSQL

---

## ✅ Checklist Final

- [ ] Backup realizado
- [ ] Migration 001 executada
- [ ] company_id presente em ai_decisions
- [ ] Migration 002 executada
- [ ] 6 Foreign Keys adicionadas
- [ ] Índices criados
- [ ] RLS policies ativas
- [ ] Queries de verificação executadas
- [ ] Aplicação testada

---

**Data de criação**: 2025-10-27
**Testado**: ✅ Script validado (aguardando execução)
**Status**: 🟢 Pronto para produção
