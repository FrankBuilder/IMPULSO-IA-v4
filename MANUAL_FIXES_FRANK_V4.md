# 🔧 MANUAL DE CORREÇÕES - FRANK V4

**Data:** 2025-10-27
**Modo:** Instruções manuais para implementação

---

## 📋 ÍNDICE

### QUICK WINS (5-30 min)
1. [Fix #1: Corrigir comando #padrao](#fix-1-corrigir-comando-padrao) - 5 min
2. [Fix #2: Mensagem de erro para vídeos](#fix-2-mensagem-de-erro-para-vídeos) - 30 min
3. [Fix #3: Script para DROP de tabelas](#fix-3-script-para-drop-de-tabelas) - 10 min

### MEDIUM EFFORT (2-6 horas)
4. [Fix #4: Armazenar arquivos de áudio](#fix-4-armazenar-arquivos-de-áudio) - 3h
5. [Fix #5: Implementar execution_logs](#fix-5-implementar-execution_logs) - 4h
6. [Fix #6: Implementar ai_decisions](#fix-6-implementar-ai_decisions) - 3h
7. [Fix #7: Implementar followup_steps](#fix-7-implementar-followup_steps) - 6h
8. [Fix #8: Debug followups não enviando](#fix-8-debug-followups-não-enviando) - 2-4h

---

# 🟢 QUICK WINS

## Fix #1: Corrigir comando #padrao

**Prioridade:** 🔴 P0
**Tempo estimado:** 5 minutos
**Arquivo:** `Process Commands _ v4.json`

### Problema
O comando `#padrao` está forçando resposta em texto quando deveria fazer "espelhamento" (texto→texto, áudio→áudio).

### Solução

#### Passo 1: Abrir workflow no n8n
1. Abra n8n
2. Procure o workflow: **"Process Commands | v4"**
3. Localize o node: **"Set Default Preference"**

#### Passo 2: Modificar valores
No node "Set Default Preference":

**ANTES (incorreto):**
```
Field Values:
  audio_response: false
  text_response: true   ← ERRADO!
```

**DEPOIS (correto):**
```
Field Values:
  audio_response: false
  text_response: false   ← AMBOS FALSE!
```

#### Passo 3: Salvar e testar

1. Clique em **"Save"** no workflow
2. Teste enviando:
   - Texto: `#padrao`
   - Envie um ÁUDIO qualquer
   - Frank deve responder em ÁUDIO
   - Envie um TEXTO qualquer
   - Frank deve responder em TEXTO

**Resultado esperado:**
✅ Sistema espelha o formato do usuário

---

## Fix #2: Mensagem de erro para vídeos

**Prioridade:** 🟠 P1
**Tempo estimado:** 30 minutos
**Arquivo:** `Frank Webhook - Main Router _ v4.json`

### Problema
Quando usuário envia vídeo, sistema não processa e não dá feedback.

### Solução

#### Passo 1: Abrir workflow
1. Abra workflow: **"Frank Webhook - Main Router | v4"**
2. Localize o node: **"Route: Contact Status"** (ou similar)

#### Passo 2: Adicionar Check de Vídeo

**ADICIONAR NOVO NODE** após "Normalize Evolution Data":

**Node Type:** `IF`
**Nome:** `Check: Is Video`

**Configuração:**
```
Conditions:
  - Field: {{ $json.media_type }}
  - Operation: equals
  - Value: "video"
```

#### Passo 3: Adicionar Node de Resposta

**ADICIONAR NOVO NODE** conectado ao output TRUE de "Check: Is Video":

**Node Type:** `Code`
**Nome:** `Prepare: Video Error Message`

**Código:**
```javascript
return [{
  json: {
    message: "Desculpe, ainda não consigo processar vídeos. 📹\n\n" +
             "Que tal me enviar uma imagem, áudio ou mensagem de texto? " +
             "Estou aqui para ajudar! 😊",
    phone_number: $json.phone_number,
    evolution_api_url: $json.evolution_api_url,
    evolution_instance: $json.evolution_instance,
    evolution_api_key: $json.evolution_api_key
  }
}];
```

#### Passo 4: Adicionar Node de Envio

**ADICIONAR NOVO NODE** após "Prepare: Video Error Message":

**Node Type:** `HTTP Request`
**Nome:** `Send: Video Error Message`

**Configuração:**
```
Method: POST
URL: {{ $json.evolution_api_url }}/message/sendText/{{ $json.evolution_instance }}

Headers:
  - Content-Type: application/json
  - apikey: {{ $json.evolution_api_key }}

Body (JSON):
{
  "number": "{{ $json.phone_number }}",
  "text": "{{ $json.message }}"
}
```

#### Passo 5: Conectar nodes

```
Normalize Evolution Data
  → Check: Is Video
      → [TRUE] Prepare: Video Error Message
                → Send: Video Error Message
                    → (fim - não processa mais nada)
      → [FALSE] (continua fluxo normal)
```

#### Passo 6: Testar

1. Envie um vídeo para o WhatsApp
2. Deve receber a mensagem de erro
3. Sistema não deve processar o vídeo

**Resultado esperado:**
✅ Usuário recebe feedback amigável
✅ Sistema não tenta processar vídeo

---

## Fix #3: Script para DROP de tabelas

**Prioridade:** 🟡 P2
**Tempo estimado:** 10 minutos
**Tipo:** SQL Script

### Problema
3 tabelas órfãs nunca usadas ocupam espaço no banco.

### Solução

#### Passo 1: Verificar se são VIEWs ou TABLEs

Execute no Supabase SQL Editor:

```sql
-- Verificar tipo de objeto
SELECT
  table_name,
  table_type
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN (
    'corev4_followup_sequences',
    'corev4_chats',
    'corev4_followup_configs_with_steps'
  )
ORDER BY table_name;
```

#### Passo 2: Verificar dependências

```sql
-- Verificar FKs que REFERENCIAM estas tabelas
SELECT
  tc.table_name as referencing_table,
  kcu.column_name as referencing_column,
  ccu.table_name as referenced_table,
  ccu.column_name as referenced_column
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage ccu
  ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND ccu.table_name IN (
    'corev4_followup_sequences',
    'corev4_chats',
    'corev4_followup_configs_with_steps'
  );
```

#### Passo 3: Verificar se há dados

```sql
-- Contar registros (se houver)
SELECT
  'corev4_followup_sequences' as table_name,
  COUNT(*) as record_count
FROM corev4_followup_sequences

UNION ALL

SELECT
  'corev4_chats',
  COUNT(*)
FROM corev4_chats

UNION ALL

SELECT
  'corev4_followup_configs_with_steps',
  COUNT(*)
FROM corev4_followup_configs_with_steps;
```

#### Passo 4: Fazer BACKUP antes de dropar

```sql
-- BACKUP (caso precise restaurar)
CREATE TABLE _backup_corev4_followup_sequences AS
  SELECT * FROM corev4_followup_sequences;

CREATE TABLE _backup_corev4_chats AS
  SELECT * FROM corev4_chats;

-- Se configs_with_steps for VIEW, pule este backup
CREATE TABLE _backup_corev4_followup_configs_with_steps AS
  SELECT * FROM corev4_followup_configs_with_steps;
```

#### Passo 5: DROP (se tudo OK acima)

```sql
-- DROP TABLES/VIEWS
-- Se for VIEW, use DROP VIEW
-- Se for TABLE, use DROP TABLE

-- Exemplo para TABLE:
DROP TABLE IF EXISTS corev4_followup_sequences CASCADE;
DROP TABLE IF EXISTS corev4_chats CASCADE;

-- Exemplo para VIEW:
DROP VIEW IF EXISTS corev4_followup_configs_with_steps CASCADE;
```

#### Passo 6: Verificar

```sql
-- Confirmar que foram dropadas
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name LIKE 'corev4_%'
ORDER BY table_name;
```

**Resultado esperado:**
✅ Tabelas removidas
✅ Banco mais limpo
✅ Backups criados por segurança

---

# 🟠 MEDIUM EFFORT

## Fix #4: Armazenar arquivos de áudio

**Prioridade:** 🟠 P1
**Tempo estimado:** 3 horas
**Arquivo:** `Process Audio Message _ v4.json`

### Problema
Áudio é transcrito mas o arquivo .opus não é salvo no storage (apenas a transcrição é salva).

### Solução

#### Passo 1: Criar bucket no Supabase

1. Acesse Supabase Dashboard
2. Vá em **Storage**
3. Crie novo bucket: `chat-audios`
4. Configurações:
   - **Public:** false (privado)
   - **File size limit:** 10 MB
   - **Allowed MIME types:** audio/ogg, audio/opus, audio/mpeg

#### Passo 2: Abrir workflow

Abra: **"Process Audio Message | v4"**

#### Passo 3: Adicionar node para salvar mensagem do usuário

**ADICIONAR NOVO NODE** após "Execute: Transcribe Audio":

**Node Type:** `Supabase`
**Nome:** `Save: User Audio Message`
**Operation:** Insert

**Configuração:**
```
Table: corev4_chat_history

Fields:
  - session_id: {{ $('Prepare: Audio Context').item.json.session_id }}
  - contact_id: {{ $('Prepare: Audio Context').item.json.contact_id }}
  - company_id: {{ $('Prepare: Audio Context').item.json.company_id }}
  - role: user
  - message: {{ $('Execute: Transcribe Audio').item.json.text }}
  - message_type: audio
  - has_media: true
  - media_url: {{ $('Prepare: Audio Context').item.json.media_url }}
  - media_mime_type: audio/ogg; codecs=opus
  - message_timestamp: {{ $now }}
```

#### Passo 4: Adicionar node para upload do áudio

**ADICIONAR NOVO NODE** após "Save: User Audio Message":

**Node Type:** `HTTP Request`
**Nome:** `Upload: Audio to Storage`

**Configuração:**
```
Method: POST
URL: https://uosauvyafotuhktpjjkm.supabase.co/storage/v1/object/chat-audios/{{ $('Prepare: Audio Context').item.json.company_id }}/{{ $('Prepare: Audio Context').item.json.contact_id }}/{{ $('Save: User Audio Message').item.json.id }}.opus

Headers:
  - Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVvc2F1dnlhZm90dWhrdHBqamttIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjU0MDgxODcsImV4cCI6MjA0MDk4NDE4N30.3UzrMj0gw1aY8fcJw9649LjIKryLTNgmDNd9EuIpOx8
  - apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVvc2F1dnlhZm90dWhrdHBqamttIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjU0MDgxODcsImV4cCI6MjA0MDk4NDE4N30.3UzrMj0gw1aY8fcJw9649LjIKryLTNgmDNd9EuIpOx8
  - Content-Type: audio/ogg; codecs=opus

Body Type: Raw/Custom
Body: {{ $('Prepare: Audio Context').item.json.base64_audio }}

Response Format: JSON
```

**IMPORTANTE:** Você precisará converter o base64 para binary. Adicione um node Code antes:

**Node Type:** `Code`
**Nome:** `Prepare: Audio Binary`

**Código:**
```javascript
const audioBase64 = $('Prepare: Audio Context').item.json.base64_audio;

// Remover data URI prefix se houver
const base64Clean = audioBase64.replace(/^data:audio\/\w+;base64,/, '');

// Converter para Buffer
const binaryBuffer = Buffer.from(base64Clean, 'base64');

return [{
  json: $input.item.json,
  binary: {
    audio_data: {
      data: binaryBuffer.toString('base64'),
      mimeType: 'audio/ogg; codecs=opus',
      fileExtension: 'opus',
      fileName: 'audio.opus'
    }
  }
}];
```

#### Passo 5: Adicionar node para salvar metadata

**ADICIONAR NOVO NODE** após "Upload: Audio to Storage":

**Node Type:** `Supabase`
**Nome:** `Save: Audio Media Info`
**Operation:** Insert

**Configuração:**
```
Table: corev4_message_media

Fields:
  - message_id: {{ $('Save: User Audio Message').item.json.id }}
  - company_id: {{ $('Prepare: Audio Context').item.json.company_id }}
  - storage_provider: supabase
  - storage_path: chat-audios/{{ $('Prepare: Audio Context').item.json.company_id }}/{{ $('Prepare: Audio Context').item.json.contact_id }}/{{ $('Save: User Audio Message').item.json.id }}.opus
  - storage_url: https://uosauvyafotuhktpjjkm.supabase.co/storage/v1/object/public/chat-audios/{{ $('Prepare: Audio Context').item.json.company_id }}/{{ $('Prepare: Audio Context').item.json.contact_id }}/{{ $('Save: User Audio Message').item.json.id }}.opus
  - original_url: {{ $('Prepare: Audio Context').item.json.media_url }}
  - media_type: audio
  - mime_type: audio/ogg; codecs=opus
  - file_size: {{ $binary.audio_data ? Buffer.byteLength($binary.audio_data.data, 'base64') : null }}
```

#### Passo 6: Reconectar fluxo

```
Execute: Transcribe Audio
  → Save: User Audio Message
      → Prepare: Audio Binary
          → Upload: Audio to Storage
              → Save: Audio Media Info
                  → (continua fluxo normal)
```

#### Passo 7: Testar

1. Envie um áudio para o WhatsApp
2. Verifique no Supabase Storage > chat-audios se o arquivo foi salvo
3. Verifique na tabela `corev4_message_media` se há um registro
4. Verifique na tabela `corev4_chat_history` se há o registro com has_media=true

**Resultado esperado:**
✅ Arquivo .opus salvo no storage
✅ Metadata em corev4_message_media
✅ Registro em chat_history com media_url

---

## Fix #5: Implementar execution_logs

**Prioridade:** 🔴 P0
**Tempo estimado:** 4 horas
**Arquivos:** Múltiplos workflows

### Problema
Nenhum workflow registra logs de execução. Sem audit trail.

### Solução

Esta solução é modular - você pode implementar aos poucos, começando pelos workflows mais críticos.

#### Estrutura da tabela corev4_execution_logs

```sql
-- Verificar estrutura atual
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'corev4_execution_logs'
ORDER BY ordinal_position;
```

#### Passo 1: Criar função helper (opcional mas recomendado)

```sql
-- Função para simplificar INSERT de logs
CREATE OR REPLACE FUNCTION log_execution(
  p_workflow_name VARCHAR(100),
  p_execution_type VARCHAR(50),
  p_contact_id INTEGER,
  p_company_id INTEGER,
  p_status VARCHAR(20),
  p_metadata JSONB DEFAULT '{}'::jsonb,
  p_execution_time_ms INTEGER DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
  new_id INTEGER;
BEGIN
  INSERT INTO corev4_execution_logs (
    workflow_name,
    execution_type,
    contact_id,
    company_id,
    status,
    metadata,
    execution_time_ms,
    created_at
  ) VALUES (
    p_workflow_name,
    p_execution_type,
    p_contact_id,
    p_company_id,
    p_status,
    p_metadata,
    p_execution_time_ms,
    NOW()
  ) RETURNING id INTO new_id;

  RETURN new_id;
END;
$$ LANGUAGE plpgsql;
```

#### Passo 2: Implementar em "Frank Chat | v4"

**ADICIONAR NODE** após "AI Agent Frank":

**Node Type:** `Postgres`
**Nome:** `Log: Chat Execution`
**Operation:** Execute Query

**Query:**
```sql
SELECT log_execution(
  'Frank Chat',                    -- workflow_name
  'chat_response',                 -- execution_type
  {{ $('Prepare: Chat Context').item.json.contact_id }},
  {{ $('Prepare: Chat Context').item.json.company_id }},
  'success',                       -- status
  jsonb_build_object(
    'message_type', '{{ $('Prepare: Chat Context').item.json.message_type }}',
    'has_media', {{ $('Prepare: Chat Context').item.json.has_media }},
    'response_mode', '{{ $('Determine: Response Mode').item.json.response_mode }}',
    'model_used', '{{ $('AI Agent Frank').item.json.model }}',
    'tokens_used', {{ $('AI Agent Frank').item.json.usage.totalTokens || 0 }},
    'cost_usd', {{ $('AI Agent Frank').item.json.usage.cost || 0 }}
  ),
  NULL                             -- execution_time_ms (pode calcular depois)
);
```

#### Passo 3: Implementar em "Execute Followup Processor | v4"

**ADICIONAR NODE** após "Send: WhatsApp Message":

**Node Type:** `Postgres`
**Nome:** `Log: Followup Execution`
**Operation:** Execute Query

**Query:**
```sql
SELECT log_execution(
  'Execute Followup Processor',
  'followup_sent',
  {{ $('Prepare: Followup Context').item.json.contact_id }},
  {{ $('Prepare: Followup Context').item.json.company_id }},
  'success',
  jsonb_build_object(
    'campaign_id', {{ $('Prepare: Followup Context').item.json.campaign_id }},
    'execution_id', {{ $('Prepare: Followup Context').item.json.execution_id }},
    'step', {{ $('Prepare: Followup Context').item.json.step }},
    'total_steps', {{ $('Prepare: Followup Context').item.json.total_steps }},
    'generated_message_length', length('{{ $('AI: Generate Message').item.json.output }}'),
    'anum_score', {{ $('Prepare: Followup Context').item.json.anum_score }}
  ),
  NULL
);
```

#### Passo 4: Implementar em "Process Commands | v4"

**ADICIONAR NODE** após cada comando ser processado (pode usar um Merge):

**Node Type:** `Postgres`
**Nome:** `Log: Command Execution`
**Operation:** Execute Query

**Query:**
```sql
SELECT log_execution(
  'Process Commands',
  'command_{{ $('Prepare: Command Data').item.json.command }}',  -- Ex: command_#audio
  {{ $('Prepare: Command Data').item.json.contact_id }},
  {{ $('Prepare: Command Data').item.json.company_id }},
  'success',
  jsonb_build_object(
    'command', '{{ $('Prepare: Command Data').item.json.command }}',
    'message_type', '{{ $('Prepare: Command Data').item.json.message_type }}'
  ),
  NULL
);
```

#### Passo 5: Implementar logs de ERROR

Em TODOS os workflows, adicione nodes de Error Handling:

**Node Type:** `Postgres`
**Nome:** `Log: Error`
**Operation:** Execute Query

**Query:**
```sql
SELECT log_execution(
  '{{ $workflow.name }}',
  'error',
  {{ $json.contact_id || NULL }},
  {{ $json.company_id || NULL }},
  'error',
  jsonb_build_object(
    'error_message', '{{ $json.error.message }}',
    'error_stack', '{{ $json.error.stack }}',
    'node_name', '{{ $node.name }}'
  ),
  NULL
);
```

#### Passo 6: Testar

Execute workflows e verifique:

```sql
-- Verificar logs recentes
SELECT
  id,
  workflow_name,
  execution_type,
  contact_id,
  status,
  metadata,
  created_at
FROM corev4_execution_logs
ORDER BY created_at DESC
LIMIT 50;
```

**Resultado esperado:**
✅ Cada execução gera um log
✅ Metadata detalhada de cada operação
✅ Erros são logados

---

## Fix #6: Implementar ai_decisions

**Prioridade:** 🔴 P0
**Tempo estimado:** 3 horas
**Arquivo:** `Execute Followup Processor _ v4.json`

### Problema
Decisões da IA no processo de followup não são registradas.

### Solução

#### Passo 1: Entender estrutura da tabela

```sql
-- Verificar estrutura
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'corev4_ai_decisions'
ORDER BY ordinal_position;
```

Campos principais:
- `followup_execution_id` - FK para corev4_followup_executions
- `model_used` - Ex: gpt-4.1-mini-2025-04-14
- `decision` - Ex: send, skip, qualified
- `confidence_score` - 0-100
- `reasoning` - Texto explicando a decisão
- `context_snapshot` - JSONB com contexto completo
- `tokens_used`, `cost_usd`, `processing_time_ms`

#### Passo 2: Abrir workflow

Abra: **"Execute Followup Processor | v4"**

#### Passo 3: Adicionar node ANTES de "Send: WhatsApp Message"

**ADICIONAR NODE** após "AI: Generate Message":

**Node Type:** `Code`
**Nome:** `Capture: AI Decision Context`

**Código:**
```javascript
const aiOutput = $('AI: Generate Message').item.json;
const context = $('Prepare: Followup Context').item.json;

// Calcular tempo de processamento (se possível)
const startTime = Date.now(); // Você pode pegar isso de um node anterior

return [{
  json: {
    ...aiOutput,
    ...context,
    // Contexto para decisão
    decision_data: {
      decision: 'send',
      model_used: aiOutput.model || 'gpt-4.1-mini-2025-04-14',
      tokens_used: aiOutput.usage?.totalTokens || 0,
      cost_usd: aiOutput.usage?.cost || 0,
      reasoning: `Generated followup for step ${context.step}/${context.total_steps}. ` +
                 `ANUM score: ${context.anum_score}. ` +
                 `Lead ${context.lead_responded ? 'has' : 'has not'} responded before.`,
      confidence_score: context.lead_responded ? 75 : 50,
      context_snapshot: {
        step: context.step,
        total_steps: context.total_steps,
        anum_score: context.anum_score,
        qualification_stage: context.qualification_stage,
        lead_responded: context.lead_responded,
        recent_messages_count: context.recent_messages.split('\n').length,
        generated_message_preview: aiOutput.output.substring(0, 100)
      }
    }
  }
}];
```

#### Passo 4: Adicionar node para INSERT na tabela

**ADICIONAR NODE** após "Capture: AI Decision Context":

**Node Type:** `Supabase`
**Nome:** `Save: AI Decision`
**Operation:** Insert

**Configuração:**
```
Table: corev4_ai_decisions

Fields:
  - followup_execution_id: {{ $('Prepare: Followup Context').item.json.execution_id }}
  - model_used: {{ $json.decision_data.model_used }}
  - decision: {{ $json.decision_data.decision }}
  - confidence_score: {{ $json.decision_data.confidence_score }}
  - reasoning: {{ $json.decision_data.reasoning }}
  - context_snapshot: {{ $json.decision_data.context_snapshot }}
  - processing_time_ms: {{ $json.decision_data.tokens_used * 10 }}  (estimativa)
  - tokens_used: {{ $json.decision_data.tokens_used }}
  - cost_usd: {{ $json.decision_data.cost_usd }}
```

#### Passo 5: Adicionar também para SKIP decisions

**ADICIONAR NODE** após "Skip: Qualified" e "Skip: Disqualified":

**Node Type:** `Supabase`
**Nome:** `Save: Skip Decision`
**Operation:** Insert

**Para Qualified:**
```
Table: corev4_ai_decisions

Fields:
  - followup_execution_id: {{ $(' Loop: Over Followups').item.json.execution_id }}
  - model_used: rule_based
  - decision: skip_qualified
  - confidence_score: 100
  - reasoning: Lead is qualified (ANUM score {{ $(' Loop: Over Followups').item.json.anum_score }} >= {{ $(' Loop: Over Followups').item.json.qualification_threshold }}). Stopping followup campaign.
  - context_snapshot: {{ { anum_score: $(' Loop: Over Followups').item.json.anum_score, threshold: $(' Loop: Over Followups').item.json.qualification_threshold } }}
  - processing_time_ms: 0
  - tokens_used: 0
  - cost_usd: 0
```

**Para Disqualified:**
```
Table: corev4_ai_decisions

Fields:
  - followup_execution_id: {{ $(' Loop: Over Followups').item.json.execution_id }}
  - model_used: rule_based
  - decision: skip_disqualified
  - confidence_score: 100
  - reasoning: Lead is disqualified (ANUM score {{ $(' Loop: Over Followups').item.json.anum_score }} <= {{ $(' Loop: Over Followups').item.json.disqualification_threshold }}). Stopping followup campaign.
  - context_snapshot: {{ { anum_score: $(' Loop: Over Followups').item.json.anum_score, threshold: $(' Loop: Over Followups').item.json.disqualification_threshold } }}
  - processing_time_ms: 0
  - tokens_used: 0
  - cost_usd: 0
```

#### Passo 6: Reconectar fluxo

```
AI: Generate Message
  → Capture: AI Decision Context
      → Save: AI Decision
          → Send: WhatsApp Message
              → ...

Skip: Qualified
  → Save: Skip Decision (qualified)
      → Merge: Skip Paths

Skip: Disqualified
  → Save: Skip Decision (disqualified)
      → Merge: Skip Paths
```

#### Passo 7: Testar

```sql
-- Verificar decisões registradas
SELECT
  ad.id,
  ad.decision,
  ad.model_used,
  ad.confidence_score,
  ad.reasoning,
  ad.context_snapshot,
  ad.tokens_used,
  ad.cost_usd,
  fe.step,
  c.full_name,
  ad.created_at
FROM corev4_ai_decisions ad
JOIN corev4_followup_executions fe ON ad.followup_execution_id = fe.id
JOIN corev4_contacts c ON fe.contact_id = c.id
ORDER BY ad.created_at DESC
LIMIT 20;
```

**Resultado esperado:**
✅ Decisões de envio são registradas
✅ Decisões de skip são registradas
✅ Metadata completa para análise

---

## Fix #7: Implementar followup_steps

**Prioridade:** 🟠 P1
**Tempo estimado:** 6 horas
**Arquivos:** `Create Contact & Followup Campaign _ v4.json` e `Execute Followup Processor _ v4.json`

### Problema
Tabela `corev4_followup_steps` existe mas nunca é usada. Timing está hardcoded e não há "objetivo macro" para cada step.

### Solução

#### Parte 1: Popular tabela corev4_followup_steps

```sql
-- 1. Verificar se já existe uma config padrão
SELECT id, name FROM corev4_followup_configs LIMIT 1;

-- Assumindo que config_id = 1 é a padrão
-- Se não houver, crie uma primeiro:

INSERT INTO corev4_followup_configs (
  name,
  qualification_threshold,
  disqualification_threshold,
  max_followups,
  created_at
) VALUES (
  'Default ANUM Qualification',
  75,   -- >= 75 = qualified
  25,   -- <= 25 = disqualified
  5,    -- 5 steps
  NOW()
) RETURNING id;

-- Agora popular os steps (use o config_id retornado acima)
INSERT INTO corev4_followup_steps (
  config_id,
  step_number,
  wait_hours,
  message_template,
  ai_prompt,
  created_at
) VALUES
  (
    1,  -- config_id
    1,
    1,  -- 1 hora após inatividade
    NULL,  -- Sem template fixo, vai gerar com IA
    'STEP 1 de 5: REENGAJAMENTO SUAVE

CONTEXTO: Primeira tentativa após ~1 hora de inatividade no chat.

OBJETIVO MACRO: Retomar a conversa de forma natural e não invasiva, demonstrando interesse genuíno pela situação do lead.

TOM: Leve, útil, sem pressão. Como um amigo que está checando se pode ajudar em algo.

ESTRATÉGIA:
- Fazer referência sutil ao último tópico discutido (usar histórico)
- Oferecer algo de valor imediato (insight, dica, recurso)
- NÃO mencionar "você não respondeu" ou similar
- Parecer uma continuação natural da conversa

TAMANHO: 2-3 linhas no máximo

EXEMPLO DE ABORDAGEM:
"Estava pensando sobre [tópico mencionado]. [Insight rápido ou pergunta curiosa]. Como você enxerga isso?"',
    NOW()
  ),
  (
    1,
    2,
    25,  -- ~1 dia (25 horas)
    NULL,
    'STEP 2 de 5: AGREGAR VALOR

CONTEXTO: Segunda tentativa após ~1 dia. Lead ainda não respondeu ao Step 1.

OBJETIVO MACRO: Demonstrar expertise e valor sem vender. Posicionar como consultor útil, não como vendedor insistente.

TOM: Educativo, consultivo, profissional mas acessível.

ESTRATÉGIA:
- Compartilhar insight valioso relacionado ao negócio do lead
- Mostrar compreensão profunda do desafio dele (usar ANUM scores se disponível)
- Fazer UMA pergunta que provoca reflexão
- NÃO mencionar a CoreConnect ainda, foco no problema dele

TAMANHO: 3-4 linhas

EXEMPLO DE ABORDAGEM:
"[Nome], percebi que empresas do seu setor têm enfrentado [desafio específico]. [Insight ou estatística]. Você tem notado isso também?"',
    NOW()
  ),
  (
    1,
    3,
    73,  -- ~3 dias
    NULL,
    'STEP 3 de 5: URGÊNCIA SUTIL

CONTEXTO: Terceira tentativa após ~3 dias sem resposta.

OBJETIVO MACRO: Criar senso de timing adequado sem ser pushy. Demonstrar que há uma janela de oportunidade, não pressão de venda.

TOM: Profissional com senso de oportunidade. Respeitoso mas direto sobre valor do tempo.

ESTRATÉGIA:
- Mencionar tendência ou mudança no mercado que afeta o lead
- Criar FOMO saudável (medo de perder oportunidade, não medo de perder desconto)
- Mostrar que você valoriza o tempo dele (e o seu)
- Abrir porta para conexão humana se houver interesse

TAMANHO: 3-4 linhas

EXEMPLO DE ABORDAGEM:
"[Nome], semana intensa aqui! Notei que [tendência de mercado]. Empresas que se moveram rápido estão [resultado]. Faz sentido conversarmos sobre isso?"',
    NOW()
  ),
  (
    1,
    4,
    145,  -- ~6 dias
    NULL,
    'STEP 4 de 5: ÚLTIMA CHANCE

CONTEXTO: Quarta tentativa após ~6 dias. Penúltima mensagem da campanha.

OBJETIVO MACRO: Comunicar de forma respeitosa e direta que essa é a última tentativa proativa, mas deixar porta aberta.

TOM: Respeitoso, direto, profissional. Reconhecer que talvez não seja o momento certo.

ESTRATÉGIA:
- Reconhecer que timing pode não estar certo
- Reforçar uma ÚLTIMA VEZ o valor que pode entregar (resumo de 1 linha)
- Dar opção clara: responder agora ou você entenderá que não é o momento
- Manter dignidade e não parecer desesperado

TAMANHO: 3-4 linhas

EXEMPLO DE ABORDAGEM:
"[Nome], imagino que não é o momento certo, e está tudo bem. Se mudar, estou à disposição para [valor específico]. Prefiro respeitar seu tempo. Faz sentido conversarmos ou melhor deixar para outro momento?"',
    NOW()
  ),
  (
    1,
    5,
    313,  -- ~13 dias
    NULL,
    'STEP 5 de 5: DESPEDIDA GRACIOSA

CONTEXTO: Última mensagem após ~13 dias sem resposta. Encerramento da campanha de followup.

OBJETIVO MACRO: Encerrar com classe e plantar semente para futuro. Deixar impressão positiva mesmo sem conversão.

TOM: Gracioso, sem ressentimento, maduro. Demonstrar que você é profissional de alto nível.

ESTRATÉGIA:
- Assumir que não é o momento certo e está tudo bem
- Deixar porta aberta para futuro (sem pressão)
- Oferecer algo de valor mesmo sem retorno (recurso gratuito, artigo, etc)
- Terminar com nota positiva e memorável

TAMANHO: 3-4 linhas

EXEMPLO DE ABORDAGEM:
"[Nome], vou parar por aqui! Se no futuro fizer sentido conversar sobre [tema], pode me chamar. Deixo aqui [recurso útil] que pode ajudar no seu dia a dia. Sucesso por aí! 🚀"',
    NOW()
  );
```

#### Parte 2: Modificar "Create Contact & Followup Campaign | v4"

**TROCAR Node que cria followup_executions:**

Localize o node que faz INSERT em `corev4_followup_executions` (provavelmente usa o hardcoded `[1, 25, 73, 145, 313]`).

**SUBSTITUIR por dois nodes:**

**Node 1:** Buscar steps da config

**Node Type:** `Postgres`
**Nome:** `Fetch: Followup Steps`
**Operation:** Execute Query

**Query:**
```sql
SELECT
  fs.step_number,
  fs.wait_hours,
  fs.ai_prompt
FROM corev4_followup_campaigns fc
JOIN corev4_followup_configs cfg ON fc.config_id = cfg.id
JOIN corev4_followup_steps fs ON cfg.id = fs.config_id
WHERE fc.id = {{ $json.campaign_id }}
ORDER BY fs.step_number ASC;
```

**Node 2:** Criar executions baseado nos steps

**Node Type:** `Code`
**Nome:** `Generate: Followup Executions`

**Código:**
```javascript
const steps = $input.all();
const campaign = $('Create: Followup Campaign').item.json;
const contact = $('Prepare: Campaign Data').item.json;

const executions = [];
let accumulatedHours = 0;

for (const step of steps) {
  accumulatedHours += step.wait_hours;

  const scheduledDate = new Date();
  scheduledDate.setHours(scheduledDate.getHours() + accumulatedHours);

  executions.push({
    campaign_id: campaign.id,
    contact_id: contact.contact_id,
    company_id: contact.company_id,
    step: step.step_number,
    total_steps: steps.length,
    scheduled_at: scheduledDate.toISOString(),
    executed: false,
    should_send: true,
    ai_prompt: step.ai_prompt,  // ← NOVO! Passar prompt para execution
    created_at: new Date().toISOString()
  });
}

return executions.map(exec => ({ json: exec }));
```

**Node 3:** Fazer INSERT em batch

**Node Type:** `Postgres`
**Nome:** `Insert: Followup Executions`
**Operation:** Execute Query

**Query:**
```sql
INSERT INTO corev4_followup_executions (
  campaign_id,
  contact_id,
  company_id,
  step,
  total_steps,
  scheduled_at,
  executed,
  should_send,
  generation_context,
  created_at
)
SELECT
  {{ $json.campaign_id }},
  {{ $json.contact_id }},
  {{ $json.company_id }},
  {{ $json.step }},
  {{ $json.total_steps }},
  '{{ $json.scheduled_at }}'::timestamp,
  {{ $json.executed }},
  {{ $json.should_send }},
  jsonb_build_object('ai_prompt', '{{ $json.ai_prompt }}'),
  '{{ $json.created_at }}'::timestamp;
```

#### Parte 3: Modificar "Execute Followup Processor | v4"

**MODIFICAR Node "Prepare: Followup Context":**

Adicione ao código existente:

```javascript
// ... código existente ...

// BUSCAR AI PROMPT do step atual da tabela followup_steps
// Você precisará fazer uma query adicional ou incluir no fetch inicial

return {
  // ... campos existentes ...

  // SUBSTITUIR stepContext hardcoded por:
  step_context: lead.generation_context?.ai_prompt || stepContext,  // Fallback para hardcoded

  // ... resto dos campos ...
};
```

**OU MELHOR: Adicionar novo node antes de "Prepare: Followup Context":**

**Node Type:** `Postgres`
**Nome:** `Fetch: Step AI Prompt`
**Operation:** Execute Query

**Query:**
```sql
SELECT
  fs.ai_prompt,
  fs.message_template
FROM corev4_followup_executions fe
JOIN corev4_followup_campaigns fc ON fe.campaign_id = fc.id
JOIN corev4_followup_configs cfg ON fc.config_id = cfg.id
JOIN corev4_followup_steps fs ON cfg.id = fs.config_id AND fs.step_number = fe.step
WHERE fe.id = {{ $(' Loop: Over Followups').item.json.execution_id }}
LIMIT 1;
```

Depois modificar "Prepare: Followup Context" para usar:

```javascript
const stepPrompt = $('Fetch: Step AI Prompt').first()?.json?.ai_prompt;

// ... código existente ...

return {
  // ... campos existentes ...
  step_context: stepPrompt || stepContext,  // Usar da tabela, fallback hardcoded
  // ...
};
```

#### Passo 6: Testar

1. Crie um novo contato
2. Verifique se followup_executions foram criadas com timing da tabela
3. Aguarde o primeiro followup
4. Verifique se a mensagem gerada reflete o "objetivo macro" do step

**Resultado esperado:**
✅ Timing vem da tabela (configurável)
✅ AI usa "objetivo macro" de cada step
✅ Sistema é escalável para diferentes configs

---

## Fix #8: Debug followups não enviando

**Prioridade:** 🔴 P0
**Tempo estimado:** 2-4 horas
**Arquivo:** `Execute Followup Processor _ v4.json`

### Problema
Followups não estão sendo enviados. Causa desconhecida.

### Solução - Investigação Sistemática

#### Passo 1: Verificar se há executions pendentes

```sql
-- Verificar quantas executions estão pendentes
SELECT
  COUNT(*) as pending_count,
  MIN(scheduled_at) as oldest_scheduled,
  MAX(scheduled_at) as newest_scheduled
FROM corev4_followup_executions
WHERE executed = false
  AND scheduled_at <= NOW();
```

**Se COUNT = 0:** Problema está na criação de executions.
**Se COUNT > 0:** Problema está no processamento.

#### Passo 2: Verificar campaigns

```sql
-- Verificar status das campanhas
SELECT
  fc.id,
  fc.contact_id,
  fc.should_continue,
  fc.status,
  fc.steps_completed,
  fc.total_steps,
  c.full_name,
  c.opt_out
FROM corev4_followup_campaigns fc
JOIN corev4_contacts c ON fc.contact_id = c.id
WHERE fc.should_continue = false
  OR fc.status != 'active'
ORDER BY fc.created_at DESC
LIMIT 20;
```

**Se muitas com should_continue=false:** Investigar por que estão sendo paradas prematuramente.

#### Passo 3: Verificar thresholds

```sql
-- Verificar se thresholds estão muito agressivos
SELECT
  fc.qualification_threshold,
  fc.disqualification_threshold,
  COUNT(*) as campaign_count,
  AVG(ls.total_score) as avg_anum_score
FROM corev4_followup_configs fc
LEFT JOIN corev4_followup_campaigns camp ON camp.config_id = fc.id
LEFT JOIN corev4_lead_state ls ON camp.contact_id = ls.contact_id
GROUP BY fc.id;
```

**Se avg_anum_score está fora do range:** Muitos leads podem estar sendo skipped.

#### Passo 4: Teste manual do workflow

1. Abra "Execute Followup Processor | v4" no n8n
2. Clique em "Execute Workflow" manualmente
3. Observe o output de cada node:
   - "Fetch: Pending Followups" - Quantos retornou?
   - "Check: Is Qualified?" - Algum passou?
   - "Check: Is Disqualified?" - Algum passou?
   - "AI: Generate Message" - Foi executado?

#### Passo 5: Adicionar debug logging TEMPORÁRIO

**ADICIONAR Node** após "Fetch: Pending Followups":

**Node Type:** `Code`
**Nome:** `DEBUG: Log Fetched Followups`

**Código:**
```javascript
const items = $input.all();

console.log('=== FOLLOWUPS DEBUG ===');
console.log(`Total fetched: ${items.length}`);

items.forEach((item, idx) => {
  console.log(`\nFollowup ${idx + 1}:`);
  console.log(`  - Execution ID: ${item.json.execution_id}`);
  console.log(`  - Contact: ${item.json.contact_name}`);
  console.log(`  - Step: ${item.json.step}/${item.json.total_steps}`);
  console.log(`  - ANUM Score: ${item.json.anum_score}`);
  console.log(`  - Qual Threshold: ${item.json.qualification_threshold}`);
  console.log(`  - Disqual Threshold: ${item.json.disqualification_threshold}`);
  console.log(`  - Should Continue: ${item.json.should_continue}`);
  console.log(`  - Opt Out: ${item.json.opt_out}`);
});

return items;
```

Execute o workflow e verifique o log no n8n.

#### Passo 6: Verificar credenciais da Evolution API

```sql
-- Verificar se companies têm credenciais corretas
SELECT
  id,
  name,
  evolution_api_url,
  evolution_instance,
  LENGTH(evolution_api_key) as api_key_length,
  created_at
FROM corev4_companies;
```

**Se api_key_length = 0 ou NULL:** Problema de configuração.

#### Passo 7: Testar envio manual

**ADICIONAR Node temporário** após "AI: Generate Message":

**Node Type:** `Code`
**Nome:** `DEBUG: Preview Message`

**Código:**
```javascript
console.log('=== MESSAGE PREVIEW ===');
console.log('AI Output:', $json.output);
console.log('Phone:', $('Prepare: Followup Context').item.json.whatsapp);
console.log('API URL:', $('Prepare: Followup Context').item.json.evolution_api_url);

return [$input.item];
```

Se a mensagem está sendo gerada corretamente mas não envia, problema está no node "Send: WhatsApp Message".

#### Passo 8: Verificar resposta da Evolution API

**MODIFICAR Node "Send: WhatsApp Message":**

Adicione logging do response:

```
Options > Response:
  - Full Response: true

Always Output Data: true
```

Depois adicione um node Code após para logar:

```javascript
console.log('=== EVOLUTION API RESPONSE ===');
console.log('Status Code:', $json.statusCode);
console.log('Response Body:', JSON.stringify($json.body, null, 2));

return [$input.item];
```

#### Passo 9: Verificar se followup foi marcado como executado indevidamente

```sql
-- Verificar executions marcadas como executed mas sem sent_at
SELECT
  fe.id,
  fe.contact_id,
  fe.step,
  fe.executed,
  fe.sent_at,
  fe.should_send,
  fe.decision_reason,
  c.full_name
FROM corev4_followup_executions fe
JOIN corev4_contacts c ON fe.contact_id = c.id
WHERE fe.executed = true
  AND fe.sent_at IS NULL
ORDER BY fe.created_at DESC
LIMIT 50;
```

**Se houver muitos:** Bug na lógica de Skip ou Update.

#### Passo 10: Resetar uma execution para testar

```sql
-- CUIDADO: Apenas em ambiente de dev/teste
-- Resetar uma execution específica para forçar reenvio

UPDATE corev4_followup_executions
SET
  executed = false,
  sent_at = NULL,
  should_send = true,
  decision_reason = NULL,
  scheduled_at = NOW() - INTERVAL '1 minute'  -- Agendar para 1 min atrás
WHERE id = 123;  -- ID de teste

-- Resetar campanha também
UPDATE corev4_followup_campaigns
SET should_continue = true,
    status = 'active'
WHERE id = (SELECT campaign_id FROM corev4_followup_executions WHERE id = 123);
```

Aguarde o próximo ciclo do cron (5 minutos) e veja se envia.

---

### Checklist de Debug

- [ ] Há executions pendentes?
- [ ] Campaigns estão com should_continue=true?
- [ ] Contacts estão com opt_out=false?
- [ ] ANUM scores estão dentro do range (não qualified nem disqualified)?
- [ ] Thresholds estão configurados corretamente?
- [ ] Workflow está ativo?
- [ ] Credenciais da Evolution API estão corretas?
- [ ] AI está gerando mensagens?
- [ ] Evolution API está retornando sucesso?

**Resultado esperado:**
✅ Identificar causa raiz do bloqueio
✅ Followups começam a enviar

---

## 🎯 RESUMO DE PRIORIDADES

### Implementar AGORA (30 min total):
1. ✅ Fix #1: #padrao (5 min)
2. ✅ Fix #3: DROP tables (10 min)

### Implementar HOJE (3-4h):
3. ✅ Fix #2: Mensagem vídeo (30 min)
4. ✅ Fix #8: Debug followups (2-4h)

### Implementar ESTA SEMANA (10-13h):
5. ✅ Fix #4: Audio storage (3h)
6. ✅ Fix #5: Execution logs (4h)
7. ✅ Fix #6: AI decisions (3h)

### Implementar PRÓXIMA SEMANA (6h):
8. ✅ Fix #7: Followup steps (6h)

---

**Total estimado:** ~24-27 horas de trabalho

Boa sorte com as implementações! Se tiver dúvidas em algum passo específico, pode me perguntar.
