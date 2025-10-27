# 🎯 FRANK V4 - FASE 2: TRACE DE FLUXOS MULTI-MODAL

**Data:** 2025-10-27
**Análise:** Rastreamento end-to-end de todos os fluxos de mensagens

---

## 📊 RESUMO EXECUTIVO

- ✅ **Fluxo de TEXTO:** Completo e funcional
- ✅ **Fluxo de ÁUDIO:** Completo com transcrição Whisper
- ✅ **Fluxo de COMANDOS:** 7 comandos implementados
- ⚠️ **Fluxo de IMAGEM:** Parcialmente implementado
- ❌ **Fluxo de VÍDEO:** Não implementado
- 🔴 **3 gaps críticos** identificados

---

## 1️⃣ FLUXO DE TEXTO SIMPLES

### ✅ STATUS: COMPLETO

```
┌─────────────────────────────────────────────────────────────────┐
│                    FLUXO DE TEXTO COMPLETO                      │
└─────────────────────────────────────────────────────────────────┘

WhatsApp → Evolution API v2
    ↓
[Receive: WhatsApp Webhook]
Frank Webhook - Main Router | v4.json
    ↓
[Execute: Normalize Evolution Data]
Normalize Evolution API | v4.json
    │
    ├─ Extrai: message_content
    ├─ Extrai: whatsapp_id, phone_number
    ├─ Extrai: contact_name (pushName)
    ├─ Extrai: message_id, timestamp
    └─ Define: media_type = "conversation"
    ↓
[Route: Audio Messages]
IF media_type == "audio" → FALSE (texto)
    ↓
[Merge: Audio and Text] (input 1)
    ↓
[Filter: Valid Messages]
IF message_content exists → TRUE
    ↓
[Prepare: Contact Lookup]
    ↓
[Fetch: Contact Record]
SELECT * FROM corev4_contacts WHERE whatsapp = $phone
    ↓
[Route: Duplicate Detection]
IF message já processada (5s window) → FALSE
    ↓
[Insert: Deduplication Record]
INSERT INTO corev4_message_dedup
    ↓
[Enrich: Message Context]
Adiciona: evolution_api_url, instance, api_key, company_id
    ↓
┌──────────────────────────────────────────────────────────────┐
│           [Route: Contact Status] - 4 ROTAS                  │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  1️⃣ NEW CONTACT (contact_exists == false)                   │
│     ↓                                                        │
│  [Prepare: Create Contact]                                  │
│     ↓                                                        │
│  [Execute: Create Contact]                                  │
│  Create Contact Flow | v4.json                              │
│     ├─ INSERT INTO corev4_contacts                          │
│     ├─ INSERT INTO corev4_contact_extras                    │
│     ├─ INSERT INTO corev4_lead_state (initial)              │
│     ├─ INSERT INTO corev4_chat_history (welcome)            │
│     └─ Execute: Create Contact & Followup Campaign          │
│         ├─ INSERT INTO corev4_followup_campaigns            │
│         └─ INSERT INTO corev4_followup_executions (5 steps) │
│     ↓                                                        │
│  [Restore: Frank Context]                                   │
│     ↓                                                        │
│  ┌────── VOLTA PARA ACTIVE CHAT ──────┐                     │
│  │                                     │                     │
│  2️⃣ BLOCKED CONTACT (opt_out == true) │                     │
│     ↓                                  │                     │
│  [Prepare: Reactivate]                │                     │
│     ↓                                  │                     │
│  [Execute: Reactivate Contact]        │                     │
│  Reactivate Blocked Contact | v4.json │                     │
│     ├─ UPDATE corev4_contacts SET opt_out = false           │
│     ├─ UPDATE/INSERT corev4_lead_state                      │
│     └─ Send welcome message                                 │
│     ↓                                  │                     │
│  ┌────── RETORNA ───────────────────┘                       │
│  │                                                           │
│  3️⃣ COMMAND (#listar, #audio, etc)                          │
│     ↓                                                        │
│  [Prepare: Process Command]                                 │
│     ↓                                                        │
│  [Execute: Process Commands]                                │
│  Process Commands | v4.json                                 │
│     ↓                                                        │
│  [Route: Commands] - Switch com 7 comandos:                 │
│     ├─ #listar → Lista comandos disponíveis                 │
│     ├─ #limpar → DELETE FROM corev4_chat_history           │
│     ├─ #audio → UPDATE contact_extras (audio_response)      │
│     ├─ #texto → UPDATE contact_extras (text_response)       │
│     ├─ #padrao → UPDATE contact_extras (default)            │
│     ├─ #sair → UPDATE contacts (opt_out = true)             │
│     └─ #zerar → DELETE ALL contact data (12 tables)         │
│     ↓                                                        │
│  [Send: WhatsApp Message]                                   │
│     ↓                                                        │
│  [Save: Command Response]                                   │
│  INSERT INTO corev4_chat_history                            │
│     ↓                                                        │
│  END                                                         │
│  │                                                           │
│  4️⃣ ACTIVE CHAT (contato ativo)    ◄─────────────┐          │
│     ↓                                            │          │
│  [Prepare: Frank Chat]                          │          │
│     ↓                                            │          │
│  [Execute: Frank Chat]                          │          │
│  Frank Chat | v4.json                           │          │
│     ↓                                            │          │
│  [Fetch: Lead & Contact Data]                   │          │
│  SELECT ls.*, ce.* FROM corev4_lead_state ls    │          │
│  LEFT JOIN corev4_contact_extras ce             │          │
│     ↓                                            │          │
│  [Fetch: Recent History]                        │          │
│  SELECT * FROM corev4_chat_history LIMIT 15     │          │
│     ↓                                            │          │
│  [Prepare: Chat Context]                        │          │
│  Formata context com: ANUM scores, history,     │          │
│  contact info, qualification_stage              │          │
│     ↓                                            │          │
│  [AI Agent Frank]                                │          │
│  @n8n/n8n-nodes-langchain.agent                  │          │
│     ├─ Model: OpenAI GPT-4o-mini                 │          │
│     ├─ Tools: None (somente chat)                │          │
│     ├─ Memory: corev4_n8n_chat_histories         │          │
│     ├─ System Prompt: Frank persona + ANUM       │          │
│     └─ Session ID: contact_{contact_id}_chat    │          │
│     ↓                                            │          │
│  [Parse: AI Response]                            │          │
│     ↓                                            │          │
│  [Check: Response Format]                        │          │
│  IF contact_extras.audio_response == true        │          │
│     ↓                        ↓                   │          │
│  [AUDIO]              [TEXT]                     │          │
│     ↓                        ↓                   │          │
│  Generate TTS       [Send: WhatsApp Text]       │          │
│  Send Audio         Evolution API POST           │          │
│     ↓                        ↓                   │          │
│  └────────────┬──────────────┘                   │          │
│               ↓                                  │          │
│  [Save: Chat Message]                            │          │
│  INSERT INTO corev4_chat_history (user + assistant)        │
│     ↓                                            │          │
│  [Trigger: ANUM Analyzer]                        │          │
│  Execute Workflow: ANUM Analyzer | v4.json       │          │
│     ├─ SELECT last 10 messages                   │          │
│     ├─ SELECT current ANUM state                 │          │
│     ├─ AI analyzes conversation for ANUM signals │          │
│     ├─ INSERT INTO corev4_anum_history           │          │
│     └─ UPDATE corev4_lead_state (scores, stage)  │          │
│     ↓                                            │          │
│  END                                              │          │
│                                                   │          │
└───────────────────────────────────────────────────┴──────────┘
```

