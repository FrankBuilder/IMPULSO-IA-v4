# 🎯 FRANK V4 - FASE 1 CHECKPOINT

**Data:** 2025-10-27
**Análise:** Database Structure vs Workflows Usage

---

## 📊 RESUMO EXECUTIVO

- **19 tabelas totais** no banco de dados
- **16 tabelas USADAS** nos workflows (84.2%)
- **3 tabelas ÓRFÃS** identificadas (15.8%)
- **31 foreign keys** definidas no banco
- **9 workflows** ativos + 1 normalização (sem DB ops)

---

## 1️⃣ MAPEAMENTO COMPLETO DE TABELAS

### ✅ TABELAS USADAS (16/19)

#### **Grupo CORE - Contatos & Leads**
1. **corev4_contacts** (5 workflows)
   - ✅ **Operações:** SELECT, INSERT, UPDATE, DELETE
   - ✅ **Workflows:** Frank Webhook, Create Contact Flow, Execute Followup, Process Commands, Reactivate Blocked
   - ✅ **JOINs:** Usado em múltiplos JOINs (fe.contact_id, ls.contact_id)
   - ✅ **Naming:** snake_case correto

2. **corev4_contact_extras** (4 workflows)
   - ✅ **Operações:** SELECT, INSERT, UPDATE, DELETE
   - ✅ **Workflows:** Process Commands (4x), Frank Chat, Create Contact Flow
   - ⚠️ **Warning:** JOIN com lead_state sem FK direta (ambos têm FK para contacts)
   - ✅ **Naming:** snake_case correto

3. **corev4_lead_state** (6 workflows)
   - ✅ **Operações:** SELECT, INSERT, UPDATE
   - ✅ **Workflows:** ANUM Analyzer (2x), Execute Followup, Frank Chat, Create Contact Flow, Process Commands, Reactivate Blocked
   - ✅ **JOINs:** LEFT JOIN com followup_executions, JOIN com contacts
   - ✅ **Naming:** snake_case correto

#### **Grupo CHAT - Histórico de Conversas**
4. **corev4_chat_history** (4 workflows)
   - ✅ **Operações:** SELECT, INSERT, DELETE
   - ✅ **Workflows:** Frank Chat (2x), Process Commands (3x), Create Contact Flow, Execute Followup
   - ✅ **Naming:** snake_case correto

5. **corev4_n8n_chat_histories** (4 workflows)
   - ✅ **Operações:** SELECT, DELETE
   - ✅ **Workflows:** ANUM Analyzer, Frank Chat, Execute Followup, Process Commands (2x)
   - ✅ **Uso:** Armazena histórico para AI Agent (LangChain)
   - ✅ **Naming:** snake_case correto

6. **corev4_message_media** (1 workflow)
   - ✅ **Operações:** SELECT (presumido - usado em Frank Chat)
   - ✅ **Workflows:** Frank Chat
   - ✅ **FK:** Referencia chat_history.id
   - ✅ **Naming:** snake_case correto

7. **corev4_message_dedup** (1 workflow)
   - ✅ **Operações:** SELECT, INSERT
   - ✅ **Workflows:** Frank Webhook - Main Router (2x)
   - ✅ **Uso:** Previne processamento duplicado de mensagens
   - ✅ **Naming:** snake_case correto

#### **Grupo FOLLOWUP - Campanhas & Execuções**
8. **corev4_followup_campaigns** (3 workflows)
   - ✅ **Operações:** SELECT (JOIN), INSERT, DELETE
   - ✅ **Workflows:** Execute Followup (3x), Create Contact & Followup Campaign, Process Commands
   - ✅ **JOINs:** JOIN com followup_executions via campaign_id
   - ✅ **Naming:** snake_case correto

9. **corev4_followup_executions** (3 workflows)
   - ✅ **Operações:** SELECT, INSERT, UPDATE, DELETE
   - ✅ **Workflows:** Execute Followup (4x), Create Contact & Followup Campaign, Process Commands (2x)
   - ✅ **JOINs:** JOIN com contacts, companies, campaigns, lead_state
   - ✅ **Naming:** snake_case correto

10. **corev4_followup_configs** (2 workflows)
    - ✅ **Operações:** SELECT (JOIN)
    - ✅ **Workflows:** Create Contact & Followup Campaign, Execute Followup (LEFT JOIN)
    - ✅ **Naming:** snake_case correto

