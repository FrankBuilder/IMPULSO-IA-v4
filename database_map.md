# MAPA DO BANCO DE DADOS - Supabase v3

## RESUMO EXECUTIVO
- Total de tabelas: **19**
- Tabelas com Foreign Keys: **17**
- Foreign Keys total: **40** (foi 21 no v2) ✅ MUITO MELHOR!
- **IMPORTANTE:** 19 FKs NOVAS foram adicionadas! Integridade muito melhor! 🎉

---

## LISTA DE TABELAS

```
corev4_ai_decisions
corev4_anum_history
corev4_chat_history
corev4_chats
corev4_companies
corev4_contact_extras
corev4_contacts
corev4_execution_logs
corev4_followup_campaigns
corev4_followup_configs
corev4_followup_executions
corev4_followup_sequences
corev4_followup_stage_history
corev4_followup_steps
corev4_lead_state
corev4_lead_state_backup
corev4_message_dedup
corev4_message_media
corev4_n8n_chat_histories
```

---

## FOREIGN KEYS EXISTENTES ✅

```
corev4_ai_decisions: 1 FKs - [followup_execution_id]
corev4_anum_history: 2 FKs - [company_id, contact_id]
corev4_chat_history: 2 FKs - [company_id, contact_id]
corev4_chats: 2 FKs - [contact_id, company_id]
corev4_companies: 1 FKs - [default_followup_config_id]
corev4_contact_extras: 3 FKs - [contact_id, contact_id, company_id]
corev4_contacts: 1 FKs - [company_id]
corev4_execution_logs: 1 FKs - [contact_id]
corev4_followup_campaigns: 6 FKs - [company_id, contact_id, config_id, company_id, contact_id, config_id]
corev4_followup_configs: 2 FKs - [company_id, company_id]
corev4_followup_executions: 6 FKs - [campaign_id, contact_id, company_id, contact_id, campaign_id, company_id]
corev4_followup_stage_history: 2 FKs - [contact_id, company_id]
corev4_followup_steps: 1 FKs - [config_id]
corev4_lead_state: 4 FKs - [contact_id, company_id, company_id, contact_id]
corev4_message_dedup: 1 FKs - [company_id]
corev4_message_media: 4 FKs - [message_id, company_id, message_id, company_id]
corev4_n8n_chat_histories: 1 FKs - [contact_id]
```

**Total:** 40 Foreign Keys distribuídas em 17 tabelas

---

## FOREIGN KEYS FALTANDO ⚠️ CRÍTICO

```
⚠️  corev4_chat_history: session_id
⚠️  corev4_companies: crm_pipeline_id
⚠️  corev4_contact_extras: pipeline_id, crm_id, deals_id, thread_id, stripe_id
⚠️  corev4_execution_logs: execution_id, followup_id
⚠️  corev4_followup_executions: evolution_message_id
⚠️  corev4_followup_sequences: campaign_id
⚠️  corev4_followup_stage_history: followup_execution_id
⚠️  corev4_lead_state: last_analysis_id
⚠️  corev4_lead_state_backup: company_id, contact_id, last_analysis_id
⚠️  corev4_message_dedup: message_id, whatsapp_id, contact_id, workflow_execution_id
⚠️  corev4_n8n_chat_histories: session_id
```

**Total:** 11 tabelas com campos *_id sem Foreign Keys

**Impacto:** Sem FKs = dados órfãos possíveis, integridade não garantida

---

## ANÁLISE DE CRITICIDADE

### 🔴 ALTA PRIORIDADE (relações core do sistema)
- `corev4_chat_history.session_id` → Afeta rastreamento de conversas
- `corev4_followup_executions.evolution_message_id` → Afeta workflow de followup
- `corev4_followup_sequences.campaign_id` → Afeta gestão de campanhas
- `corev4_execution_logs.execution_id, followup_id` → Afeta logs e auditoria
- `corev4_lead_state_backup.company_id, contact_id` → Afeta backup de estados

### 🟡 MÉDIA PRIORIDADE (integrações externas)
- `corev4_companies.crm_pipeline_id` → Integração com CRM
- `corev4_contact_extras.pipeline_id, crm_id, deals_id, thread_id` → Dados de CRM
- `corev4_message_dedup.message_id, whatsapp_id, contact_id` → Dedup de mensagens

### 🟢 BAIXA PRIORIDADE (features secundárias)
- `corev4_contact_extras.stripe_id` → Integração Stripe (se não usado)
- `corev4_n8n_chat_histories.session_id` → Logs N8N

---

## SQL PARA ADICIONAR FKs FALTANDO

```sql
-- TODO: Gerar ALTER TABLE statements na próxima fase
-- Exemplo estrutura:
-- ALTER TABLE corev4_chat_history
-- ADD CONSTRAINT fk_chat_session
-- FOREIGN KEY (session_id) REFERENCES corev4_sessions(id);

-- IMPORTANTE: Antes de executar, verificar:
-- 1. Tabela de destino existe?
-- 2. Dados órfãos precisam ser limpos?
-- 3. ON DELETE CASCADE ou SET NULL?
```

---

## PRÓXIMOS PASSOS

1. **Fase 2:** Análise de Workflows 01 e 02
2. **Fase 3:** Documentação de relacionamentos
3. **Fase 4:** Geração de SQLs para FKs faltando
4. **Fase 5:** Relatório consolidado

---

**Data da análise:** 2025-10-27
**Fase:** 1/5 - Mapeamento do Banco
**Próxima fase:** Análise de Workflows 01 e 02
**Status:** ✅ CONCLUÍDA
