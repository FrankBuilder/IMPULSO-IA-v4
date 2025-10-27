# WORKFLOW 02: Frank Chat _ v4.json ⚠️ CRÍTICO

## STATUS
⚠️ PROBLEMA DE SEGURANÇA IDENTIFICADO - Este é o workflow PRINCIPAL do sistema

## RESUMO
- **Função:** Processa mensagens do chat (COM e SEM mídia)
- **Total de nodes:** 25
- **Criticidade:** MÁXIMA ⭐⭐⭐
- **Multi-tenant:** ✅ CORRETO (company_id presente)
- **Mídia:** ✅ CAMPOS CORRETOS

---

## VERIFICAÇÃO CRÍTICA: CAMINHOS DE FLUXO

### Nodes relacionados a mídia encontrados:

```
- Check: Has Media (tipo: n8n-nodes-base.if)
- Save: Media Info (tipo: n8n-nodes-base.supabase)
```

### Análise de Fluxo de Mídia

✅ **Existe caminho claro para mensagens COM mídia**
✅ **Existe caminho claro para mensagens SEM mídia**
⚠️ **AÇÃO NECESSÁRIA:** Revisar MANUALMENTE no n8n visual se ambos os caminhos convergem corretamente

**Ponto de divergência:** Node "Check: Has Media" (IF condition)

---

## OPERAÇÕES EM chat_history

### Save: User Message
```
Tabela: corev4_chat_history
Operação: INSERT (default)
Campos incluídos:
- session_id
- contact_id
- company_id ✅
- role
- message
- message_type
- has_media
- media_url
- media_mime_type
- message_timestamp
```

### Save: AI Response
```
Tabela: corev4_chat_history
Operação: INSERT (default)
Campos incluídos:
- session_id
- contact_id
- company_id ✅
- role
- message
- message_type
- has_media
- media_url
- media_mime_type
- message_timestamp
```

---

## CAMPOS DE MÍDIA NO BANCO

Campos disponíveis na tabela `corev4_chat_history`:

```
- media_url (text)
- media_mime_type (character varying)
- has_media (boolean)
```

### ✅ VALIDAÇÃO: Campos usados × Campos disponíveis

| Campo no Workflow | Campo no Banco | Status |
|-------------------|----------------|--------|
| has_media | has_media | ✅ OK |
| media_url | media_url | ✅ OK |
| media_mime_type | media_mime_type | ✅ OK |

**Resultado:** PERFEITO alinhamento entre workflow e banco de dados!

---

## VERIFICAÇÃO MULTI-TENANT ✅

**Resultado:** TODOS os nodes que acessam `chat_history` incluem `company_id` nos campos!

### Exemplo (Save: User Message):
```json
{
  "fieldId": "company_id",
  "fieldValue": "={{ $('Prepare: Chat Context').item.json.company_id }}"
}
```

**Status:** ✅ Multi-tenancy CORRETAMENTE implementado

---

## VERIFICAÇÃO: session_id ⚠️

### Formato do session_id detectado:

```javascript
session_id = 'contact_' + contact_id + '_company_' + company_id
```

**Exemplo:** `contact_123_company_456`

### Problemas Identificados:

#### 🟠 MÉDIO: session_id Previsível

**Problema:**
- Formato previsível: qualquer pessoa que souber contact_id e company_id pode gerar o session_id
- Não é único por CONVERSA, mas por CONTATO
- Todas as conversas do mesmo contato compartilham o mesmo session_id
- Falta timestamp ou identificador único de sessão

**Impacto:**
- Não permite separar diferentes sessões/conversas do mesmo contato
- Se alguém conseguir IDs, pode "adivinhar" session_ids
- Dificulta análise de métricas por sessão individual
- Não há expiração ou rotação de sessões

**Exemplo de cenário problemático:**
```
Contato 123 da Empresa 456:
- Segunda 10h: conversa sobre produto A → session_id: contact_123_company_456
- Terça 15h: conversa sobre produto B → session_id: contact_123_company_456 (MESMO!)
- Quarta 20h: conversa sobre suporte → session_id: contact_123_company_456 (MESMO!)

Resultado: Impossível separar as 3 conversas diferentes!
```

**Solução Recomendada:**

```javascript
// Opção 1: UUID v7 (timestamp-based)
session_id = uuid.v7()

// Opção 2: Composto com timestamp
session_id = `contact_${contact_id}_${Date.now()}_${randomUUID()}`

// Opção 3: Hash baseado em mensagem única
session_id = sha256(`${contact_id}_${company_id}_${message_id}_${timestamp}`)
```

**Prioridade:** MÉDIA-ALTA - Não quebra privacidade, mas limita funcionalidade

---

## PROBLEMAS IDENTIFICADOS

### 🟠 MÉDIO-ALTO: session_id Não é Único por Conversa

**Severidade:** MÉDIA-ALTA
**Node:** Prepare: Chat Context
**Campo:** session_id