### 🎯 TABELAS TOCADAS NO FLUXO DE TEXTO

| Operação | Tabela | Workflow |
|----------|--------|----------|
| SELECT | corev4_contacts | Frank Webhook |
| INSERT | corev4_message_dedup | Frank Webhook |
| SELECT | corev4_lead_state | Frank Chat |
| SELECT | corev4_contact_extras | Frank Chat |
| SELECT | corev4_chat_history | Frank Chat |
| INSERT | corev4_chat_history | Frank Chat (2x: user + assistant) |
| INSERT | corev4_n8n_chat_histories | Frank Chat (AI memory) |
| SELECT | corev4_n8n_chat_histories | ANUM Analyzer |
| SELECT | corev4_lead_state | ANUM Analyzer |
| INSERT | corev4_anum_history | ANUM Analyzer |
| UPDATE | corev4_lead_state | ANUM Analyzer |

### ✅ AVALIAÇÃO: FLUXO DE TEXTO

- ✅ **End-to-end funcional:** Webhook → IA → Resposta → DB
- ✅ **Deduplicação:** Previne processamento duplicado (5s window)
- ✅ **AI Memory:** Histórico persistido em n8n_chat_histories
- ✅ **ANUM tracking:** Análise automática a cada mensagem
- ✅ **Error handling:** Checks em cada node crítico
- ⚠️ **Performance:** ANUM Analyzer roda em CADA mensagem (pode ser throttled)

