# WORKFLOW 01: Frank Webhook - Main Router _ v4.json

## STATUS
⚠️ PROBLEMA CRÍTICO IDENTIFICADO

## RESUMO
- **Função:** Ponto de entrada do sistema via webhook
- **Total de nodes:** 24
- **Nodes Supabase:** 1
- **Criticidade:** ALTA (ponto de entrada do sistema)

---

## NODES SUPABASE ENCONTRADOS

```
- Fetch: Contact Record | Operação: getAll | Tabela: corev4_contacts
```

---

## VERIFICAÇÃO MULTI-TENANT

### Nodes SEM company_id ⚠️

**⚠️ CRÍTICO: "Fetch: Contact Record"**

```json
{
  "name": "Fetch: Contact Record",
  "type": "n8n-nodes-base.supabase",
  "operation": "getAll",
  "tableId": "corev4_contacts",
  "filters": {
    "conditions": [
      {
        "keyName": "whatsapp",
        "condition": "eq",
        "keyValue": "={{ $('Execute: Normalize Evolution Data').item.json.whatsapp_id }}"
      }
    ]
  }
}
```

**Problema:** Filtra APENAS por `whatsapp`, sem `company_id`

**Impacto:**
- Empresa A pode buscar contato que pertence à Empresa B
- Dados de contatos vazam entre empresas
- Violação GRAVE de multi-tenancy

---

## PROBLEMAS IDENTIFICADOS

### 🔴 CRÍTICO: Query sem company_id

**Node:** Fetch: Contact Record
**Tabela:** corev4_contacts
**Operação:** getAll (SELECT)
**Severidade:** CRÍTICA

**Impacto:**
- Multi-tenant completamente quebrado neste ponto
- Empresas diferentes podem acessar contatos umas das outras
- Risco de violação de privacidade e LGPD

**Solução:**

```json
{
  "filters": {
    "conditions": [
      {
        "keyName": "whatsapp",
        "condition": "eq",
        "keyValue": "={{ $('Execute: Normalize Evolution Data').item.json.whatsapp_id }}"
      },
      {
        "keyName": "company_id",
        "condition": "eq",
        "keyValue": "={{ $('Execute: Normalize Evolution Data').item.json.company_id }}"
      }
    ]
  }
}
```

**Prioridade:** URGENTE - Corrigir ANTES de qualquer deploy

---

## ANÁLISE DE FLUXO

### Contexto do Problema

Este workflow é o **PONTO DE ENTRADA** do sistema via webhook. Quando recebe uma mensagem:

1. Normaliza dados da Evolution API
2. **Busca contato por whatsapp_id (SEM company_id)** ⚠️
3. Roteia para workflows subsequentes

Se o contato errado for retornado aqui, TODO o resto do fluxo ficará comprometido.

### Cenário de Falha

```
Empresa A (company_id: 1) e Empresa B (company_id: 2) têm contatos com whatsapp: +5511999999999

Mensagem chega para Empresa A:
1. Webhook recebe whatsapp_id = +5511999999999
2. Busca sem company_id
3. Retorna contato da Empresa B (foi criado primeiro no banco)
4. Mensagem é processada no contexto ERRADO
5. Dados vazam entre empresas
```

---

## RECOMENDAÇÕES

### Imediatas (URGENTE)
- [ ] Adicionar `company_id` no filtro do node "Fetch: Contact Record"
- [ ] Validar que `company_id` vem corretamente da Evolution API normalizada
- [ ] Testar com 2 empresas diferentes tendo o mesmo número

### Curto Prazo
- [ ] Adicionar logging/telemetria neste workflow
- [ ] Implementar validação de company_id em TODAS as queries
- [ ] Criar teste automatizado de multi-tenancy

### Médio Prazo
- [ ] Revisar TODOS os workflows para garantir company_id
- [ ] Criar template/snippet reutilizável para queries Supabase
- [ ] Documentar padrão de multi-tenancy obrigatório

---

## PRÓXIMOS PASSOS

1. **URGENTE:** Corrigir query do Fetch: Contact Record
2. Validar correção em ambiente de teste
3. Deploy da correção
4. Monitorar logs para garantir que company_id está sendo usado

---

## NOTAS TÉCNICAS

### Estrutura do Webhook
- Recebe dados da Evolution API
- Node "Execute: Normalize Evolution Data" processa payload
- Deve garantir que `company_id` está presente nos dados normalizados

### Dependências
- Evolution API deve enviar `company_id` no webhook
- Se não enviar, precisa adicionar lógica para derivar company_id

---

**Analisado em:** 2025-10-27
**Fase:** 2A/5
**Status:** ⚠️ CORREÇÃO URGENTE NECESSÁRIA
**Próxima análise:** workflow_02_chat_CRITICAL.md