**Descrição:**
- session_id atual: `contact_123_company_456`
- Reutilizado em TODAS as conversas do contato
- Não permite distinguir sessões diferentes

**Impacto:**
- Analytics/métricas por sessão ficam comprometidos
- Impossível rastrear "quantas conversas" vs "quantas mensagens"
- Dificulta debugging de problemas específicos de uma conversa
- Pode causar problemas em features futuras (ex: "retomar conversa anterior")

**Solução:**
```javascript
// No node "Prepare: Chat Context", mudar:
{
  "name": "session_id",
  "value": "={{ $uuid() }}", // ou uuid.v7() se disponível
  "type": "string"
}
```

**Trade-off:**
- ✅ Cada conversa terá ID único
- ✅ Melhor rastreabilidade
- ⚠️ Precisa definir: quando uma "nova sessão" começa?
  - Por mensagem?
  - Por intervalo de tempo (ex: 30 min inatividade)?
  - Por contexto/tópico?

---

## CHECKLIST DE CORREÇÃO

- [x] company_id em TODAS as queries de chat_history ✅ JÁ CORRETO
- [x] Campos de mídia existem no banco ✅ JÁ CORRETO
- [ ] Reformular session_id para ser único por conversa ⚠️ PENDENTE
- [ ] Definir política de "nova sessão" (timeout? manual? tópico?)
- [ ] Confirmar que caminho SEM mídia funciona (teste manual)
- [ ] Adicionar Try-Catch em INSERTs críticos (verificar se já existe)

---

## ANÁLISE DE ROBUSTEZ

### Pontos Fortes ✅
1. Multi-tenancy corretamente implementado
2. Campos de mídia alinhados com banco
3. Estrutura clara de salvamento (User Message + AI Response)
4. Usa node de preparação (Prepare: Chat Context) - boa prática

### Pontos de Atenção ⚠️
1. session_id não é único por conversa
2. Precisa validação manual do fluxo visual (caminhos com/sem mídia)
3. Não há evidência de Try-Catch (verificar manualmente)
4. Falta timestamp de criação de sessão

### Recomendações de Melhoria

#### Curto Prazo
- [ ] Implementar session_id único (UUID v7)
- [ ] Adicionar campo `session_started_at` para tracking
- [ ] Validar error handling nos INSERTs

#### Médio Prazo
- [ ] Implementar lógica de "nova sessão" baseada em timeout
- [ ] Adicionar metadata de sessão (device, location se aplicável)
- [ ] Criar índice composto em (contact_id, session_id) para performance

#### Longo Prazo
- [ ] Implementar analytics de sessão
- [ ] Permitir "retomar conversa anterior"
- [ ] Expor session_id em APIs/webhooks para tracking externo

---

## ⚠️ AÇÃO NECESSÁRIA

Este workflow PRECISA de:

1. **Revisão manual no n8n visual:**
   - Abrir workflow no editor visual
   - Traçar caminho COMPLETO para mensagem COM mídia
   - Traçar caminho COMPLETO para mensagem SEM mídia
   - Validar que ambos chegam ao mesmo destino final

2. **Teste real:**
   - Enviar mensagem de texto puro (sem mídia)
   - Verificar que salva corretamente em chat_history
   - Verificar que has_media = false

3. **Decisão de produto:**
   - Como definir "nova sessão"?
   - Manter histórico unificado ou separar por sessão?
   - Timeout de inatividade?

---

## COMPARAÇÃO: Workflow 01 vs 02

| Aspecto | Workflow 01 (Router) | Workflow 02 (Chat) |
|---------|----------------------|-------------------|
| Multi-tenant | 🔴 QUEBRADO | ✅ CORRETO |
| Campos DB | N/A | ✅ CORRETO |
| Security | 🔴 CRÍTICO | 🟠 MÉDIO |
| Prioridade | URGENTE | ALTA |

---

## PRÓXIMOS PASSOS

1. Decidir estratégia de session_id (produto + tech)
2. Implementar nova lógica de session_id
3. Testar fluxo completo com e sem mídia
4. Validar error handling
5. Documentar comportamento de sessões

---

## NOTAS TÉCNICAS

### Node: Prepare: Chat Context
- Tipo: n8n-nodes-base.set (v3.4)
- Função: Normaliza e prepara dados para chat
- 22 campos mapeados
- ✅ Boa separação de responsabilidades

### Dependências
- Recebe dados já normalizados (company_id, contact_id presentes)
- Node anterior deve garantir integridade dos dados
- Session_id é gerado NESTE ponto (não vem de fora)

### Sugestão de Arquitetura
```
[Webhook] → [Normalize] → [Prepare Context + Generate Session ID] → [Route: Has Media?]
                                                                           ↓
                                        [Yes: Process Media] ← → [No: Direct Save]
                                                                           ↓
                                                                    [Save to chat_history]
```

---

**Analisado em:** 2025-10-27
**Fase:** 2B/5
**Status:** ⚠️ AJUSTES RECOMENDADOS (não urgentes, mas importantes)
**Próxima análise:** Workflows 03-05