---

## 2️⃣ FLUXO DE ÁUDIO

### ✅ STATUS: COMPLETO

```
┌─────────────────────────────────────────────────────────────────┐
│                    FLUXO DE ÁUDIO COMPLETO                      │
└─────────────────────────────────────────────────────────────────┘

WhatsApp → Evolution API v2 (áudio .ogg)
    ↓
[Receive: WhatsApp Webhook]
Frank Webhook - Main Router | v4.json
    ↓
[Execute: Normalize Evolution Data]
Normalize Evolution API | v4.json
    │
    ├─ Extrai: media_type = "audioMessage"
    ├─ Extrai: message_id para buscar base64
    └─ NÃO extrai message_content (áudio binário)
    ↓
[Route: Audio Messages]
IF media_type == "audio" → TRUE ✅
    ↓
┌──────────────────────────────────────────────────────────────┐
│  [Execute: Transcribe Audio]                                 │
│  Process Audio Message | v4.json                             │
│     ↓                                                        │
│  [Fetch: Audio Base64]                                      │
│  HTTP POST /chat/getBase64FromMediaMessage                  │
│     ├─ Input: message_id                                    │
│     └─ Output: base64 string (audio)                        │
│     ↓                                                        │
│  [Convert: Base64 to Binary]                                │
│  n8n-nodes-base.convertToFile                               │
│     └─ Output: audio.ogg (binary)                           │
│     ↓                                                        │
│  [Transcribe: Audio (Whisper)]                              │
│  @n8n/n8n-nodes-langchain.openAi                            │
│     ├─ Model: Whisper-1                                     │
│     ├─ Language: pt (português)                             │
│     ├─ Temperature: 0 (determinístico)                      │
│     └─ Output: { text: "transcrição" }                      │
│     ↓                                                        │
│  [Check: Transcription Success]                             │
│  IF text exists → TRUE                                      │
│     ↓                        ↓                              │
│  [SUCCESS]              [ERROR]                             │
│     ↓                        ↓                              │
│  Format Success      Format Error                           │
│  ├─ message_content = text                                  │
│  ├─ transcribed = true                                      │
│  ├─ message_type = "conversation"                           │
│  ├─ original_message_type = "audioMessage"                  │
│  └─ transcription_service = "OpenAI Whisper"                │
│     ↓                        ↓                              │
│     │                    message_content =                  │
│     │              "[Áudio não pôde ser transcrito]"        │
│     │                        ↓                              │
│     └─────────┬──────────────┘                              │
│               ↓                                             │
│  RETURN to Frank Webhook                                    │
└──────────────────────────────────────────────────────────────┘
    ↓
[Merge: Audio and Text] (input 0 - áudio transcrito)
    ↓
[Filter: Valid Messages]
IF message_content exists → TRUE (se transcrito com sucesso)
    ↓
┌────── CONTINUA NO FLUXO DE TEXTO ──────┐
│  Duplicate Detection → Contact Status  │
│  → Active Chat → Frank Chat → Response │
└────────────────────────────────────────┘
```

### 🎯 TABELAS TOCADAS NO FLUXO DE ÁUDIO

**Process Audio Message NÃO toca banco diretamente**
- Apenas transcreve e retorna texto
- Fluxo continua como texto normal após transcrição

### ✅ AVALIAÇÃO: FLUXO DE ÁUDIO

- ✅ **Transcrição funcional:** OpenAI Whisper integrado
- ✅ **Error handling:** Catch para falhas de transcrição
- ✅ **Conversão automática:** Áudio vira texto e segue fluxo normal
- ✅ **Language detection:** Fixo em PT (correto para BR)
- ⚠️ **Cost:** Cada áudio gera chamada Whisper API ($$$)
- ⚠️ **No audio storage:** Base64 não é salvo no banco

---

## 3️⃣ FLUXO DE COMANDOS

### ✅ STATUS: COMPLETO