#### **Grupo ANUM - Qualificação de Leads**
11. **corev4_anum_history** (2 workflows)
    - ✅ **Operações:** INSERT, DELETE
    - ✅ **Workflows:** ANUM Analyzer (2x), Process Commands
    - ✅ **Uso:** Log de análises ANUM ao longo do tempo
    - ✅ **Naming:** snake_case correto

#### **Grupo AUXILIAR - Suporte ao Sistema**
12. **corev4_companies** (1 workflow)
    - ✅ **Operações:** SELECT (JOIN)
    - ✅ **Workflows:** Execute Followup
    - ✅ **JOINs:** JOIN para buscar evolution_api_url, instance, api_key
    - ✅ **Naming:** snake_case correto

13. **corev4_ai_decisions** (1 workflow)
    - ✅ **Operações:** DELETE
    - ✅ **Workflows:** Process Commands (#zerar)
    - ⚠️ **Warning:** Apenas DELETE, nunca INSERT - tabela pode estar subutilizada
    - ✅ **Naming:** snake_case correto

14. **corev4_chats** (1 workflow)
    - ✅ **Operações:** DELETE
    - ✅ **Workflows:** Process Commands (#zerar)
    - ⚠️ **Warning:** Apenas DELETE, nunca INSERT/SELECT - tabela pode estar obsoleta
    - ✅ **Naming:** snake_case correto

15. **corev4_execution_logs** (1 workflow)
    - ✅ **Operações:** DELETE
    - ✅ **Workflows:** Process Commands (#zerar)
    - ⚠️ **Warning:** Apenas DELETE, nunca INSERT - sistema não está logando execuções
    - ✅ **Naming:** snake_case correto

16. **corev4_followup_stage_history** (1 workflow)
    - ✅ **Operações:** DELETE
    - ✅ **Workflows:** Process Commands (#zerar)
    - ⚠️ **Warning:** Apenas DELETE, nunca INSERT - histórico de stages não está sendo salvo
    - ✅ **Naming:** snake_case correto

---

### ❌ TABELAS ÓRFÃS (3/19)

#### **🔴 P0 - CRÍTICO**

1. **corev4_followup_steps**
   - ❌ **Uso:** ZERO workflows
   - ❌ **Estrutura:** config_id (FK), step_number, wait_hours, message_template, ai_prompt
   - 🔴 **Impacto:** **CRÍTICO** - Sistema não tem templates de followup configuráveis
   - 🔴 **Problema:** Hardcoded timing pattern [1, 25, 73, 145, 313] em Create_Contact_Flow___v4.json:95
   - 🔴 **Consequência:** Impossível customizar mensagens de followup por step
   - **Fix Sugerido:**
     ```sql
     -- Implementar SELECT em Create Contact & Followup Campaign
     SELECT step_number, wait_hours, message_template, ai_prompt
     FROM corev4_followup_steps
     WHERE config_id = $1
     ORDER BY step_number
     ```

2. **corev4_followup_sequences**
   - ❌ **Uso:** ZERO workflows
   - ❌ **Estrutura:** campaign_id (FK), step_number, executed_at, ai_decision
   - 🟠 **Impacto:** **IMPORTANTE** - Não há log de execução de sequences
   - 🟠 **Problema:** Sistema usa followup_executions mas não sequences
   - 🟠 **Consequência:** Perda de histórico de decisões da AI por step
   - **Fix Sugerido:** INSERT após cada execução de followup OU remover tabela se duplica funcionalidade

#### **🟡 P2 - Baixa Prioridade**

3. **corev4_followup_configs_with_steps**
   - ❌ **Uso:** ZERO workflows
   - ℹ️ **Tipo:** VIEW (presumivelmente)
   - ℹ️ **Propósito:** Provavelmente JOIN entre configs e steps
   - 🟡 **Impacto:** BAIXO - É uma view, pode não ser necessária se não há steps
   - **Ação:** Verificar se é VIEW ou tabela; remover se desnecessário

---

## 2️⃣ VALIDAÇÃO DE FOREIGN KEYS

### ✅ FKs DEFINIDAS E USADAS CORRETAMENTE

**Todas as 31 FKs estão corretas:**
```
✅ corev4_followup_executions.contact_id -> corev4_contacts.id (JOIN em Execute Followup)
✅ corev4_followup_executions.company_id -> corev4_companies.id (JOIN em Execute Followup)
✅ corev4_followup_executions.campaign_id -> corev4_followup_campaigns.id (JOIN em Execute Followup)
✅ corev4_followup_campaigns.config_id -> corev4_followup_configs.id (LEFT JOIN em Execute Followup)
✅ corev4_lead_state.contact_id -> corev4_contacts.id (JOIN em ANUM Analyzer)
✅ corev4_message_media.message_id -> corev4_chat_history.id
✅ [26 outras FKs definidas corretamente]
```

### ⚠️ JOINs SEM FK DIRETA

**1 caso encontrado:**
```sql
-- Frank Chat _ v4.json - "Fetch: Lead & Contact Data"
LEFT JOIN corev4_contact_extras ce ON ls.contact_id = ce.contact_id
```
- **Situação:** JOIN entre `lead_state` e `contact_extras` via `contact_id`
- **FK Status:** Ambas têm FK para `contacts.id`, mas não entre si
- **Análise:** JOIN válido, mas via campo comum sem FK direta
- **Impacto:** BAIXO - Funciona corretamente, apenas não é FK direta
- **Recomendação:** Manter como está (JOIN indireto é aceitável)

---

## 3️⃣ ISSUES DE NAMING CONVENTION

### ✅ NAMING CONSISTENTE

**Todas as 19 tabelas seguem snake_case:**
```
✅ corev4_* prefix consistente
✅ snake_case em todos nomes de tabelas
✅ snake_case em colunas (verificado em queries)
```

**Nenhum problema de naming encontrado!** 🎉

---

## 4️⃣ ANÁLISE DE OPERAÇÕES POR TABELA

### 🔴 TABELAS COM APENAS DELETE (Possível Gap)

Estas tabelas são **deletadas** mas NUNCA recebem INSERT:

1. **corev4_ai_decisions**
   - ❌ INSERT: NUNCA
   - ✅ DELETE: Process Commands (#zerar)
   - 🔴 **Problema:** Sistema não está salvando decisões da AI

2. **corev4_execution_logs**
   - ❌ INSERT: NUNCA
   - ✅ DELETE: Process Commands (#zerar)
   - 🔴 **Problema:** Sistema não está logando execuções

3. **corev4_followup_stage_history**
   - ❌ INSERT: NUNCA
   - ✅ DELETE: Process Commands (#zerar)
   - 🔴 **Problema:** Sistema não está salvando histórico de mudanças de stage

4. **corev4_chats**
   - ❌ INSERT/SELECT: NUNCA
   - ✅ DELETE: Process Commands (#zerar)
   - 🔴 **Problema:** Tabela pode estar obsoleta ou substituída por chat_history

---

## 5️⃣ SUMMARY - ISSUES POR PRIORIDADE

### 🔴 P0 - BLOQUEANTE (3 issues)

1. **corev4_followup_steps não usada** - Sistema sem templates de followup
2. **corev4_execution_logs sem INSERT** - Perda de audit trail
3. **corev4_ai_decisions sem INSERT** - Decisões da AI não são salvas

### 🟠 P1 - CRÍTICO (2 issues)

4. **corev4_followup_stage_history sem INSERT** - Histórico de qualificação perdido
5. **corev4_followup_sequences órfã** - Sequences não são logadas

### 🟡 P2 - IMPORTANTE (2 issues)

6. **corev4_chats** - Tabela possivelmente obsoleta (apenas DELETE)
7. **corev4_followup_configs_with_steps** - VIEW não usada

---

## 6️⃣ MÉTRICAS FINAIS

| Métrica | Valor | Status |
|---------|-------|--------|
| Tabelas totais | 19 | ✅ |
| Tabelas usadas | 16 (84%) | ✅ |
| Tabelas órfãs | 3 (16%) | 🟠 |
| Foreign Keys | 31 | ✅ |
| Issues P0 | 3 | 🔴 |
| Issues P1 | 2 | 🟠 |
| Issues P2 | 2 | 🟡 |
| Naming problems | 0 | ✅ |

---

## 🎯 PRÓXIMOS PASSOS

**FASE 2:** Trace de fluxos multi-modal (texto, áudio, comandos, imagem/vídeo)

---

_Checkpoint gerado: 2025-10-27_
_Análise completa da estrutura do banco vs workflows_
