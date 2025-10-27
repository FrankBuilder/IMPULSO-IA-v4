# 🎯 COMANDO PARA CLAUDE CODE (WEB)

Copie e cole este texto completo no Claude Code web (https://claude.ai/code):

---

## 📋 INSTRUÇÃO PARA ANÁLISE

Você receberá:
1. Estrutura do banco de dados (JSON)
2. 10 workflows n8n (.json)
3. Documentação do projeto

**Sua missão:** Analisar o sistema Frank v4 e gerar relatório de problemas/gaps.

---

## 🔍 ANÁLISE EM 3 FASES

### FASE 1: Database vs Workflows (20 min)

**Objetivos:**
1. Mapear quais tabelas são usadas em quais workflows
2. Identificar tabelas órfãs (não usadas em nenhum workflow)
3. Validar campos: snake_case vs camelCase
4. Checar foreign keys usadas vs definidas
5. Identificar campos NOT NULL que workflows tentam deixar vazios

**Output esperado:**
```markdown
# FASE 1 - DATABASE MAPPING

## Tabelas Usadas (X de 19)
- corev4_contacts: Usado em [workflow1, workflow2]
  - Operações: INSERT (3x), UPDATE (1x), SELECT (5x)
  - Campos usados: id, whatsapp, full_name...

## Tabelas Órfãs (Y de 19)
- corev4_anum_history: CRÍTICO - deveria ser usado após análise
  - Impacto: Sem auditoria de mudanças ANUM

## Issues Críticos
1. [P0] Campo X em workflow Y usa camelCase mas banco é snake_case
2. [P1] Tabela Z nunca recebe INSERT mas é critical
```

---

### FASE 2: Trace de Fluxos Multi-Modal (25 min)

**Cenários para rastrear:**

**A) Mensagem de texto simples:**
```
Webhook → Router → Frank Chat → Lead State Update → Followup?
```

**B) Mensagem de áudio:**
```
Webhook → Router → Process Audio → Frank Chat → ...
```

**C) Comando especial (#sair, #zerar):**
```
Webhook → Router → Process Commands → ...
```

**D) Imagem/Video:**
```
Webhook → Router → ??? (multimodal implementado?)
```

**Para cada cenário, identifique:**
1. Sequence de workflows executados
2. Tabelas tocadas (INSERT/UPDATE/SELECT)
3. Gaps: O que DEVERIA acontecer mas não acontece?
4. Dead ends: Fluxos que não completam?

**Output esperado:**
```markdown
# FASE 2 - TRACE DE FLUXOS

## Fluxo: Texto Simples
Webhook → Normalize → Router → Frank Chat → ???
❌ GAP: Lead state não é atualizado após conversa
❌ GAP: chat_history recebe INSERT mas anum_history não

## Fluxo: Áudio
Webhook → Normalize → Router → Process Audio → Frank Chat
✅ OK até aqui
⚠️  ISSUE: Transcrição não persiste em message_media

## Fluxo: Comando #sair
Webhook → Router → Process Commands
❌ GAP: followup_campaigns.status não é atualizado
```

---

### FASE 3: Node-by-Node dos Workflows Críticos (25 min)

**Workflows prioritários:**
1. Frank Chat (AI Agent core)
2. Execute Followup Processor (cron job)
3. Create Contact Flow (entrada de leads)

**Para cada workflow, analise:**

1. **Nodes Postgres:**
   - Query SQL está correto?
   - Campos existem no banco?
   - Naming convention consistente?
   - Trata erros (Try-Catch)?

2. **Nodes AI Agent:**
   - Tools configuradas corretas?
   - Memory session_id correto?
   - Output parseado adequadamente?

3. **Nodes Execute Workflow:**
   - Sub-workflow existe?
   - Parâmetros passados corretos?
   - Response handling OK?

4. **Conditional/IF nodes:**
   - Lógica correta?
   - Cobre todos os casos?
   - Tratamento de null/undefined?

**Output esperado:**
```markdown
# FASE 3 - NODE-BY-NODE

## Workflow: Frank Chat

### Node: "Update Lead State"
❌ ERRO: Campo `authorityScore` (camelCase) mas banco é `authority_score`
🔧 FIX: Mudar para snake_case

### Node: "AI Agent"
⚠️  WARNING: Tool schema não valida response
🔧 FIX: Adicionar structured output parser

### Node: "Get Contact Info"
✅ OK
```

---

## 📊 RELATÓRIO FINAL

Ao final, gere:

```markdown
# 🎯 FRANK V4 - ANÁLISE COMPLETA

## Executive Summary
- X tabelas órfãs críticas
- Y queries com naming mismatch
- Z fluxos incompletos

## Issues por Prioridade

### P0 - Bloqueante (impedem produção)
1. [Issue detalhado]
   - Onde: workflow X, node Y
   - O quê: descrição
   - Fix: solução específica

### P1 - Crítico (bugs em produção)
[...]

### P2 - Importante (melhorias)
[...]

## Checklist de Produção
- [ ] Todas tabelas core integradas
- [ ] Naming convention consistente
- [ ] Error handling completo
- [ ] Logs/auditoria funcionando
- [ ] Multimodal implementado
- [ ] Followup automation completa

## Próximos Passos (ordem de execução)
1. Corrigir P0 issues
2. Testar fluxo end-to-end
3. Implementar P1 issues
4. Deploy com monitoring
```

---

## 🚀 COMO USAR

1. Abra https://claude.ai/code
2. Cole este prompt completo
3. Faça upload de:
   - `supabase_structure_v4.json` (query abaixo)
   - 10 workflows `.json`
   - Arquivos `.md` de documentação
4. Aguarde análise completa (~70 min)

---

## ⚙️ CONFIGURAÇÕES

**Seja:**
- Direto e objetivo
- Específico (nome de node, linha de código)
- Pragmático (sempre sugira o fix)
- Crítico (aponte tudo que estiver errado)

**Não seja:**
- Genérico
- Evasivo
- Teórico
- Complacente

---

**Pronto para começar?**