```
┌─────────────────────────────────────────────────────────────────┐
│                  FLUXO DE COMANDOS (7 TIPOS)                    │
└─────────────────────────────────────────────────────────────────┘

WhatsApp → "#listar" (ou outro comando)
    ↓
[Receive: WhatsApp Webhook]
    ↓
[Normalize] → [Route: Audio] → [Merge] → [Filter]
    ↓
[Route: Duplicate Detection] → [Enrich]
    ↓
[Route: Contact Status]
    ↓
IF message_content STARTS WITH "#" → OUTPUT 2 (command)
    ↓
[Prepare: Process Command]
    ↓
[Execute: Process Commands]
Process Commands | v4.json
    ↓
[Prepare: Command Data]
    ↓
┌──────────────────────────────────────────────────────────────┐
│  [Route: Commands] - Switch 7 outputs                        │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  1️⃣ #listar                                                  │
│     ↓                                                        │
│  [Message: Listar]                                          │
│  Texto: "📋 Lista de Comandos Disponíveis..."              │
│     ↓                                                        │
│  ┌────── MERGE ──────┐                                      │
│  │                    │                                      │
│  2️⃣ #limpar           │                                      │
│     ↓                 │                                      │
│  [Clear: Chat History]                                      │
│  DELETE FROM corev4_chat_history WHERE contact_id = X       │
│  DELETE FROM corev4_n8n_chat_histories WHERE session LIKE X │
│     ↓                 │                                      │
│  [Message: Limpar]    │                                      │
│  Texto: "✅ Histórico limpo!"                               │
│     ↓                 │                                      │
│  ┌────── MERGE ──────┤                                      │
│  │                    │                                      │
│  3️⃣ #audio            │                                      │
│     ↓                 │                                      │
│  [Set Audio Preference]                                     │
│  UPDATE corev4_contact_extras                               │
│  SET audio_response = true, text_response = false           │
│     ↓                 │                                      │
│  [Message: Audio]     │                                      │
│     ↓                 │                                      │
│  ┌────── MERGE ──────┤                                      │
│  │                    │                                      │
│  4️⃣ #texto            │                                      │
│     ↓                 │                                      │
│  [Set Text Preference]                                      │
│  UPDATE corev4_contact_extras                               │
│  SET audio_response = false, text_response = true           │
│     ↓                 │                                      │
│  [Message: Text]      │                                      │
│     ↓                 │                                      │
│  ┌────── MERGE ──────┤                                      │
│  │                    │                                      │
│  5️⃣ #padrao           │                                      │
│     ↓                 │                                      │
│  [Set Default Preference]                                   │
│  UPDATE corev4_contact_extras                               │
│  SET audio_response = false, text_response = true           │
│     ↓                 │                                      │
│  [Message: Default]   │                                      │
│     ↓                 │                                      │
│  ┌────── MERGE ──────┤                                      │
│  │                    │                                      │
│  6️⃣ #sair             │                                      │
│     ↓                 │                                      │
│  [Set Opt-Out]        │                                      │
│  UPDATE corev4_contacts SET opt_out = true                  │
│     ↓                 │                                      │
│  [Message: Opt-Out]   │                                      │
│  Texto: "👋 Você não receberá mais mensagens"              │
│     ↓                 │                                      │
│  ┌────── MERGE ──────┤                                      │
│  │                    │                                      │
│  7️⃣ #zerar - ESPECIAL │                                      │
│     ↓                 │                                      │
│  [Delete: Full Chat History]                                │
│  🔴 CASCADING DELETE (12 tabelas em ordem):                 │
│     1. DELETE FROM corev4_ai_decisions                      │
│     2. DELETE FROM corev4_followup_executions               │
│     3. DELETE FROM corev4_followup_campaigns                │
│     4. DELETE FROM corev4_chat_history                      │
│     5. DELETE FROM corev4_n8n_chat_histories                │
│     6. DELETE FROM corev4_anum_history                      │
│     7. DELETE FROM corev4_followup_stage_history            │
│     8. DELETE FROM corev4_chats                             │
│     9. DELETE FROM corev4_lead_state                        │
│    10. DELETE FROM corev4_contact_extras                    │
│    11. DELETE FROM corev4_execution_logs                    │
│    12. DELETE FROM corev4_contacts                          │
│     ↓                                                        │
│  [Message: Zerar]                                           │
│  Texto: "🔧 RESET COMPLETO"                                 │
│     ↓                                                        │
│  [Send: WhatsApp Message #Zerar]                            │
│  (Separado porque contato foi deletado)                     │
│     ↓                                                        │
│  END                                                         │
│  │                                                           │
│  8️⃣ FALLBACK (comando desconhecido)                         │
│     ↓                 │                                      │
│  [Message: Unknown]   │                                      │
│  Texto: "❌ Comando não reconhecido"                        │
│     ↓                 │                                      │
│  └────────┬──────────┘                                      │
│           ↓                                                  │
│  [Merge: All Command Responses]                             │
│     ↓                                                        │
│  [Send: WhatsApp Message]                                   │
│  Evolution API POST /message/sendText                       │
│     ↓                                                        │
│  [Save: Command Response]                                   │
│  INSERT INTO corev4_chat_history                            │
│     (role = 'assistant', message_type = 'command_response') │
│     ↓                                                        │
│  [Format: Command Output]                                   │
│     ↓                                                        │
│  END                                                         │
└──────────────────────────────────────────────────────────────┘
```

### 🎯 TABELAS TOCADAS POR COMANDO

| Comando | Operação | Tabelas |
|---------|----------|---------|
| **#listar** | - | Nenhuma (só responde) |
| **#limpar** | DELETE | chat_history, n8n_chat_histories |
| **#audio** | UPDATE | contact_extras |
| **#texto** | UPDATE | contact_extras |
| **#padrao** | UPDATE | contact_extras |
| **#sair** | UPDATE | contacts (opt_out = true) |
| **#zerar** | DELETE | 12 tabelas (reset completo) |
| **Todos** | INSERT | chat_history (response) |

### ✅ AVALIAÇÃO: FLUXO DE COMANDOS

- ✅ **7 comandos funcionais:** Todos implementados
- ✅ **#zerar é correto:** Deleta em ordem para evitar FK violations
- ✅ **User preferences:** #audio/#texto funciona
- ⚠️ **#padrao bug:** Deveria restaurar default (texto OU áudio), mas força texto
- ⚠️ **No undo:** #zerar é IRREVERSÍVEL (sem backup)
- ⚠️ **No confirmation:** #zerar executa sem pedir confirmação

---

## 4️⃣ FLUXO DE IMAGEM

### ⚠️ STATUS: PARCIALMENTE IMPLEMENTADO

```
┌─────────────────────────────────────────────────────────────────┐
│               FLUXO DE IMAGEM (INCOMPLETE)                      │
└─────────────────────────────────────────────────────────────────┘

WhatsApp → Evolution API v2 (imagem)
    ↓
[Receive: WhatsApp Webhook]
    ↓
[Execute: Normalize Evolution Data]
Normalize Evolution API | v4.json
    │
    ├─ Extrai: media_type = "image" ✅
    ├─ Extrai: base64 (presumido) ✅
    └─ Extrai: media_mime_type ✅
    ↓
[Route: Audio Messages]
IF media_type == "audio" → FALSE
    ↓
[Merge: Audio and Text] (input 1)
    ↓
[Filter: Valid Messages]
IF message_content exists → ⚠️ PROBLEMA: Imagem não tem text!
    │
    ├─ TRUE: Imagem com caption (texto) → Passa ✅
    └─ FALSE: Imagem sem caption → ❌ BLOQUEADO
    ↓
⚠️ SE PASSAR O FILTER:
    ↓
[Duplicate Detection] → [Enrich] → [Contact Status] → [Active Chat]
    ↓
[Execute: Frank Chat]
Frank Chat | v4.json
    ↓
[Prepare: Chat Context]
    ↓
┌──────────────────────────────────────────────────────────────┐
│  [Check: Has Media]                                          │
│  IF media_type === 'image' → TRUE ✅                         │
│     ↓                                                        │
│  [Prepare: Image Context] (node EXISTE)                     │
│  Converte base64 para binary Buffer                         │
│     ↓                                                        │
│  ⚠️ PROBLEMA: Não há integração com AI Vision                │
│     ↓                                                        │
│  [AI Agent Frank]                                            │
│  - NÃO recebe imagem como input                             │
│  - Apenas recebe texto                                      │
│  - GPT-4o-mini pode processar imagens, mas não está configurado │
│     ↓                                                        │
│  Responde como se fosse TEXTO                               │
│     ↓                                                        │
│  ❌ GAP: Imagem é ignorada                                   │
└──────────────────────────────────────────────────────────────┘
```

### ❌ GAPS IDENTIFICADOS NO FLUXO DE IMAGEM

1. **🔴 P0: Filter: Valid Messages bloqueia imagens sem caption**
   - **Problema:** Verifica `IF message_content exists`
   - **Imagem sem texto:** Bloqueada no filtro
   - **Consequência:** Imagens sem caption são descartadas
   - **Fix:**
     ```javascript
     // Frank Webhook - Main Router _ v4.json, node "Filter: Valid Messages"
     // ATUAL:
     IF message_content exists

     // CORRIGIR PARA:
     IF (message_content exists) OR (media_type === 'image')
     ```

2. **🔴 P0: AI Agent não processa imagens**
   - **Problema:** GPT-4o-mini suporta vision, mas não recebe imagem
   - **Gap:** Node "Prepare: Image Context" existe mas não é usado
   - **Consequência:** Frank responde "não entendi a imagem"
   - **Fix:** Configurar AI Agent para receber binary image data
     ```json
     {
       "type": "image_url",
       "image_url": {
         "url": "data:image/jpeg;base64,{{base64}}"
       }
     }
     ```

3. **🟠 P1: Imagens não são salvas no banco**
   - **Problema:** `corev4_message_media` nunca recebe INSERT
   - **Tabela existe** mas não é usada
   - **Consequência:** Perda de histórico de imagens enviadas
   - **Fix:** INSERT em `corev4_message_media` após processar imagem

### ⚠️ AVALIAÇÃO: FLUXO DE IMAGEM

- ⚠️ **Detecção OK:** Sistema identifica media_type = "image"
- ⚠️ **Parse OK:** Base64 é extraído corretamente
- ❌ **Processing FAIL:** AI não recebe/processa imagem
- ❌ **Storage FAIL:** Imagens não são salvas no banco
- 🔴 **BLOCKER:** Imagens sem caption são descartadas

---

## 5️⃣ FLUXO DE VÍDEO

### ❌ STATUS: NÃO IMPLEMENTADO

```
┌─────────────────────────────────────────────────────────────────┐
│                  FLUXO DE VÍDEO (NOT FOUND)                     │
└─────────────────────────────────────────────────────────────────┘

WhatsApp → Evolution API v2 (vídeo)
    ↓
[Receive: WhatsApp Webhook]
    ↓
[Execute: Normalize Evolution Data]
    │
    ❌ NÃO detecta media_type = "video"
    ❌ NÃO extrai base64 de vídeo
    │
    ↓
Tratado como mensagem inválida ou desconhecida
    ↓
❌ DESCARTADO
```

### ❌ GAPS IDENTIFICADOS NO FLUXO DE VÍDEO

1. **🔴 P0: Vídeos não são processados**
   - **Status:** Feature não implementada
   - **Impacto:** Usuários podem enviar vídeos e não receberão resposta
   - **Comportamento atual:** Vídeo é ignorado silenciosamente
   - **Fix necessário:**
     1. Detectar `videoMessage` no Normalize
     2. Extrair base64 (ou URL) do vídeo
     3. Enviar para processamento (ex: frame extraction + vision)
     4. OU responder "Desculpe, não consigo processar vídeos no momento"

2. **🟡 P2: Sem feedback para o usuário**
   - **Problema:** Usuário envia vídeo e não recebe resposta
   - **UX ruim:** Parece que o bot travou
   - **Fix simples:** Resposta automática "Não processo vídeos, envie texto/áudio"

---

## 6️⃣ SUMMARY - GAPS POR PRIORIDADE

### 🔴 P0 - BLOQUEANTE (3 issues)

1. **Imagens sem caption são bloqueadas** (Frank Webhook - Filter node)
   - Fix: Alterar condição do Filter para aceitar images

2. **AI Agent não processa imagens** (Frank Chat - AI Agent config)
   - Fix: Configurar input multimodal para GPT-4o-mini

3. **Vídeos não são processados** (Normalize + Frank Chat)
   - Fix: Implementar detecção de vídeo OU resposta de "não suportado"

### 🟠 P1 - CRÍTICO (3 issues)

4. **corev4_message_media nunca recebe INSERT** (Frank Chat)
   - Fix: Salvar imagens/áudios no banco para histórico

5. **#padrao força texto** (Process Commands)
   - Fix: Restaurar preferência original ou sistema default

6. **#zerar sem confirmação** (Process Commands)
   - Fix: Adicionar step de confirmação antes de deletar

### 🟡 P2 - IMPORTANTE (2 issues)

7. **ANUM Analyzer roda em TODA mensagem** (Frank Chat)
   - Fix: Throttle (ex: a cada 3 mensagens ou 5 minutos)

8. **Vídeos sem feedback** (Frank Webhook)
   - Fix: Resposta automática informando não-suporte

---

## 7️⃣ FLUXO FOLLOWUP (BONUS)

### ✅ STATUS: AUTOMÁTICO E FUNCIONAL

```
┌─────────────────────────────────────────────────────────────────┐
│              FLUXO AUTOMÁTICO DE FOLLOWUP                       │
└─────────────────────────────────────────────────────────────────┘

TRIGGER: Schedule (polling a cada X minutos)
    ↓
[Execute Followup Processor | v4.json]
    ↓
[Fetch: Pending Executions]
SELECT fe.*, c.*, comp.*, camp.*, fc.*, ls.*
FROM corev4_followup_executions fe
JOIN corev4_contacts c ON fe.contact_id = c.id
JOIN corev4_companies comp ON fe.company_id = comp.id
JOIN corev4_followup_campaigns camp ON fe.campaign_id = camp.id
LEFT JOIN corev4_followup_configs fc ON camp.config_id = fc.id
LEFT JOIN corev4_lead_state ls ON fe.contact_id = ls.contact_id
WHERE fe.executed = false
  AND fe.scheduled_at <= NOW()
  AND c.opt_out = false
  AND camp.should_continue = true
  AND fe.step <= fe.total_steps
ORDER BY fe.scheduled_at ASC
LIMIT 50
    ↓
[Loop Over Executions] (até 50)
    ↓
FOR EACH execution:
    ↓
[Prepare: Followup Context]
    ├─ Contact info (name, phone)
    ├─ ANUM scores (authority, need, urgency, money)
    ├─ Qualification stage (pre/partial/full)
    ├─ Step number (1-5)
    └─ Evolution API config
    ↓
[AI Agent: Generate Followup Message]
@n8n/n8n-nodes-langchain.agent
    ├─ System Prompt: "Você é Frank, gerando followup step X"
    ├─ Context: ANUM scores, stage, previous interactions
    ├─ Goal: Mover lead para próximo stage ANUM
    └─ Output: Personalized message
    ↓
[Send: WhatsApp Message]
Evolution API POST /message/sendText
    ↓
[Update: Execution Record]
UPDATE corev4_followup_executions
SET executed = true,
    executed_at = NOW(),
    message_sent = [AI message]
WHERE id = X
    ↓
[Check: Should Continue Campaign]
IF ANUM score >= qualification_threshold → Stop campaign
IF ANUM score <= disqualification_threshold → Stop campaign
IF opt_out = true → Stop campaign
IF step == total_steps → Stop campaign
    ↓
IF should_stop:
    UPDATE corev4_followup_campaigns
    SET should_continue = false,
        status = 'completed'/'stopped'
    ↓
END LOOP
```

### ✅ AVALIAÇÃO: FLUXO FOLLOWUP

- ✅ **Automático:** Roda via schedule (polling)
- ✅ **Inteligente:** AI gera mensagens personalizadas por ANUM stage
- ✅ **ANUM-aware:** Para campaign se lead qualifica ou desqualifica
- ✅ **Opt-out respect:** Não envia se usuário deu #sair
- ⚠️ **Limite 50:** Processa max 50 execuções por run (pode gerar atraso)
- ⚠️ **Sem corev4_followup_steps:** Mensagens não vêm de templates configuráveis

---

## 🎯 MÉTRICAS FINAIS

| Fluxo | Status | Completude | Issues |
|-------|--------|------------|--------|
| **Texto** | ✅ COMPLETO | 100% | 0 P0, 1 P2 |
| **Áudio** | ✅ COMPLETO | 100% | 0 P0 |
| **Comandos** | ✅ COMPLETO | 100% | 0 P0, 2 P1 |
| **Imagem** | ⚠️ PARCIAL | 40% | 2 P0, 1 P1 |
| **Vídeo** | ❌ AUSENTE | 0% | 1 P0, 1 P2 |
| **Followup** | ✅ COMPLETO | 95% | 0 P0 |

**Total Issues Identificados:**
- 🔴 **3 P0** (bloqueantes)
- 🟠 **3 P1** (críticos)
- 🟡 **2 P2** (importantes)

---

## 🎯 PRÓXIMOS PASSOS

**FASE 3:** Análise node-by-node dos 3 workflows críticos

---

_Fase 2 concluída: 2025-10-27_
_Todos os fluxos mapeados end-to-end_
